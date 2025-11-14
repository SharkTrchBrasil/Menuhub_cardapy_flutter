import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';

/// Profile Tab Page - Versão otimizada para funcionar como tab
class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: !isDesktop,
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (previous, current) =>
            previous.customer != current.customer,
        builder: (context, state) {
          final customer = state.customer;

          if (customer == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'Você precisa estar logado para ver seu perfil',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  DsPrimaryButton(
                    onPressed: () => context.push('/auth/signin'),
                    label: 'Fazer login',
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: isDesktop ? 60 : 50,
                      backgroundImage: customer.photo != null
                          ? NetworkImage(customer.photo!)
                          : null,
                      child: customer.photo == null
                          ? Icon(Icons.person,
                              size: isDesktop ? 60 : 50)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      customer.name ?? 'Usuário',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (customer.email != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        customer.email!,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    _ProfileMenuItem(
                      icon: Icons.history,
                      title: 'Histórico de pedidos',
                      onTap: () {
                        if (customer.id != null) {
                          context.read<ProfileCubit>().loadOrderHistory(customer.id!);
                          context.push('/orders/history');
                        }
                      },
                    ),
                    _ProfileMenuItem(
                      icon: Icons.edit,
                      title: 'Editar perfil',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.location_on,
                      title: 'Meus endereços',
                      onTap: () => context.push('/select-address'),
                    ),
                    _ProfileMenuItem(
                      icon: Icons.payment,
                      title: 'Formas de pagamento',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Em breve')),
                        );
                      },
                    ),
                    const Divider(height: 32),
                    _ProfileMenuItem(
                      icon: Icons.logout,
                      title: 'Sair',
                      iconColor: Colors.red,
                      textColor: Colors.red,
                      onTap: () {
                        context.read<AuthCubit>().signOut();
                        // Não navega para home pois já estamos na tab
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

