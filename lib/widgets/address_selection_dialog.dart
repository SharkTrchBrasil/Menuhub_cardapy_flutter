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

class AddressSelectionDialog extends StatefulWidget {
  const AddressSelectionDialog({super.key});

  @override
  State<AddressSelectionDialog> createState() => _AddressSelectionDialogState();
}

enum AddressDialogStep {
  searchAndList,
  mapAndForm,
}

class _AddressSelectionDialogState extends State<AddressSelectionDialog> {
  AddressDialogStep _currentStep = AddressDialogStep.searchAndList;
  AddressSearchResult? _selectedSearchResult;
  double? _mapLatitude;
  double? _mapLongitude;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressSearchService _searchService = AddressSearchService(getIt<Dio>());
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _complementController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
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
    _streetController.dispose();
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
    if (query.length < 3) return;
    _performSearch(query);
  }

  (double?, double?) _getCustomerCoordinates() {
    final addressState = context.read<AddressCubit>().state;
    if (addressState.selectedAddress != null) {
      final selectedAddress = addressState.selectedAddress!;
      if (selectedAddress.latitude != null && selectedAddress.longitude != null) {
        return (selectedAddress.latitude, selectedAddress.longitude);
      }
    }
    if (addressState.addresses.isNotEmpty) {
      final firstAddress = addressState.addresses.first;
      if (firstAddress.latitude != null && firstAddress.longitude != null) {
        return (firstAddress.latitude, firstAddress.longitude);
      }
    }
    return (null, null);
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted || _searchController.text.trim() != query) return;

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
      if (result.number != null && result.number!.isNotEmpty) {
        _numberController.text = result.number!;
      }
      _streetController.text = result.street ?? '';
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
    if (authState.status != AuthStatus.success || authState.customer == null) return;

    if (_numberController.text.trim().isEmpty) {
      _showError('Por favor, preencha o numero do endereco');
      return;
    }

    if (_mapLatitude == null || _mapLongitude == null) {
      _showError('Erro: Coordenadas nao disponiveis');
      return;
    }

    if (_selectedSearchResult == null) {
      _showError('Erro: Endereco nao selecionado');
      return;
    }

    final customerId = authState.customer!.id!;
    final store = context.read<StoreCubit>().state.store;
    
    if (store == null) {
      _showError('Erro: Loja nao encontrada');
      return;
    }

    final newAddress = CustomerAddress(
      label: _favoriteLabel.isNotEmpty ? _favoriteLabel : 'Endereco',
      isFavorite: _favoriteLabel.isNotEmpty,
      street: _streetController.text.trim().isNotEmpty 
          ? _streetController.text.trim() 
          : (_selectedSearchResult!.street ?? ''),
      number: _numberController.text.trim(),
      complement: _complementController.text.trim().isEmpty 
          ? null 
          : _complementController.text.trim(),
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
            title: const Text('Endereco fora da area'),
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

    try {
      await context.read<AddressCubit>().saveAddress(customerId, newAddress);
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereco adicionado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError('Erro ao salvar endereco: $e');
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
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 0),
      ),
      child: Container(
        width: isDesktop ? 700 : MediaQuery.of(context).size.width,
        height: isDesktop ? MediaQuery.of(context).size.height * 0.9 : MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 0),
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
          return const Center(child: Text('Erro: Dados do endereco nao disponiveis'));
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
          streetController: _streetController,
          favoriteLabel: _favoriteLabel,
          onFavoriteLabelChanged: (label) => setState(() => _favoriteLabel = label),
        );
    }
  }
}
