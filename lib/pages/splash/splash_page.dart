// totem/pages/splash/splash_page.dart
import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:totem/models/totem_auth.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page_state.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/widgets/ds_app_logo.dart';

import '../../core/di.dart';
import '../../themes/ds_theme_switcher.dart';

import 'package:web/web.dart' as web;

import '../../widgets/dot_loading.dart';


class SplashPage extends StatefulWidget {
  final String? initialSubdomain; // Adicionar este parâmetro
  const SplashPage({super.key, this.initialSubdomain}); // E no construtor

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();



  }





  @override
  Widget build(BuildContext context) {
    final DsTheme theme = context.watch<DsThemeSwitcher>().theme;

    return Scaffold(

      
      body: Center(child: DotLoading())
    );
  }

}