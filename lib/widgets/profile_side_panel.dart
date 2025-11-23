import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/core/di.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/order_repository.dart';

/// Função helper para abrir o sidepanel do perfil
void showProfileSidePanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Perfil',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const ProfileSidePanel();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Animação de slide da direita para esquerda
      final slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0), // Começa da direita
        end: Offset.zero, // Termina na posição normal
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ));

      return SlideTransition(
        position: slideAnimation,
        child: child,
      );
    },
  );
}

/// SidePanel do perfil que desliza da direita para esquerda (estilo iFood)
class ProfileSidePanel extends StatelessWidget {
  const ProfileSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.4; // 40% da largura da tela
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth,
          constraints: const BoxConstraints(maxWidth: 400), // Limite máximo
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final customer = authState.customer;

              if (customer == null) {
                return const Center(
                  child: Text('Erro: usuário não encontrado'),
                );
              }

              return BlocProvider(
                create: (context) => ProfileCubit(
                  customerRepository: getIt<CustomerRepository>(),
                  orderRepository: getIt<OrderRepository>(),
                ),
                child: Column(
                  children: [
                    // Header do SidePanel
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Olá, ${customer.name?.split(' ').first ?? 'Usuário'}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.onBackgroundColor,
                                  ),
                                ),
                                if (customer.email != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    customer.email!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey.shade600),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Fechar',
                          ),
                        ],
                      ),
                    ),
                    // Conteúdo do menu
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            // Pedidos
                            _ProfileMenuItem(
                              icon: Icons.receipt_long,
                              title: 'Pedidos',
                              onTap: () {
                                Navigator.of(context).pop();
                                if (customer.id != null) {
                                  context.read<ProfileCubit>().loadOrderHistory(customer.id!);
                                  context.push('/orders/history');
                                }
                              },
                            ),
                          // Cupons
                          _ProfileMenuItem(
                            icon: Icons.local_offer,
                            title: 'Meus Cupons',
                            iconColor: theme.primaryColor,
                            textColor: theme.primaryColor,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/coupons');
                            },
                          ),
                          // Favoritos
                          _ProfileMenuItem(
                            icon: Icons.favorite_border,
                            title: 'Favoritos',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Em breve')),
                              );
                            },
                          ),
                          // Pagamento
                          _ProfileMenuItem(
                            icon: Icons.payment,
                            title: 'Pagamento',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Em breve')),
                              );
                            },
                          ),
                          // Fidelidade
                          _ProfileMenuItem(
                            icon: Icons.stars,
                            title: 'Fidelidade',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Em breve')),
                              );
                            },
                          ),
                          // Ajuda
                          _ProfileMenuItem(
                            icon: Icons.help_outline,
                            title: 'Ajuda',
                            onTap: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Em breve')),
                              );
                            },
                          ),
                          // Meus dados
                          _ProfileMenuItem(
                            icon: Icons.person_outline,
                            title: 'Meus dados',
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/profile/edit');
                            },
                          ),
                          const Divider(height: 32),
                          // Sair
                          _ProfileMenuItem(
                            icon: Icons.logout,
                            title: 'Sair',
                            iconColor: Colors.red,
                            textColor: Colors.red,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.read<AuthCubit>().signOut();
                            },
                          ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Item do menu do perfil
class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.grey.shade700,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor ?? Colors.grey.shade900,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

