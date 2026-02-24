// Em: lib/pages/address/address_selection_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/widgets/address_dialog/address_map_and_form_step.dart';
import 'package:totem/widgets/address_dialog/address_checkout_selection_step.dart'; 
import 'package:totem/widgets/address_selection_bottom_sheet.dart'; 
import 'package:totem/cubit/auth_cubit.dart';
import 'package:dio/dio.dart';
import 'package:totem/services/address_search_service.dart';
import '../../core/di.dart';

import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';

class AddressSelectionPage extends StatefulWidget {
  final bool isManagement;
  const AddressSelectionPage({super.key, this.isManagement = false});

  @override
  State<AddressSelectionPage> createState() => _AddressSelectionPageState();
}

class _AddressSelectionPageState extends State<AddressSelectionPage> {
  late DeliveryType _selectedType;
  bool _initialized = false;

  // Controladores de busca
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final AddressSearchService _searchService = AddressSearchService(getIt<Dio>());
  List<AddressSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      // ✅ OTIMIZAÇÃO: Só chama setState se o valor realmente mudou
      final shouldShow = _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;
      if (_showSearchResults != shouldShow) {
        setState(() {
          _showSearchResults = shouldShow;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeDeliveryType();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _initializeDeliveryType() {
    final storeConfig = context.read<StoreCubit>().state.store?.store_operation_config;
    final deliveryEnabled = storeConfig?.deliveryEnabled ?? false;
    final pickupEnabled = storeConfig?.pickupEnabled ?? false;
    final deliveryFeeState = context.read<DeliveryFeeCubit>().state;
    DeliveryType currentType = deliveryFeeState.deliveryType;

    if (currentType == DeliveryType.delivery && !deliveryEnabled && pickupEnabled) {
      currentType = DeliveryType.pickup;
    } else if (currentType == DeliveryType.pickup && !pickupEnabled && deliveryEnabled) {
      currentType = DeliveryType.delivery;
    }

    _selectedType = currentType;
    context.read<DeliveryFeeCubit>().updateDeliveryType(_selectedType);
  }

  // --- Lógica de Busca ---
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (_showSearchResults) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _isSearching = false;
        });
      }
      return;
    }
    if (query.length < 3) return;
    
    // ✅ Sempre inicia a busca - o debounce no _performSearch cuida de cancelar buscas antigas
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
    if (!mounted) return;
    
    print('🔍 [AddressSearch] Iniciando busca: "$query"');
    
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600)); // Debounce
      if (!mounted || _searchController.text.trim() != query) {
        print('⚠️ [AddressSearch] Busca cancelada - query mudou');
        // ✅ CORREÇÃO: Não reseta isSearching aqui pois outra busca já foi iniciada
        // Se a query estiver vazia, reseta o estado
        if (mounted && _searchController.text.trim().isEmpty) {
          setState(() {
            _isSearching = false;
            _showSearchResults = false;
          });
        }
        return;
      }

      final (lat, lon) = _getCustomerCoordinates();
      print('🔍 [AddressSearch] Coordenadas: lat=$lat, lon=$lon');
      
      final results = await _searchService.searchAddresses(
        input: query,
        userLatitude: lat,
        userLongitude: lon,
      );
      
      print('✅ [AddressSearch] ${results.length} resultados encontrados');
      
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ [AddressSearch] Erro: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _showSearchResults = false;
    });
  }

  void _onSearchResultSelected(AddressSearchResult result) async {
      // Quando seleciona um resultado da busca na PÁGINA, 
      // abrimos o Bottom Sheet JÁ no step de mapa/formulário
      // para completar o cadastro.
      
      _searchFocusNode.unfocus();

      // Busca detalhes se necessário
      AddressSearchResult finalResult = result;
      if (result.placeId != null) {
        final details = await _searchService.getAddressDetails(result.placeId!);
        if (details != null) {
          finalResult = details;
        }
      }

      if (!mounted) return;

      // Cria um CustomerAddress temporário para passar pro modal
      // ou passa null e o modal inicia com os dados da busca se implementarmos isso.
      // Atualmente o BottomSheet tem "startWithSearch".
      // Vamos abrir o bottom sheet e preencher os controllers lá?
      // Melhor: O BottomSheet é autônomo. Se clicou num resultado AQUI,
      // idealmente passamos esse resultado para o BottomSheet já abrir no mapa.
      // Como o BottomSheet atual não aceita "initialSearchResult", 
      // vamos abrir o bottom sheet normal (startWithSearch: true) e o usuário busca lá denovo?
      // NÃO, isso é ruim UX.
      
      // SOLUÇÃO: Vamos abrir o BottomSheet e fazer ele iniciar com esse endereço.
      // Vou adaptar o AddressSelectionBottomSheet para aceitar um 'initialSearchResult'.
      // Por enquanto, como não posso editar o BottomSheet agora (estou editando ESTE arquivo),
      // vou abrir o BottomSheet em modo de busca mesmo, mas idealmente passaria o resultado.
      
      // Mas espere! O AddressSearchAndListStep JÁ É o corpo do BottomSheet.
      // Se eu estou REUSANDO o AddressSearchAndListStep aqui, eu tenho a mesma UI.
      
      // Vamos abrir o BottomSheet passando o startWithSearch: true
      // O usuário vai ter que buscar de novo, infelizmente, até eu refatorar o BottomSheet
      // para aceitar um resultado inicial.
      // OU: Eu passo um "fake" addressToEdit com os dados que tenho.
      
      final tempAddress = CustomerAddress(
        street: finalResult.street ?? finalResult.description,
        number: finalResult.number ?? '',
        neighborhood: finalResult.neighborhood ?? '',
        city: finalResult.city ?? '',
        latitude: finalResult.latitude,
        longitude: finalResult.longitude, 
        label: 'Novo Endereço', 
        isFavorite: true
      );

      AddressSelectionBottomSheet.show(
        context, 
        addressToEdit: tempAddress, // Truque para abrir já no formulário
        // Precisamos garantir que o ID seja null para criar um novo
      ).then((_) {
        // ✅ Limpa o estado de busca quando voltar do bottom sheet
        if (mounted) {
          _onClearSearch();
          _searchFocusNode.unfocus();
        }
      });
  }

  void _onAddressTap(CustomerAddress address) async {
    final store = context.read<StoreCubit>().state.store;
    final addressState = context.read<AddressCubit>().state;
    final feeCubit = context.read<DeliveryFeeCubit>();
    
    // 0. Se for retirada, seleciona direto
    if (feeCubit.state.deliveryType == DeliveryType.pickup) {
       context.read<AddressCubit>().selectAddress(address);
       return;
    }

    // ✅ NOVO: Validação Instantânea via Cache (o que você sugeriu)
    final feeCached = address.id != null ? addressState.addressFees[address.id] : null;
    if (feeCached == -1.0) {
      // Já sabemos que é fora da área
      if (mounted && store != null) {
        _showOutOfAreaDialog(context, store.name);
      }
      return; // Nem deixa selecionar se estiver fora
    }

    // 1. Marca como "tentativa de seleção"
    await context.read<AddressCubit>().selectAddress(address);

    if (store != null) {
      final subtotalRaw = context.read<CartCubit>().state.cart.subtotal;
      final subtotal = subtotalRaw / 100.0;

      String? errorMsg;
      await feeCubit.calculate(
        address: address,
        store: store,
        cartSubtotal: subtotal,
        onResult: (fee, error) => errorMsg = error,
      );

      if (mounted && errorMsg != null) {
        _showOutOfAreaDialog(context, store.name);
      }
    }
  }

  void _onSavedAddressSelected(CustomerAddress address) async {
    final store = context.read<StoreCubit>().state.store;
    final subtotalRaw = context.read<CartCubit>().state.cart.subtotal;
    final subtotal = subtotalRaw / 100.0;
    
    final feeCubit = context.read<DeliveryFeeCubit>();
    if (feeCubit.state.deliveryType == DeliveryType.pickup) {
       await context.read<AddressCubit>().selectAddress(address);
       if (mounted && context.canPop()) context.pop();
       return;
    }

    if (store != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFEA1D2C))),
      );

      String? errorMsg;
      await feeCubit.calculate(
        address: address,
        store: store,
        cartSubtotal: subtotal,
        onResult: (fee, error) => errorMsg = error,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (errorMsg != null) {
        _showOutOfAreaDialog(context, store.name);
        return;
      }
    }

    await context.read<AddressCubit>().selectAddress(address);
    if (mounted && context.canPop()) {
      context.pop();
    }
  }

  void _showOutOfAreaDialog(BuildContext context, String storeName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$storeName não entrega neste endereço.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F3E3E),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Infelizmente este restaurante não realiza entregas nesta região. Por favor, selecione outro endereço para continuar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(bottomSheetContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA1D2C),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Trocar endereço',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(bottomSheetContext),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Voltar',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFEA1D2C), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ENDEREÇOS',
          style: TextStyle(
            color: Color(0xFF3E3E3E),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF5F5F5), height: 1),
        ),
      ),
      body: AddressCheckoutSelectionStep(
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        searchResults: _searchResults,
        isSearching: _isSearching,
        showSearchResults: _showSearchResults,
        onClearSearch: _onClearSearch,
        onSearchResultSelected: _onSearchResultSelected,
        onSavedAddressSelected: _onSavedAddressSelected,
        onAddressTap: _onAddressTap, // ✅ Conecta o callback de validação imediata
        onEditAddress: (address) {
          AddressSelectionBottomSheet.show(context, addressToEdit: address);
        },
        onDeleteAddress: (address) {
          if (address.id != null) {
            final customerId = context.read<AuthCubit>().state.customer?.id;
            if (customerId != null) {
              context.read<AddressCubit>().deleteAddress(customerId, address.id!);
            }
          }
        },
        onSearchChanged: _onSearchChanged,
      ),
    );
  }
}