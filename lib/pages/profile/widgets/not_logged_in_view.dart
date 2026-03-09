import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Not Logged In View - Estilo Menuhub
/// Tela exibida quando o usuário não está logado na tab de perfil
class NotLoggedInView extends StatelessWidget {
  final bool isDesktop;

  const NotLoggedInView({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Centraliza verticalmente
                    children: [
                      // ✅ Header com ilustração e botão de login (agora centralizado)
                      _buildLoginHeader(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Loading overlay
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

  // ✅ Header com ilustração de sacola feliz e botão de login
  Widget _buildLoginHeader(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 20,
        isDesktop ? 40 : 24,
        isDesktop ? 32 : 20,
        isDesktop ? 32 : 20,
      ),
      color: Colors.white,
      child: Column(
        children: [
          // ✅ Row com texto e ilustração
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Texto de boas-vindas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Falta pouco para matar sua fome!',
                      style: TextStyle(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // ✅ Ilustração de sacola feliz (estilo Menuhub)
              _buildHappyBagIllustration(),
            ],
          ),

          const SizedBox(height: 24),

          // ✅ Botão "Entrar ou cadastrar-se" (estilo Menuhub - borda vermelha)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.push('/onboarding');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primaryColor,
                side: BorderSide(color: theme.primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Entrar ou cadastrar-se',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Ilustração de sacola feliz (estilo Menuhub)
  Widget _buildHappyBagIllustration() {
    return Container(
      width: isDesktop ? 120 : 100,
      height: isDesktop ? 120 : 100,
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sacola principal
          Icon(
            Icons.shopping_bag,
            size: isDesktop ? 60 : 50,
            color: Colors.red.shade400,
          ),
          // Olhinhos felizes
          Positioned(
            top: isDesktop ? 40 : 35,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // Sorriso
          Positioned(
            top: isDesktop ? 55 : 48,
            child: Container(
              width: 20,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 3),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
          // Caixa no topo da sacola
          Positioned(
            top: isDesktop ? 15 : 12,
            child: Container(
              width: isDesktop ? 35 : 28,
              height: isDesktop ? 25 : 20,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
