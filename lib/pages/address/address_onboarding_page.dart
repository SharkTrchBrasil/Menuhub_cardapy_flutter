import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/services/address_search_service.dart';
import 'package:totem/core/di.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/widgets/address_dialog/address_map_and_form_step.dart';
import 'package:dio/dio.dart';

/// Página de onboarding de endereço obrigatória
/// Exibida quando o usuário está logado mas não tem nenhum endereço cadastrado
class AddressOnboardingPage extends StatefulWidget {
  const AddressOnboardingPage({super.key});

  @override
  State<AddressOnboardingPage> createState() => _AddressOnboardingPageState();
}

enum _OnboardingStep {
  search, // Tela 1: Buscar endereço
  mapAndForm, // Tela 2: Mapa + Formulário (widget integrado)
}

class _AddressOnboardingPageState extends State<AddressOnboardingPage> {
  _OnboardingStep _currentStep = _OnboardingStep.search;

  // Controladores de busca
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressSearchService _searchService = AddressSearchService(
    getIt<Dio>(),
  );
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;

  // Timer para debounce
  Timer? _debounceTimer;

  // Dados do endereço selecionado
  AddressSearchResult? _selectedResult;
  double? _latitude;
  double? _longitude;

  // Controladores do formulário
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _complementController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  String _favoriteLabel = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _referenceController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Cancela o timer anterior
    _debounceTimer?.cancel();

    // Limpa resultados se menos de 3 caracteres
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Aguarda 800ms após o usuário parar de digitar
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() => _isSearching = true);

    try {
      // Verifica se o texto ainda é o mesmo
      if (_searchController.text.trim() != query) return;

      final store = context.read<StoreCubit>().state.store;

      final results = await _searchService.searchAddresses(
        input: query,
        userLatitude: store?.latitude,
        userLongitude: store?.longitude,
      );

      // Verifica novamente antes de atualizar
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _onSearchResultSelected(AddressSearchResult result) async {
    setState(() => _isSearching = true);

    try {
      AddressSearchResult finalResult = result;

      if (result.placeId != null) {
        final details = await _searchService.getAddressDetails(result.placeId!);
        if (details != null) {
          finalResult = details;
        }
      }

      if (mounted) {
        setState(() {
          _selectedResult = finalResult;
          _latitude = finalResult.latitude;
          _longitude = finalResult.longitude;
          _streetController.text = finalResult.street ?? '';
          _neighborhoodController.text = finalResult.neighborhood ?? '';
          if (finalResult.number != null && finalResult.number!.isNotEmpty) {
            _numberController.text = finalResult.number!;
          }
          _isSearching = false;
          _currentStep = _OnboardingStep.mapAndForm;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar detalhes do endereço')),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.customer == null) return;

    // Validações
    final street =
        _streetController.text.trim().isNotEmpty
            ? _streetController.text.trim()
            : (_selectedResult?.street ?? '');
    final neighborhood =
        _neighborhoodController.text.trim().isNotEmpty
            ? _neighborhoodController.text.trim()
            : (_selectedResult?.neighborhood ?? '');

    if (street.isEmpty) {
      _showError('Por favor, preencha a rua');
      return;
    }

    if (neighborhood.isEmpty) {
      _showError('Por favor, preencha o bairro');
      return;
    }

    if (_numberController.text.trim().isEmpty) {
      _showError('Por favor, preencha o número');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final customerId = authState.customer!.id!;

      final newAddress = CustomerAddress(
        label: _favoriteLabel.isNotEmpty ? _favoriteLabel : 'Casa',
        isFavorite: true,
        street: street,
        number: _numberController.text.trim(),
        // Complemento é opcional
        complement:
            _complementController.text.trim().isEmpty
                ? null
                : _complementController.text.trim(),
        neighborhood: neighborhood,
        city: _selectedResult?.city ?? '',
        reference:
            _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );

      await context.read<AddressCubit>().saveAddress(customerId, newAddress);

      if (mounted) {
        // Sucesso! Navega para a home
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showError('Erro ao salvar endereço: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _goBack() {
    if (_currentStep == _OnboardingStep.mapAndForm) {
      setState(() {
        _currentStep = _OnboardingStep.search;
        _selectedResult = null;
        _latitude = null;
        _longitude = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _OnboardingStep.search:
        return _buildSearchStep();
      case _OnboardingStep.mapAndForm:
        return _buildMapAndFormStep();
    }
  }

  // ========== STEP 1: BUSCA ==========
  Widget _buildSearchStep() {
    return Column(
      children: [
        // Header com ilustração
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fundo com ícones de localização
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                          ),
                      itemCount: 25,
                      itemBuilder:
                          (context, index) => Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                    ),
                  ),
                ),
                // Ícone central
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Icon(
                        Icons.location_on,
                        size: 60,
                        color: Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Onde você quer\nreceber seu pedido?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Campo de busca e resultados
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                // Campo de busca
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Endereço e número',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.red.shade400,
                      ),
                      filled: true,
                      fillColor: const Color(0XFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Resultados da busca
                Expanded(
                  child:
                      _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _searchResults.isEmpty
                          ? _buildEmptySearchState()
                          : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.grey.shade600,
                                ),
                                title: Text(
                                  result.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _onSearchResultSelected(result),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySearchState() {
    if (_searchController.text.isNotEmpty &&
        _searchController.text.length >= 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhum endereço encontrado',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '',
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ========== STEP 2: MAPA + FORMULÁRIO (widget integrado estilo Menuhub) ==========
  Widget _buildMapAndFormStep() {
    // ✅ Usa o widget AddressMapAndFormStep existente que já tem o layout correto do Menuhub
    return AddressMapAndFormStep(
      key: const ValueKey('address_onboarding_form_step'),
      latitude: _latitude ?? 0,
      longitude: _longitude ?? 0,
      street:
          _streetController.text.isNotEmpty
              ? _streetController.text
              : (_selectedResult?.street ?? ''),
      neighborhood:
          _neighborhoodController.text.isNotEmpty
              ? _neighborhoodController.text
              : (_selectedResult?.neighborhood ?? ''),
      city: _selectedResult?.city ?? '',
      state: _selectedResult?.state ?? '',
      numberController: _numberController,
      complementController: _complementController,
      referenceController: _referenceController,
      neighborhoodController: _neighborhoodController,
      streetController: _streetController,
      favoriteLabel: _favoriteLabel,
      onFavoriteLabelChanged: (label) {
        setState(() => _favoriteLabel = label);
      },
      onCoordinatesChanged: (lat, lon) {
        setState(() {
          _latitude = lat;
          _longitude = lon;
        });
      },
      onBack: _goBack,
      onSave: _saveAddress,
      startWithForm: false, // Começa mostrando o mapa
    );
  }
}
