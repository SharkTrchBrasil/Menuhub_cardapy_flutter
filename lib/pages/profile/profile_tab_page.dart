import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
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
              child: _NotLoggedInView(isDesktop: isDesktop),
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

/// ✅ NOVO: Tela de perfil quando não está logado - Design moderno e atrativo
class _NotLoggedInView extends StatelessWidget {
  final bool isDesktop;

  const _NotLoggedInView({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;
    final maxWidth = isDesktop ? 600.0 : double.infinity;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    
                    // ✅ Seção principal: Login/Cadastro
                    _LoginSection(theme: theme, isDesktop: isDesktop),

                  ],
                ),
              ),
            ),
          ),
        ),
        
        // ✅ Overlay de loading durante autenticação
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state.status == AuthStatus.loading) {
              return Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Seção de login/cadastro destacada - Integrada com login Google direto
class _LoginSection extends StatelessWidget {
  final theme;
  final bool isDesktop;

  const _LoginSection({required this.theme, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isLoading = authState.status == AuthStatus.loading;
        
        return Card(
          elevation: 0,

          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Ícone de perfil
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 48,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Título
                Text(
                  'Falta um clique para matar sua fome!',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: theme.onBackgroundColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Descrição
                Text(
                  'Como deseja continuar?',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // ✅ Botão de login com Google (direto, sem navegação)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          // ✅ Chama login direto, sem navegar para tela separada
                          context.read<AuthCubit>().signInWithGoogle();
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ✅ Tenta usar SVG primeiro, fallback para PNG
                            Builder(
                              builder: (context) {
                                try {
                                  return SvgPicture.asset(
                                    'assets/images/google.svg',
                                    height: 24,
                                    width: 24,
                                  );
                                } catch (e) {
                                  // Fallback para PNG se SVG não existir
                                  return Image.asset(
                                    'assets/images/google.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Se nenhum asset existir, usa ícone
                                      return const Icon(
                                        Icons.login,
                                        size: 24,
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continuar com Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


