// lib/widgets/address_autocomplete_field.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/core/di.dart';
import 'package:totem/services/address_search_service.dart';
import 'package:totem/services/geolocation_service.dart';
import 'package:dio/dio.dart';

/// Widget de autocomplete para busca de endereços
class AddressAutocompleteField extends StatefulWidget {
  final Function(AddressSearchResult) onAddressSelected;
  final String? initialValue;

  const AddressAutocompleteField({
    super.key,
    required this.onAddressSelected,
    this.initialValue,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AddressSearchService _searchService = AddressSearchService(getIt<Dio>());
  
  List<AddressSearchResult> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  
  // ✅ NOVO: Localização do usuário para bias de busca
  double? _userLatitude;
  double? _userLongitude;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Atraso para permitir clicar na sugestão antes de esconder
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() => _showSuggestions = false);
          }
        });
      } else if (_controller.text.isNotEmpty) {
        _onTextChanged();
      }
    });
    
    // ✅ NOVO: Tenta obter localização do usuário ao inicializar
    _getUserLocation();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ✅ NOVO: Obtém localização do usuário para melhorar busca
  Future<void> _getUserLocation() async {
    try {
      final position = await GeolocationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
        print('✅ Localização do usuário obtida: $_userLatitude, $_userLongitude');
      }
    } catch (e) {
      print('⚠️ Não foi possível obter localização do usuário: $e');
      // Não é crítico, a busca funciona sem localização
    }
  }

  void _onTextChanged() {
    final query = _controller.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoading = false;
      });
      return;
    }

    if (query.length < 3) {
      return; // Aguarda pelo menos 3 caracteres
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      // ✅ MELHORIA: Aguarda 800ms para o usuário terminar de digitar
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted || _controller.text.trim() != query) {
        return; // O texto mudou enquanto esperava
      }

      // ✅ MELHORIA: Usa localização do usuário para bias de busca
      final results = await _searchService.searchAddresses(
        input: query,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );
      
      if (mounted && _controller.text.trim() == query) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _suggestions = [];
        });
      }
    }
  }

  void _onSuggestionSelected(AddressSearchResult suggestion) async {
    setState(() {
      _showSuggestions = false;
      _controller.text = suggestion.description;
    });
    _focusNode.unfocus();

    // Se tem placeId (Google Places), busca detalhes completos
    if (suggestion.placeId != null) {
      final details = await _searchService.getAddressDetails(suggestion.placeId!);
      if (details != null && mounted) {
        widget.onAddressSelected(details);
      } else {
        widget.onAddressSelected(suggestion);
      }
    } else {
      widget.onAddressSelected(suggestion);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'rua Nações unidas, 405, roseira',
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20, color: Colors.grey.shade600),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _suggestions = [];
                        _showSuggestions = false;
                      });
                    },
                  )
                : _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        
        // Texto "powered by Google" (opcional, só se usar Google Places)
        if (_controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Row(
              children: [
                Image.network(
                  'https://www.google.com/images/poweredby_transparent/poweredby_FFFFFF/14px/poweredby_google_on_white_hdpi.png',
                  height: 14,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

        // Lista de sugestões
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return InkWell(
                  onTap: () => _onSuggestionSelected(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

























