import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive_builder.dart';
import '../../cubit/auth_cubit.dart';


class OnboardingPage extends StatelessWidget {
  // ✅ 1. DECLARE a variável final que receberá a rota.


  // ✅ 2. ADICIONE a variável ao construtor do widget.
  const OnboardingPage({
    super.key,

  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveBuilder.isDesktop(context);




    // ✅ LÓGICA 1: O BlocListener "ouve" as mudanças de estado para navegar ou mostrar erros.
    // Ele não reconstrói a UI, apenas executa ações.
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Garante que qualquer SnackBar anterior seja removido
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (state.status == AuthStatus.success) {
          // ✅ 2. A ÚNICA AÇÃO EM CASO DE SUCESSO!
          // Em vez de redirecionar, apenas fechamos a tela
          // e devolvemos 'true' para quem a chamou (a ProductPage).
          if (context.canPop()) {
            context.pop(true);
          } else {
            // Fallback caso a página seja aberta diretamente (raro)
            context.go('/address');
          }
        } else if (state.status == AuthStatus.error) {
          // A lógica de erro continua igual.
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
        body: Stack(
          children: [
            // Seu layout original, sem alterações
            isDesktop
                ? _buildDesktopLayout(context)
                : _buildMobileLayout(context),

            // ✅ LÓGICA 2: O BlocBuilder mostra um overlay de loading sobre a tela
            // quando o estado de autenticação está "carregando".
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
                // Se não estiver carregando, retorna um widget vazio
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

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Imagem no topo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SvgPicture.asset(
              'assets/images/login.svg',

              height: 250,
              fit: BoxFit.contain,
            ),
          ),

          const SizedBox(height: 40),

          // Card de login
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _buildLoginCard(context),
          ),

          const SizedBox(height: 40),
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
