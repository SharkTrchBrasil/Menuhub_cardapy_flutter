import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bot_toast/bot_toast.dart';

import '../../core/responsive_builder.dart';
import '../../cubit/auth_cubit.dart';
import '../../cubit/store_cubit.dart';
import '../../cubit/store_state.dart';
import '../../pages/address/cubits/address_cubit.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveBuilder.isDesktop(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        print(
          "👂 [OnboardingPage] BlocListener ouviu uma mudança! Novo estado: ${state.status}",
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (state.status == AuthStatus.success) {
          print("✅ [OnboardingPage] Estado de SUCESSO detectado.");
          BotToast.showText(text: "Login realizado! Verificando endereços...");

          final customer = state.customer;
          if (customer != null && customer.id != null) {
            try {
              // Aguarda os endereços com timeout de 6 segundos
              print(
                "📍 [OnboardingPage] Aguardando carregamento de endereços...",
              );
              await context
                  .read<AddressCubit>()
                  .loadAddresses(customer.id!)
                  .timeout(const Duration(seconds: 6));

              final addressState = context.read<AddressCubit>().state;
              final hasAddresses = addressState.addresses.isNotEmpty;

              if (!hasAddresses) {
                print(
                  "📍 [OnboardingPage] Usuário sem endereço. Redirecionando para /address-onboarding",
                );
                if (context.mounted) {
                  context.go('/address-onboarding');
                }
                return;
              }
            } catch (e) {
              print(
                "⚠️ [OnboardingPage] Timeout ou erro ao carregar endereços. Seguindo para a Home como fallback.",
              );
              BotToast.showText(
                text: "Aviso: Seguindo sem endereços (timeout)",
              );
            }
          }

          // ✅ Fluxo normal ou fallback (se tiver endereço ou se deu timeout)
          if (context.mounted) {
            print(
              "✅ [OnboardingPage] Finalizando fluxo de login e indo para '/'",
            );
            // Usamos Go direto para garantir a saída da tela independente da pilha
            context.go('/');
          }
        } else if (state.status == AuthStatus.error) {
          print(
            "❌ [OnboardingPage] Estado de ERRO detectado: ${state.errorMessage}",
          );
          BotToast.showText(
            text: "Erro: ${state.errorMessage}",
            backgroundColor: Colors.red,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? 'Ocorreu um erro desconhecido.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor:
            Colors
                .transparent, // ✅ Permite transparência se usado como BottomSheet
        body: Stack(
          children: [
            // Layout responsivo
            isDesktop
                ? _buildDesktopLayout(context)
                : _buildMobileLayout(context),

            // Overlay de loading
            Builder(
              builder: (context) {
                final authLoading =
                    context.watch<AuthCubit>().state.status ==
                    AuthStatus.loading;
                final addressLoading =
                    context.watch<AddressCubit>().state.status ==
                    AddressStatus.loading;

                if (authLoading || addressLoading) {
                  return Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            addressLoading
                                ? 'Buscando seus endereços...'
                                : 'Autenticando...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Lado esquerdo - Ilustração
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: SvgPicture.asset(
                'assets/images/login.svg',
                height: 500,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Lado direito - Card de login
        Expanded(
          child: Center(
            child: Container(
              height: 400,
              width: 400,
              child: _buildLoginCard(context),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ NOVO: Layout mobile inspirado no Menuhub
  Widget _buildMobileLayout(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        // Tenta pegar a imagem do banner da loja, ou usa uma imagem padrão
        final store = storeState.store;
        final String? storeImage = store?.image?.url;
        final String? bannerImage = store?.banner?.url;

        // Usa banner, depois imagem da loja, depois imagem padrão de comida
        final String backgroundImage =
            bannerImage ??
            storeImage ??
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80';

        return Stack(
          children: [
            // ✅ 1. IMAGEM DE FUNDO (ocupa toda a tela)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: backgroundImage,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(
                        Icons.restaurant,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
              ),
            ),

            // ✅ 2. GRADIENTE para melhorar legibilidade
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ✅ 3. CONTAINER BRANCO com bordas arredondadas no topo
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle visual (opcional, estilo sheet)
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // Título
                        Text(
                          'Falta um clique para matar sua fome!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Subtítulo
                        Text(
                          'Entre para continuar seu pedido',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // ✅ Botão de Google (estilo Menuhub)
                        _buildGoogleButton(context),

                        const SizedBox(height: 16),

                        // Separador "ou"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'ou',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ✅ Botão "Continuar como visitante"
                        TextButton(
                          onPressed: () {
                            // Fecha a tela de login e continua como visitante
                            if (context.canPop()) {
                              context.pop(false);
                            } else {
                              context.go('/address');
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          child: Text(
                            'Continuar como visitante',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Botão de voltar (se puder voltar)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.black87,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ Botão de Google estilizado (estilo Menuhub)
  Widget _buildGoogleButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
      onPressed: () {
        print(
          "🖱️ [OnboardingPage] Clique detectado no botão Google (Layout Mobile)",
        );
        context.read<AuthCubit>().signInWithGoogle();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // ✅ Evita ocupar espaço extra
        children: [
          SvgPicture.asset('assets/images/google.svg', height: 22),
          const SizedBox(width: 12),
          Flexible(
            // ✅ Permite que o texto quebre ou diminua se necessário
            child: Text(
              'Continuar com Google',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Card(
      elevation: ResponsiveBuilder.isMobile(context) ? 0 : 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Falta um clique para matar sua fome!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            const Text(
              'Como deseja continuar?',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Botão de login com Google
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.grey),
                ),
              ),
              onPressed: () {
                print(
                  "🖱️ [OnboardingPage] Clique detectado no botão Google (Layout Card)",
                );
                context.read<AuthCubit>().signInWithGoogle();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/images/google.svg', height: 24),
                  const SizedBox(width: 12),
                  const Text('Continuar com Google'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
