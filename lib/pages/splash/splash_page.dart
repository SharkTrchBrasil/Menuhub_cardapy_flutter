// pages/splash/splash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page_state.dart';
import 'package:totem/themes/ds_theme.dart';
import '../../core/di.dart';
import '../../themes/ds_theme_switcher.dart';
import '../../widgets/dot_loading.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    // ✅ Simplesmente inicializa e aguarda os dados do Socket.IO
    context.read<SplashPageCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return BlocListener<SplashPageCubit, SplashPageState>(
      listener: (context, state) {
        // ✅ Quando carregar, navega para a home
        if (!state.loading && state.products != null && state.store != null) {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Seu logo aqui
              const SizedBox(height: 24),
              const DotLoading(),
              const SizedBox(height: 16),
              Text(
                'Carregando cardápio...',
                style: TextStyle(color: theme.onBackgroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}