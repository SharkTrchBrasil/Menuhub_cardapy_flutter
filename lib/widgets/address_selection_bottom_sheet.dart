
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
import 'package:totem/widgets/address_dialog/address_checkout_selection_step.dart';
import 'package:totem/widgets/address_dialog/address_map_and_form_step.dart';

/// ✅ Bottom Sheet para seleção/cadastro de endereço no mobile
/// Usa os mesmos widgets do AddressSelectionDialog (desktop)
class AddressSelectionBottomSheet extends StatefulWidget {
  /// Se true, inicia diretamente no Step de busca (para adicionar novo)
  final bool startWithSearch;
  
  /// Endereço a editar (se null, estamos criando novo)
  final CustomerAddress? addressToEdit;

  const AddressSelectionBottomSheet({
    super.key,
    this.startWithSearch = false,
    this.addressToEdit,
  });

  /// Mostra o bottom sheet no contexto fornecido
  static Future<void> show(
    BuildContext context, {
    bool startWithSearch = false,
    CustomerAddress? addressToEdit,
  }) async {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        // Passa os cubits necessários para dentro do bottom sheet
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<AddressCubit>()),
            BlocProvider.value(value: context.read<AuthCubit>()),
            BlocProvider.value(value: context.read<StoreCubit>()),
            BlocProvider.value(value: context.read<DeliveryFeeCubit>()),
          ],
          child: AddressSelectionBottomSheet(
            startWithSearch: startWithSearch,
            addressToEdit: addressToEdit,
          ),
        );
      },
    );
  }

  @override
  State<AddressSelectionBottomSheet> createState() => _AddressSelectionBottomSheetState();
}

enum _AddressSheetStep {
  searchAndList,
  mapAndForm,
}

class _AddressSelectionBottomSheetState extends State<AddressSelectionBottomSheet> {
  _AddressSheetStep _currentStep = _AddressSheetStep.searchAndList;
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
  int? _addressIdBeingEdited;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _showSearchResults = false);
      }
    });
    
    // Se tem endereço para editar, pré-popula os campos
    if (widget.addressToEdit != null) {
      _addressIdBeingEdited = widget.addressToEdit!.id;
      _initializeForEdit(widget.addressToEdit!);
    }
  }

  void _initializeForEdit(CustomerAddress address) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _mapLatitude = address.latitude;
        _mapLongitude = address.longitude;
        _numberController.text = address.number ?? '';
        _complementController.text = address.complement ?? '';
        _referenceController.text = address.reference ?? '';
        _neighborhoodController.text = address.neighborhood ?? '';
        _streetController.text = address.street ?? '';
        _favoriteLabel = address.label ?? '';
        
        // Cria um SearchResult fake para permitir edição
        _selectedSearchResult = AddressSearchResult(
          description: '${address.street}, ${address.number} - ${address.neighborhood}',
          street: address.street,
          number: address.number,
          neighborhood: address.neighborhood,
          city: address.city,
          state: '', // Não temos o estado no CustomerAddress
          latitude: address.latitude,
          longitude: address.longitude,
        );
        
        // Vai direto para o step de mapa/formulário
        _currentStep = _AddressSheetStep.mapAndForm;
      });
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
      _currentStep = _AddressSheetStep.mapAndForm;
    });
  }

  void _onSavedAddressSelected(CustomerAddress address) {
    context.read<AddressCubit>().selectAddress(address);
    Navigator.of(context).pop();
  }

  void _onEditAddress(CustomerAddress address) {
    setState(() {
      _addressIdBeingEdited = address.id;
      _mapLatitude = address.latitude;
      _mapLongitude = address.longitude;
      _numberController.text = address.number ?? '';
      _streetController.text = address.street;
      _neighborhoodController.text = address.neighborhood;
      _referenceController.text = address.reference ?? '';
      _complementController.text = address.complement ?? '';
      _favoriteLabel = address.label;
      
      _selectedSearchResult = AddressSearchResult(
        description: '${address.street}, ${address.number}',
        street: address.street,
        number: address.number,
        neighborhood: address.neighborhood,
        city: address.city,
        state: '',
        latitude: address.latitude,
        longitude: address.longitude,
      );
      
      _currentStep = _AddressSheetStep.mapAndForm;
    });
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

    // ✅ Validação de campos obrigatórios
    if (_numberController.text.trim().isEmpty) {
      _showError('Por favor, preencha o número do endereço');
      return;
    }
    
    if (_neighborhoodController.text.trim().isEmpty) {
      _showError('Por favor, preencha o bairro');
      return;
    }
    
    if (_streetController.text.trim().isEmpty) {
      _showError('Por favor, preencha a rua');
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

    final newAddress = CustomerAddress(
      id: _addressIdBeingEdited, // Mantém ID se for edição
      label: _favoriteLabel.isNotEmpty ? _favoriteLabel : 'Endereço',
      isFavorite: true, // ✅ SEMPRE marca como favorito ao salvar para ser o padrão
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

    // Verificação básica de área de entrega
    bool shouldSave = true;
    String? warningMessage;
    
    try {
      final tempDeliveryFeeCubit = DeliveryFeeCubit();

      await tempDeliveryFeeCubit.calculate(
        address: newAddress,
        store: store,
        cartSubtotal: 0,
      );

      final deliveryState = tempDeliveryFeeCubit.state;

      if (deliveryState is DeliveryFeeError) {
        final errorMsg = deliveryState.message.toLowerCase();
        
        // Erros de conexão não devem bloquear
        if (errorMsg.contains('connection') || 
            errorMsg.contains('timeout') ||
            errorMsg.contains('network') ||
            errorMsg.contains('xmlhttprequest')) {
          warningMessage = 'Não foi possível verificar a área de entrega. O endereço será salvo.';
        }
        // Erros de área de entrega mostram diálogo
        else if (errorMsg.contains('fora da área') || 
                 errorMsg.contains('fora do raio') ||
                 errorMsg.contains('não entrega')) {
          if (context.mounted) {
            final continueAnyway = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Não entregamos neste endereço'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deliveryState.message),
                    const SizedBox(height: 16),
                    const Text(
                      'Deseja salvar este endereço mesmo assim?',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Este endereço ficará salvo e poderá ser usado para retirada na loja.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Salvar mesmo assim'),
                  ),
                ],
              ),
            );
            shouldSave = continueAnyway ?? false;
          }
        } else {
          warningMessage = 'Aviso: ${deliveryState.message}';
        }
      }
    } catch (e) {
      warningMessage = 'Não foi possível verificar a área de entrega. O endereço será salvo.';
    }

    if (!shouldSave) return;

    try {
      await context.read<AddressCubit>().saveAddress(customerId, newAddress);
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warningMessage ?? (widget.addressToEdit != null 
                ? 'Endereço atualizado com sucesso!' 
                : 'Endereço adicionado com sucesso!')),
            backgroundColor: warningMessage != null ? Colors.orange : Colors.green,
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
      if (_currentStep == _AddressSheetStep.mapAndForm && widget.addressToEdit == null) {
        _currentStep = _AddressSheetStep.searchAndList;
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header com botão de voltar e título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFFEA1D2C)),
                ),
                const Expanded(
                  child: Text(
                    'ENDEREÇOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E3E3E),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balanço do botão lateral
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(customer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(dynamic customer) {
    switch (_currentStep) {
      case _AddressSheetStep.searchAndList:
        return AddressCheckoutSelectionStep(
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          searchResults: _searchResults,
          isSearching: _isSearching,
          showSearchResults: _showSearchResults,
          onClearSearch: _onClearSearch,
          onSearchResultSelected: _onSearchResultSelected,
          onSavedAddressSelected: _onSavedAddressSelected,
          onEditAddress: _onEditAddress,
          onDeleteAddress: (address) {
            if (address.id != null && customer != null) {
              final cust = customer as dynamic;
              context.read<AddressCubit>().deleteAddress(cust.id!, address.id!);
            }
          },
          onSearchChanged: _onSearchChanged,
        );
        
      case _AddressSheetStep.mapAndForm:
        if (_mapLatitude == null || _mapLongitude == null || _selectedSearchResult == null) {
          return const Center(child: Text('Erro: Dados do endereço não disponíveis'));
        }
        return AddressMapAndFormStep(
          latitude: _mapLatitude!,
          longitude: _mapLongitude!,
          street: _selectedSearchResult!.street ?? '',
          neighborhood: _selectedSearchResult!.neighborhood ?? '',
          city: _selectedSearchResult!.city ?? '',
          state: _selectedSearchResult!.state ?? '', // Aqui mantemos pois o SearchResult tem state
          onSave: _saveAddress,
          onBack: _goBack,
          numberController: _numberController,
          complementController: _complementController,
          referenceController: _referenceController,
          neighborhoodController: _neighborhoodController,
          streetController: _streetController,
          favoriteLabel: _favoriteLabel,
          onFavoriteLabelChanged: (label) => setState(() => _favoriteLabel = label),
          startWithForm: widget.addressToEdit != null, // ✅ Abre direto no formulário se for edição
        );
    }
  }
}
