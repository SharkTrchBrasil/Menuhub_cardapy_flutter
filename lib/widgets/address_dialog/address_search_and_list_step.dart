import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/services/address_search_service.dart';

/// Step 0: Tela de busca + lista de endereços salvos (Versão Enterprise/Desktop)
class AddressSearchAndListStep extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<AddressSearchResult> searchResults;
  final bool isSearching;
  final bool showSearchResults;
  final VoidCallback onClearSearch;
  final Function(AddressSearchResult) onSearchResultSelected;
  final Function(CustomerAddress) onSavedAddressSelected;
  final bool isManagement;
  final bool isDesktop;
  final VoidCallback? onSearchChanged;

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
    this.isManagement = false,
    this.isDesktop = false,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, state) {
        final addresses = state.addresses;
        final selectedAddress = state.selectedAddress;
        final isLoading = state.status == AddressStatus.loading;

        return Container(
          color: Colors.white,
          child: Column(
            key: const ValueKey('searchAndList'),
            children: [
              // Ilustração com asset (Oculto se for gerenciamento)
              if (!isManagement) _buildIllustration(),

              // Título e subtítulo (Oculto se for gerenciamento)
              if (!isManagement) _buildTitleSection(),

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
        'assets/address.webp',
        width: 199,
        height: 113,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        controller: searchController,
        focusNode: searchFocusNode,
        onChanged: (_) => onSearchChanged?.call(),
        decoration: InputDecoration(
          hintText: 'Buscar endereço e número',
          prefixIcon: const Icon(Icons.search, color: Color(0xFFEA1D2C)),
          suffixIcon: searchController.text.isNotEmpty
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
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined, color: Color(0xFF666666)),
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

    if (addresses.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum endereço salvo',
          style: TextStyle(color: Color(0xFF666666)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final isSelected = selectedAddress?.id == address.id;

        return _buildAddressListItem(context, address, isSelected);
      },
    );
  }

  Widget _buildAddressListItem(BuildContext context, CustomerAddress address, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFEA1D2C) : const Color(0xFFF5F5F5),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.home_outlined, color: Color(0xFF3F3E3E), size: 20),
        ),
        title: Column(
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
        onTap: () => onSavedAddressSelected(address),
      ),
    );
  }
}
