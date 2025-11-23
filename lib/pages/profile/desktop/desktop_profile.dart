import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/pages/profile/widgets/not_logged_in_view.dart';
import 'package:totem/pages/profile/widgets/profile_menu_item.dart';

/// Desktop Profile Page
/// Implementação específica para desktop
class DesktopProfile extends StatelessWidget {
  const DesktopProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (previous, current) => previous.customer != current.customer,
        builder: (context, state) {
          final customer = state.customer;

          if (customer == null) {
            return BlocListener<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state.status == AuthStatus.error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage ?? 'Ocorreu um erro no login.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const NotLoggedInView(isDesktop: true),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: customer.photo != null
                          ? NetworkImage(customer.photo!)
                          : null,
                      child: customer.photo == null
                          ? const Icon(Icons.person, size: 60)
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ProfileMenuItem(
                      icon: Icons.history,
                      title: 'Histórico de pedidos',
                      onTap: () {
                        if (customer.id != null) {
                          context.read<ProfileCubit>().loadOrderHistory(customer.id!);
                          context.push('/orders/history');
                        }
                      },
                    ),
                    ProfileMenuItem(
                      icon: Icons.edit,
                      title: 'Editar perfil',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    ProfileMenuItem(
                      icon: Icons.location_on,
                      title: 'Meus endereços',
                      onTap: () => context.push('/select-address'),
                    ),
                    ProfileMenuItem(
                      icon: Icons.payment,
                      title: 'Formas de pagamento',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Em breve')),
                        );
                      },
                    ),
                    const Divider(height: 32),
                    ProfileMenuItem(
                      icon: Icons.logout,
                      title: 'Sair',
                      iconColor: Colors.red,
                      textColor: Colors.red,
                      onTap: () {
                        context.read<AuthCubit>().signOut();
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
