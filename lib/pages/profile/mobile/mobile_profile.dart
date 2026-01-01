import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/pages/profile/widgets/not_logged_in_view.dart';
import 'package:totem/pages/profile/widgets/profile_menu_item.dart';

/// Mobile Profile Page - Estilo iFood
/// Implementação específica para dispositivos móveis
class MobileProfile extends StatelessWidget {
  const MobileProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Remove AppBar para ficar no estilo iFood (sem barra de título)
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
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
                child: const NotLoggedInView(isDesktop: false),
              );
            }

            // ✅ Quando logado, mostra perfil do usuário
            return _buildLoggedInView(context, customer);
          },
        ),
      ),
    );
  }

  // ✅ View quando usuário está logado
  Widget _buildLoggedInView(BuildContext context, dynamic customer) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ✅ Header do perfil
          _buildProfileHeader(context, customer),
          
          const SizedBox(height: 16),
          
          // ✅ Menu de opções
          Container(
            color: Colors.white,
            child: Column(
              children: [
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
                  icon: Icons.location_on_outlined,
                  title: 'Meus endereços',
                  onTap: () => context.push('/select-address'),
                ),
                ProfileMenuItem(
                  icon: Icons.local_offer_outlined,
                  title: 'Cupons',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Em breve')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Separador
          Container(
            height: 8,
            color: Colors.grey.shade100,
          ),
          
          // ✅ Opções secundárias
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ProfileMenuItem(
                  icon: Icons.help_outline,
                  title: 'Ajuda',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Em breve')),
                    );
                  },
                ),
                ProfileMenuItem(
                  icon: Icons.logout,
                  title: 'Sair',
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  showChevron: false,
                  onTap: () {
                    context.read<AuthCubit>().signOut();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ✅ Header do perfil (quando logado)
  Widget _buildProfileHeader(BuildContext context, dynamic customer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: Colors.white,
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: customer.photo != null
                ? NetworkImage(customer.photo!)
                : null,
            child: customer.photo == null
                ? Icon(Icons.person, size: 32, color: Colors.grey.shade500)
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Nome e email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name ?? 'Usuário',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
          
          // Botão de editar
          IconButton(
            onPressed: () => context.push('/profile/edit'),
            icon: Icon(
              Icons.edit_outlined,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
