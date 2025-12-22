import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/models/customer_address.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/core/extensions.dart';
import 'package:totem/widgets/address_selection_dialog.dart';
import 'package:totem/widgets/cart_side_panel.dart';
import 'package:totem/widgets/profile_side_panel.dart';

/// AppBar Desktop - Versão Responsiva
class DesktopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController? searchController;
  final VoidCallback? onSearchChanged;

  const DesktopAppBar({super.key, this.searchController, this.onSearchChanged});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final storeState = context.watch<StoreCubit>().state;
    final store = storeState.store;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Definição de breakpoints para responsividade
        final isLargeScreen = screenWidth > 1200;
        final isMediumScreen = screenWidth > 768;
        final isSmallScreen = screenWidth <= 768;

        return Container(
          height: 70,
          decoration: BoxDecoration(color: Colors.white),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 32,
              vertical: 12,
            ),
            child: Row(
              children: [
                // Logo + Nome (Lado Esquerdo - Menor espaço)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo da Loja
                    if (store?.image?.url != null)
                      Container(
                        width: isSmallScreen ? 40 : 50,
                        height: isSmallScreen ? 40 : 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(store!.image!.url),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: isSmallScreen ? 40 : 50,
                        height: isSmallScreen ? 40 : 50,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.store,
                          color: theme.primaryColor,
                          size: isSmallScreen ? 20 : 28,
                        ),
                      ),
                    SizedBox(width: isSmallScreen ? 12 : 16),

                    // Nome da Loja - Esconder em telas muito pequenas
                    if (!isSmallScreen)
                      Text(
                        'Inicio',
                        style: TextStyle(
                          fontSize: isMediumScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: theme.onBackgroundColor,
                        ),
                      ),
                  ],
                ),

                // Espaçamento entre logo e busca
                SizedBox(width: isLargeScreen ? 32 : (isMediumScreen ? 24 : 16)),

                // Barra de Busca (Centro - Maior espaço)
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Container(
                      height: 42,
                      constraints: BoxConstraints(
                        maxWidth:
                            isLargeScreen
                                ? 600
                                : isMediumScreen
                                ? 500
                                : 400,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => onSearchChanged?.call(),
                        decoration: InputDecoration(
                          hintText: 'Buscar no cardápio...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade600,
                            size: isSmallScreen ? 16 : 20,
                          ),
                          suffixIcon:
                              searchController?.text.isNotEmpty == true
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade600,
                                      size: isSmallScreen ? 14 : 18,
                                    ),
                                    onPressed: () {
                                      searchController?.clear();
                                      onSearchChanged?.call();
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 12,
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 13,
                        ),
                      ),
                    ),
                  ),
                ),

                // Espaçamento entre busca e elementos da direita
                SizedBox(width: isLargeScreen ? 24 : (isMediumScreen ? 16 : 12)),

                // Elementos da Direita (Endereço + Perfil + Carrinho)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Endereço de Entrega - Versão compacta em telas menores
                    if (isMediumScreen || isLargeScreen)
                      _buildAddressButton(context, theme, isMediumScreen),

                    if (isMediumScreen || isLargeScreen)
                      SizedBox(width: isMediumScreen ? 12 : 16),

                    // Ícone do Perfil
                    _buildProfileButton(context, theme, isSmallScreen),

                    SizedBox(width: isSmallScreen ? 8 : (isMediumScreen ? 12 : 16)),

                    // Carrinho com Resumo
                    _buildCartButton(context, theme, isSmallScreen),
                  ],
                ),
              ],
            ),




          ));



      },
    );
  }

  Widget _buildAddressButton(BuildContext context, theme, bool isMediumScreen) {
    final authState = context.watch<AuthCubit>().state;
    final customer = authState.customer;
    
    // Se cliente não está logado, mostra apenas texto "Escolha um endereço"
    if (customer == null) {
      return InkWell(
        onTap: () => context.push('/onboarding'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMediumScreen ? 8 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escolha um endereço',
                style: TextStyle(
                  fontSize: isMediumScreen ? 13 : 15,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(width: isMediumScreen ? 4 : 6),
              Icon(
                Icons.keyboard_arrow_down,
                size: isMediumScreen ? 16 : 18,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      );
    }

    // Cliente logado: mostra apenas o nome da rua (sem ícone, sem "Entregar em")
    return BlocBuilder<AddressCubit, AddressState>(
      builder: (context, addressState) {
        // Carrega endereços se ainda não foram carregados
        if (addressState.status == AddressStatus.initial && customer.id != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<AddressCubit>().loadAddresses(customer.id!);
          });
        }

        final selectedAddress = addressState.selectedAddress;
        final hasAddress = selectedAddress != null;

        return InkWell(
          onTap: () => _showAddressDialog(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMediumScreen ? 6 : 8,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: isMediumScreen ? 100 : 140,
                  child: Text(
                    hasAddress
                        ? _formatAddress(selectedAddress!, isMediumScreen)
                        : 'Escolha um endereço',
                    style: TextStyle(
                      fontSize: isMediumScreen ? 12 : 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: isMediumScreen ? 3 : 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: isMediumScreen ? 14 : 16,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAddress(CustomerAddress address, bool isMediumScreen) {
    // Formata o endereço de forma compacta para o AppBar
    final parts = <String>[];
    if (address.street.isNotEmpty) {
      parts.add(address.street);
    }
    if (address.number.isNotEmpty) {
      parts.add(address.number);
    }
    
    if (parts.isEmpty) {
      return 'Selecionar endereço';
    }
    
    final addressLine = parts.join(', ');
    
    // Limita o tamanho para telas menores
    if (isMediumScreen && addressLine.length > 15) {
      return '${addressLine.substring(0, 15)}...';
    } else if (!isMediumScreen && addressLine.length > 25) {
      return '${addressLine.substring(0, 25)}...';
    }
    
    return addressLine;
  }

  void _showAddressDialog(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final customer = authState.customer;
    
    // Se não está logado, redireciona para página de login full screen
    if (customer?.id == null) {
      context.push('/onboarding');
      return;
    }

    final addressCubit = context.read<AddressCubit>();
    
    // Garante que os endereços estão carregados
    if (addressCubit.state.status == AddressStatus.initial) {
      addressCubit.loadAddresses(customer!.id!);
    }

    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: addressCubit,
        child: const AddressSelectionDialog(),
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, theme, bool isSmallScreen) {
    final authState = context.watch<AuthCubit>().state;
    final customer = authState.customer;

    return InkWell(
      onTap: () {
        // Se não estiver logado, redireciona para login
        if (customer == null) {
          context.push('/onboarding');
        } else {
          // Se estiver logado, abre sidepanel do perfil
          final isDesktop = MediaQuery.of(context).size.width >= 768;
          if (isDesktop) {
            showProfileSidePanel(context);
          } else {
            context.push('/profile');
          }
        }
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: isSmallScreen ? 40 : 46,
        height: isSmallScreen ? 40 : 46,

        child: customer == null
            ? Icon(
                Icons.login_outlined,
                color: theme.primaryColor,
                size: isSmallScreen ? 20 : 24,
              )

                : Icon(
                    Icons.person_outline,
                    color: Theme.of(context).primaryColor,

                    size: isSmallScreen ? 20 : 24,
                  ),
      ),
    );
  }

  Widget _buildCartButton(BuildContext context, theme, bool isSmallScreen) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        final cart = cartState.cart;
        final itemCount = cart.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );
        final total = cart.total / 100.0;
        final isEmpty = cart.items.isEmpty;

        return InkWell(
          onTap: () {
            // Em desktop, abre sidepanel. Em mobile, usa rota normal
            final isDesktop = MediaQuery.of(context).size.width >= 768;
            if (isDesktop) {
              showCartSidePanel(context);
            } else {
              context.push('/cart');
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(
              minHeight: isSmallScreen ? 40 : 46,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : (isEmpty ? 12 : 12),
              vertical: isEmpty ? 8 : (isSmallScreen ? 4 : 6),
            ),
            decoration: BoxDecoration(
              color: isEmpty ? Colors.grey.shade100 : theme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isEmpty
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey.shade600,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone do Carrinho com Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: isSmallScreen ? 18 : 22,
                          ),

                        ],
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 10),
                      // Valor Total e quantidade de itens (só mostra texto em telas maiores)
                      isSmallScreen
                          ? Text(
                              total.toCurrency(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  total.toCurrency(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,

                                  ),
                                ),
                                SizedBox(height: 2,),
                                Text(
                                  '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 10,

                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
