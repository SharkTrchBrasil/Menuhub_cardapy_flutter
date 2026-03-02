import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/models/delivery_type.dart';
import 'package:totem/services/address_search_service.dart';

/// Step Moderno: Layout para Mobile/Checkout (Conforme Imagem 2)
class AddressCheckoutSelectionStep extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<AddressSearchResult> searchResults;
  final bool isSearching;
  final bool showSearchResults;
  final VoidCallback onClearSearch;
  final Function(AddressSearchResult) onSearchResultSelected;
  final Function(CustomerAddress) onSavedAddressSelected;
  final Function(CustomerAddress)? onAddressTap;
  final Function(CustomerAddress)? onEditAddress;
  final Function(CustomerAddress)? onDeleteAddress;
  final VoidCallback? onSearchChanged;

  const AddressCheckoutSelectionStep({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResults,
    required this.isSearching,
    required this.showSearchResults,
    required this.onClearSearch,
    required this.onSearchResultSelected,
    required this.onSavedAddressSelected,
    this.onAddressTap,
    this.onEditAddress,
    this.onDeleteAddress,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, state) {
        final addresses = state.addresses;
        final selectedAddress = state.selectedAddress;
        final isLoading = state.status == AddressStatus.loading;

        // Ocultar lista e botão se estiver buscando, se o campo tiver texto ou se estiver focado (Imagem 2)
        final isSearchingFlow =
            showSearchResults ||
            searchController.text.isNotEmpty ||
            searchFocusNode.hasFocus;

        return Column(
          children: [
            // 1. Toggles de Entrega/Retirada
            if (!isSearchingFlow) _buildDeliveryToggles(context),

            // 2. Campo de busca
            _buildSearchField(context),

            // 3. Resultados da busca OR Lista de endereços salvos
            Expanded(
              child:
                  isSearchingFlow
                      ? _buildSearchResults(context)
                      : _buildSavedAddressesList(
                        context,
                        addresses,
                        selectedAddress,
                        isLoading,
                      ),
            ),

            // 4. Botão Confirmar Fixo
            if (!isSearchingFlow && selectedAddress != null)
              _buildConfirmButton(context, selectedAddress),
          ],
        );
      },
    );
  }

  Widget _buildDeliveryToggles(BuildContext context) {
    return BlocBuilder<DeliveryFeeCubit, DeliveryFeeState>(
      builder: (context, state) {
        final deliveryType = state.deliveryType;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleItem(
                  context,
                  label: 'Entregar no endereço',
                  isSelected: deliveryType == DeliveryType.delivery,
                  onTap:
                      () => context.read<DeliveryFeeCubit>().updateDeliveryType(
                        DeliveryType.delivery,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildToggleItem(
                  context,
                  label: 'Retirar na loja',
                  isSelected: deliveryType == DeliveryType.pickup,
                  onTap:
                      () => context.read<DeliveryFeeCubit>().updateDeliveryType(
                        DeliveryType.pickup,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleItem(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF3E3E3E),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final hasText = searchController.text.isNotEmpty;
    final isFocused = searchFocusNode.hasFocus;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: (_) => onSearchChanged?.call(),
            readOnly: false,
            enableInteractiveSelection: true,
            showCursor: true,
            decoration: InputDecoration(
              hintText: 'Endereço e número',
              // Seta de voltar à esquerda se estiver focado ou com texto (Imagem 2)
              prefixIcon:
                  (isFocused || hasText)
                      ? IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.black,
                          size: 18,
                        ),
                        onPressed: onClearSearch,
                      )
                      : const Icon(Icons.search, color: Colors.black),
              suffixIcon:
                  hasText
                      ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onClearSearch,
                      )
                      : null,
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Linear Indicator vermelho abaixo do search (Imagem 2)
        if (isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: LinearProgressIndicator(
              color: Colors.black,
              backgroundColor: Color(0xFFF5F5F5),
              minHeight: 2,
            ),
          )
        else
          const SizedBox(
            height: 2,
          ), // Espaço reservado para evitar pulos no layout
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (searchResults.isEmpty && !isSearching) {
      // Se não há resultados e não está buscando, mostra dica sutil
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Digite o endereço completo para buscar',
            style: TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: searchResults.length,
      separatorBuilder:
          (context, index) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return ListTile(
          leading: const Icon(
            Icons.location_on_outlined,
            color: Color(0xFF666666),
          ),
          title: Text(
            result.description,
            style: const TextStyle(fontSize: 14, color: Color(0xFF3F3E3E)),
          ),
          onTap: () => onSearchResultSelected(result),
        );
      },
    );
  }

  Widget _buildSavedAddressesList(
    BuildContext context,
    List<CustomerAddress> addresses,
    CustomerAddress? selectedAddress,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final addressState = context.read<AddressCubit>().state;
        final isSelected = selectedAddress?.id == address.id;

        // Verifica se o endereço está fora da área de entrega (marcado como -1.0 no Cubit)
        final fee =
            address.id != null ? addressState.addressFees[address.id] : null;
        final isOutOfArea = fee == -1.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.black : const Color(0xFFF5F5F5),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const Icon(
              Icons.home_outlined,
              color: Color(0xFF3E3E3E),
              size: 24,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF666666)),
              onPressed: () => _showAddressOptions(context, address),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    address.label.isNotEmpty ? address.label : 'Endereço',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E3E3E),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.black, size: 20),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${address.street}, ${address.number}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                Text(
                  '${address.neighborhood} - ${address.city}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            onTap: () {
              if (onAddressTap != null) {
                onAddressTap!(address);
              } else {
                context.read<AddressCubit>().selectAddress(address);
              }
            },
          ),
        );
      },
    );
  }

  void _showAddressOptions(BuildContext context, CustomerAddress address) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  address.label.isNotEmpty
                      ? address.label
                      : '${address.street}, ${address.number}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F3E3E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address.neighborhood}, ${address.city}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onDeleteAddress?.call(address);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFF5F5F5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Color(0xFF3E3E3E),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Excluir',
                              style: TextStyle(
                                color: Color(0xFF3E3E3E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onEditAddress?.call(address);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFF5F5F5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF3E3E3E),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Editar',
                              style: TextStyle(
                                color: Color(0xFF3E3E3E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildConfirmButton(
    BuildContext context,
    CustomerAddress selectedAddress,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => onSavedAddressSelected(selectedAddress),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text(
          'Confirmar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
