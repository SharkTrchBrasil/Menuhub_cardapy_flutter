import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/services/address_search_service.dart';
import 'package:totem/core/di.dart';
import 'package:dio/dio.dart';
import 'package:totem/widgets/address_dialog/address_search_and_list_step.dart';
import 'package:totem/widgets/address_dialog/address_map_and_form_step.dart';

/// Dialog de seleção de endereço (estilo iFood)
/// Apenas 2 steps: busca+lista e mapa+formulário unificado
class AddressSelectionDialog extends StatefulWidget {
  const AddressSelectionDialog({super.key});

  @override
  State<AddressSelectionDialog> createState() => _AddressSelectionDialogState();
}

enum AddressDialogStep {
  searchAndList,  // Step 0: Busca + Lista de endereços
  mapAndForm,     // Step 1: Mapa + Formulário (unificado)
}

class _AddressSelectionDialogState extends State<AddressSelectionDialog> {
  AddressDialogStep _currentStep = AddressDialogStep.searchAndList;
  AddressSearchResult? _selectedSearchResult;
  double? _mapLatitude;
  double? _mapLongitude;
  
  // Controllers para busca
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressSearchService _searchService = AddressSearchService(getIt<Dio>());
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  
  // Controllers para o formulário
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _complementController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  String _favoriteLabel = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _showSearchResults = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _referenceController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    if (query.length < 3) {
      return;
    }

    _performSearch(query);
  }

  /// Obtém coordenadas do cliente (endereço selecionado ou geolocalização)
  (double?, double?) _getCustomerCoordinates() {
    // Tenta pegar do endereço selecionado primeiro
    final addressState = context.read<AddressCubit>().state;
    if (addressState.selectedAddress != null) {
      final selectedAddress = addressState.selectedAddress!;
      if (selectedAddress.latitude != null && selectedAddress.longitude != null) {
        print('📍 Usando coordenadas do endereço selecionado: ${selectedAddress.latitude}, ${selectedAddress.longitude}');
        return (selectedAddress.latitude, selectedAddress.longitude);
      }
    }
    
    // Se não tiver endereço selecionado, tenta pegar do primeiro endereço salvo
    if (addressState.addresses.isNotEmpty) {
      final firstAddress = addressState.addresses.first;
      if (firstAddress.latitude != null && firstAddress.longitude != null) {
        print('📍 Usando coordenadas do primeiro endereço salvo: ${firstAddress.latitude}, ${firstAddress.longitude}');
        return (firstAddress.latitude, firstAddress.longitude);
      }
    }
    
    // Se não tiver endereços, retorna null (sem filtro de proximidade)
    return (null, null);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }

      // ✅ NOVO: Obtém coordenadas do cliente para filtrar por proximidade
      final (customerLat, customerLon) = _getCustomerCoordinates();
      
      final results = await _searchService.searchAddresses(
        input: query,
        userLatitude: customerLat,
        userLongitude: customerLon,
      );
      
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

  void _onSearchResultSelected(AddressSearchResult result) async {
    setState(() {
      _showSearchResults = false;
      _searchController.text = result.description;
    });
    _searchFocusNode.unfocus();

    // Busca detalhes completos se tiver placeId
    if (result.placeId != null) {
      final details = await _searchService.getAddressDetails(result.placeId!);
      if (details != null && mounted) {
        _onAddressSearchSelected(details);
      } else {
        _onAddressSearchSelected(result);
      }
    } else {
      _onAddressSearchSelected(result);
    }
  }

  void _onAddressSearchSelected(AddressSearchResult result) {
    setState(() {
      _selectedSearchResult = result;
      _mapLatitude = result.latitude;
      _mapLongitude = result.longitude;
      
      // Preenche número se vier do resultado
      if (result.number != null && result.number!.isNotEmpty) {
        _numberController.text = result.number!;
      }
      
      // Preenche o bairro no controller
      _neighborhoodController.text = result.neighborhood ?? '';
      
      _currentStep = AddressDialogStep.mapAndForm;
    });
  }

  void _onSavedAddressSelected(CustomerAddress address) {
    context.read<AddressCubit>().selectAddress(address);
    Navigator.of(context).pop();
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  Future<void> _saveAddress() async {
    final authState = context.read<AuthCubit>().state;
    if (authState.status != AuthStatus.success || authState.customer == null) {
      return;
    }

    // ✅ VALIDAÇÃO: Verifica se o número foi preenchido
    if (_numberController.text.trim().isEmpty) {
      _showError('Por favor, preencha o número do endereço');
      return;
    }

    if (_mapLatitude == null || _mapLongitude == null) {
      _showError('Erro: Coordenadas não disponíveis');
      return;
    }

    if (_selectedSearchResult == null) {
      _showError('Erro: Endereço não selecionado');
      return;
    }

    final customerId = authState.customer!.id!;
    final store = context.read<StoreCubit>().state.store;
    
    if (store == null) {
      _showError('Erro: Loja não encontrada');
      return;
    }

    // Cria o endereço com os dados do resultado da busca
    final newAddress = CustomerAddress(
      label: _favoriteLabel.isNotEmpty ? _favoriteLabel : 'Endereço',
      isFavorite: _favoriteLabel.isNotEmpty,
      street: _selectedSearchResult!.street ?? '',
      number: _numberController.text.trim(),
      complement: _complementController.text.trim().isEmpty 
          ? null 
          : _complementController.text.trim(),
      // Usa o bairro do controller se foi preenchido, senão usa o do resultado
      neighborhood: _neighborhoodController.text.trim().isNotEmpty
          ? _neighborhoodController.text.trim()
          : (_selectedSearchResult!.neighborhood ?? ''),
      city: _selectedSearchResult!.city ?? '',
      reference: _referenceController.text.trim().isEmpty 
          ? null 
          : _referenceController.text.trim(),
      latitude: _mapLatitude,
      longitude: _mapLongitude,
    );

    // Valida se está dentro da área de entrega
    final tempDeliveryFeeCubit = DeliveryFeeCubit();

    await tempDeliveryFeeCubit.calculate(
      address: newAddress,
      store: store,
      cartSubtotal: 0,
    );

    final deliveryState = tempDeliveryFeeCubit.state;

    if (deliveryState is DeliveryFeeError) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Endereço fora da área'),
            content: Text(deliveryState.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Salva o endereço
    try {
      await context.read<AddressCubit>().saveAddress(customerId, newAddress);
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError('Erro ao salvar endereço: $e');
      }
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    setState(() {
      if (_currentStep == AddressDialogStep.mapAndForm) {
        _currentStep = AddressDialogStep.searchAndList;
        _searchController.clear();
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final customer = authState.customer;
    
    // Se não está logado, redireciona para login
    if (customer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        context.push('/onboarding');
      });
      return const SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Dialog(
      insetPadding: isDesktop 
          ? const EdgeInsets.symmetric(horizontal: 40, vertical: 24)
          : EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isDesktop ? 700 : MediaQuery.of(context).size.width,
        height: isDesktop ? MediaQuery.of(context).size.height * 0.9 : MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildCurrentStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case AddressDialogStep.searchAndList:
        return AddressSearchAndListStep(
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          searchResults: _searchResults,
          isSearching: _isSearching,
          showSearchResults: _showSearchResults,
          onClearSearch: _onClearSearch,
          onSearchResultSelected: _onSearchResultSelected,
          onSavedAddressSelected: _onSavedAddressSelected,
        );
        
      case AddressDialogStep.mapAndForm:
        if (_mapLatitude == null || _mapLongitude == null || _selectedSearchResult == null) {
          return const Center(child: Text('Erro: Dados do endereço não disponíveis'));
        }
        return AddressMapAndFormStep(
          latitude: _mapLatitude!,
          longitude: _mapLongitude!,
          street: _selectedSearchResult!.street ?? '',
          neighborhood: _selectedSearchResult!.neighborhood ?? '',
          city: _selectedSearchResult!.city ?? '',
          state: _selectedSearchResult!.state ?? '',
          onSave: _saveAddress,
          onBack: _goBack,
          numberController: _numberController,
          complementController: _complementController,
          referenceController: _referenceController,
          neighborhoodController: _neighborhoodController,
          favoriteLabel: _favoriteLabel,
          onFavoriteLabelChanged: (label) => setState(() => _favoriteLabel = label),
        );
    }
  }
}
