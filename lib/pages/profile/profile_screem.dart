// lib/pages/profile/profile_screem.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/widgets/ds_primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        centerTitle: true,
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final customer = state.customer;

          if (customer == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Você precisa estar logado para ver seu perfil'),
                  const SizedBox(height: 16),
                  DsPrimaryButton(
                    onPressed: () => context.push('/auth/signin'),
                    label: 'Fazer login',
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: customer.photo != null
                      ? NetworkImage(customer.photo!)
                      : null,
                  child: customer.photo == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  customer.name ?? 'Usuário',
                  style: Theme.of(context).textTheme.headlineSmall,
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
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Histórico de pedidos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Carrega histórico antes de navegar
                    if (customer.id != null) {
                      context.read<ProfileCubit>().loadOrderHistory(customer.id!);
                      context.push('/orders/history');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar perfil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Meus endereços'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/address'),
                ),
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Formas de pagamento'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Implementar formas de pagamento
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Em breve')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sair', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    context.read<AuthCubit>().signOut();
                    context.go('/');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
