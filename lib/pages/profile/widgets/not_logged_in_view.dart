import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Not Logged In View
/// Tela exibida quando o usuário não está logado
class NotLoggedInView extends StatelessWidget {
  final bool isDesktop;

  const NotLoggedInView({super.key, required this.isDesktop});

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
                    _LoginSection(theme: theme, isDesktop: isDesktop),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                Text(
                  'Como deseja continuar?',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                            Builder(
                              builder: (context) {
                                try {
                                  return SvgPicture.asset(
                                    'assets/images/google.svg',
                                    height: 24,
                                    width: 24,
                                  );
                                } catch (e) {
                                  return Image.asset(
                                    'assets/images/google.png',
                                    height: 24,
                                    width: 24,
                                    errorBuilder: (context, error, stackTrace) {
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
