// pages/splash/splash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page_state.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/widgets/food_loading_animation.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import '../../themes/ds_theme_switcher.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isCheckingAddress = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // ✅ Simplesmente inicializa e aguarda os dados do Socket.IO
    context.read<SplashPageCubit>().initialize();
  }

  Future<void> _checkAddressAndNavigate() async {
    // ✅ Verifica se já navegou ou está navegando
    if (_isCheckingAddress || _hasNavigated) {
      print("⚠️ [SplashPage] Já navegou ou está navegando. Ignorando.");
      return;
    }
    
    // ✅ Verifica se ainda estamos na página de splash
    final currentRoute = GoRouterState.of(context).matchedLocation;
    if (currentRoute != '/splash') {
      print("⚠️ [SplashPage] Não estamos mais no splash ($currentRoute). Ignorando redirect.");
      _hasNavigated = true;
      return;
    }
    
    _isCheckingAddress = true;

    try {
      final authState = context.read<AuthCubit>().state;
      final customer = authState.customer;

      if (customer != null && customer.id != null) {
        print("📍 [SplashPage] Usuário logado. Verificando endereços...");
        
        // ✅ Carrega endereços e espera o resultado
        final addressCubit = context.read<AddressCubit>();
        await addressCubit.loadAddresses(customer.id!);
        
        // ✅ Espera um frame para garantir que o estado foi atualizado
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted || _hasNavigated) return;
        
        // ✅ Verifica novamente se ainda estamos no splash após o await
        final currentRouteAfterLoad = GoRouterState.of(context).matchedLocation;
        if (currentRouteAfterLoad != '/splash') {
          print("⚠️ [SplashPage] Saímos do splash durante o load. Ignorando redirect.");
          _hasNavigated = true;
          return;
        }
        
        final addressState = addressCubit.state;
        final hasAddresses = addressState.addresses.isNotEmpty;
        
        print("📍 [SplashPage] Endereços encontrados: ${addressState.addresses.length}");
        
        if (!hasAddresses) {
          // ✅ Logado sem endereço: vai para onboarding de endereço
          print("📍 [SplashPage] Usuário logado SEM endereço. Redirecionando para /address-onboarding");
          _hasNavigated = true;
          context.go('/address-onboarding');
          return;
        }
        
        print("✅ [SplashPage] Usuário tem ${addressState.addresses.length} endereço(s). Indo para home.");
      } else {
        print("👤 [SplashPage] Usuário não está logado. Indo para home.");
      }

      // ✅ Tem endereço ou não está logado: vai para home normalmente
      _hasNavigated = true;
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      print("❌ [SplashPage] Erro ao verificar endereços: $e");
      // Em caso de erro, vai para home
      _hasNavigated = true;
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return BlocListener<SplashPageCubit, SplashPageState>(
      listener: (context, state) {
        // ✅ Quando carregar, verifica endereços (apenas se não navegou ainda)
        if (!state.loading && state.products != null && state.store != null && !_hasNavigated) {
          _checkAddressAndNavigate();
        }
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Logo 400x400
              Image.asset(
                'assets/logo.png', // Verificado em c:/Users/Sharkcode/Documents/Menuhub/totem/assets/logo.png
                width: 400,
                height: 400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}