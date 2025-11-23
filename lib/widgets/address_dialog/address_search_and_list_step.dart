import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/services/address_search_service.dart';

/// Step 0: Tela de busca + lista de endereços salvos - Estilo iFood
class AddressSearchAndListStep extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<AddressSearchResult> searchResults;
  final bool isSearching;
  final bool showSearchResults;
  final VoidCallback onClearSearch;
  final Function(AddressSearchResult) onSearchResultSelected;
  final Function(CustomerAddress) onSavedAddressSelected;

  const AddressSearchAndListStep({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchResults,
    required this.isSearching,
    required this.showSearchResults,
    required this.onClearSearch,
    required this.onSearchResultSelected,
    required this.onSavedAddressSelected,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, state) {
        final customer = context.read<AuthCubit>().state.customer;

        if (customer?.id != null && state.status == AddressStatus.initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AddressCubit>().loadAddresses(customer!.id!);
          });
        }

        final addresses = state.addresses;
        final selectedAddress = state.selectedAddress;
        final isLoading = state.status == AddressStatus.loading && addresses.isEmpty;

        return Container(
          color: Colors.white,
          child: Column(
            key: const ValueKey('searchAndList'),
            children: [
              // Ilustração com asset
              _buildIllustration(),

              // Título e subtítulo
              _buildTitleSection(),

              // Campo de busca
              _buildSearchField(context),

              // Resultados da busca OU Lista de endereços salvos
              Expanded(
                child: showSearchResults && searchResults.isNotEmpty
                    ? _buildSearchResults(context)
                    : _buildSavedAddressesList(context, addresses, selectedAddress, isLoading),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIllustration() {
    return Container(
      height: 150,
      margin: const EdgeInsets.only(top: 40, bottom: 20),
      child: Image.asset(
        'assets/address.webp', // ✅ SEU ASSET AQUI
        width: 199, // Largura similar ao design original
        height: 113, // Altura similar ao design original
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback caso o asset não seja encontrado
          return Container(
            width: 199,
            height: 113,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFEDF4).withOpacity(0.8),
                  const Color(0xFFFFEDF4).withOpacity(0),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              size: 60,
              color: Color(0xFFE8B1B4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleSection() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Onde você quer receber seu pedido?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'As entregas são feitas no portão ou portaria.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Campo de texto
            TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Buscar endereço e número',
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(left: 16, right: 56, top: 18, bottom: 18),
                hintStyle: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 16,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF3F3E3E),
              ),
            ),

            // Ícone de busca (botão transparente sobre todo o campo)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    // Foca no campo de busca quando clicar em qualquer área
                    searchFocusNode.requestFocus();
                  },
                  child: Container(),
                ),
              ),
            ),

            // Ícone de lupa
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF3F3E3E),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: searchResults.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildSearchResultItem(AddressSearchResult result) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSearchResultSelected(result),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.street ?? result.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3F3E3E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.neighborhood != null || result.city != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${result.neighborhood ?? ''}, ${result.city ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAddressesList(
      BuildContext context,
      List<CustomerAddress> addresses,
      CustomerAddress? selectedAddress,
      bool isLoading,
      ) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA1D2C)),
          ),
        ),
      );
    }

    if (addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum endereço cadastrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use a busca acima para adicionar um endereço',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final isSelected = selectedAddress?.id == address.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildAddressListItem(
            address: address,
            isSelected: isSelected,
            onTap: () => onSavedAddressSelected(address),
          ),
        );
      },
    );
  }

  Widget _buildAddressListItem({
    required CustomerAddress address,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Define ícone baseado no tipo de endereço
    IconData icon = Icons.location_on_outlined;
    Color iconColor = const Color(0xFF3F3E3E);
    Color iconBgColor = const Color(0xFFF5F5F5);

    if (address.label.toLowerCase().contains('casa')) {
      icon = Icons.home_outlined;
    } else if (address.label.toLowerCase().contains('trabalho')) {
      icon = Icons.work_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFFEA1D2C) : const Color(0xFFE0E0E0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Ícone à esquerda
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Informações do endereço
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.label.isNotEmpty ? address.label : 'Endereço',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3F3E3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address.street}, ${address.number}${address.complement?.isNotEmpty == true ? ', ${address.complement}' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                ),

                // Ícone de três pontos à direita
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Color(0xFF999999),
                    size: 20,
                  ),
                  onPressed: () {
                    // TODO: Implementar ações do endereço
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}