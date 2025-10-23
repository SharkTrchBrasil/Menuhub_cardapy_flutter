// main.dart
import 'dart:io';
import 'dart:ui';

import 'package:bot_toast/bot_toast.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'package:provider/provider.dart';

import 'package:totem/core/router.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:url_strategy/url_strategy.dart';

import 'controllers/customer_controller.dart';
import 'controllers/menu_app_controller.dart';
import 'core/di.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/store_cubit.dart';
import 'package:web/web.dart' as web;


/**/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'assets/env');// carrega o env

  setPathUrlStrategy();

  final storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorage.webStorageDirectory
        : await getApplicationDocumentsDirectory(),
  );



  HydratedBloc.storage = storage;

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAvI8rSa8mgZcg4IJAqJOgMIQEF7IwtDt8",
      authDomain: "pdvix-c69fe.firebaseapp.com",
      projectId: "pdvix-c69fe",
      storageBucket: "pdvix-c69fe.appspot.com",
      messagingSenderId: "209909701330",
      appId: "1:209909701330:web:03ea9f309ce422c35e6b0b",
      measurementId: "G-R2QQ42E9T7",
    ),
  );

  configureDependencies();


  await getIt<CustomerController>().loadCustomerFromPrefs();


// --- Bloco de Inicialização Assíncrona ---
  // Este bloco garante que tudo esteja pronto antes do app rodar.
  try {
    // 1. Pega o subdomínio
    String initialSubdomain = 'topburguer'; // Sua lógica para pegar o subdomínio aqui
    getIt.registerSingleton<String>(initialSubdomain, instanceName: 'initialSubdomain');

    final dio = getIt<Dio>();
    final response = await dio.post(
      '/auth/subdomain', // Endpoint que você já tem
      data: {'store_url': initialSubdomain},
    );
    final totemToken = response.data['totem_token'];

    // 3. INICIALIZA E ESPERA o RealtimeRepository ficar 100% pronto.
    final realtimeRepo = getIt<RealtimeRepository>();
    await realtimeRepo.initialize(totemToken);


    // 4. ✅ AGORA SIM: Com a conexão pronta, mandamos o AuthCubit verificar o status.
    //    Isso vai disparar o `linkCustomerToSession` se houver um cliente salvo.
    final authCubit = getIt<AuthCubit>(); // Pega a instância do GetIt
    await authCubit.checkInitialAuthStatus();
    // Marca a inicialização como completa para o GoRouter saber que pode prosseguir.
    getIt.registerSingleton<bool>(true, instanceName: 'isInitialized');


    // ✅ DISPARA O EVENTO PARA O JAVASCRIPT ESCONDER O LOADING DO HTML
    if (kIsWeb) {
      web.window.dispatchEvent(web.Event('flutter_ready'));
    }

  } catch (e) {
    print("💥 ERRO CRÍTICO NA INICIALIZAÇÃO: $e");
    // Aqui você poderia, por exemplo, rodar uma versão "offline" do app ou uma tela de erro.
    getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');
  }


  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('Erro capturado: ${details.exception}');
      print('Stack: ${details.stack}');
    }
  };




  runApp( MyApp());
}

// ✅ PASSO 2: MyApp se torna mais simples
class MyApp extends StatelessWidget {
  MyApp({super.key}); // Removido o 'const'

  // O router agora é uma propriedade da classe
  final GoRouter router = createGoRouter();


  @override
  Widget build(BuildContext context) {

    return MultiBlocProvider(
      providers: [
        // ✅ FORMA FINAL: Todos os singletons são fornecidos com `.value`
        BlocProvider<CartCubit>.value(value: getIt<CartCubit>()),
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        BlocProvider<StoreCubit>.value(value: getIt<StoreCubit>()),
        BlocProvider<AddressCubit>.value(value: getIt<AddressCubit>()),
        BlocProvider<DeliveryFeeCubit>.value(value: getIt<DeliveryFeeCubit>()),


        // Seus ChangeNotifiers
        ChangeNotifierProvider<DsThemeSwitcher>.value(value: getIt()),
        ChangeNotifierProvider<MenuAppController>.value(value: getIt()),
      ],


      child: Builder(
        builder: (context) {
          final theme = context.watch<DsThemeSwitcher>().theme;
          return MaterialApp.router(
            title: 'TotemPRO',
            debugShowCheckedModeBanner: false,
            theme: theme.toThemeData().copyWith(
              appBarTheme: const AppBarTheme(
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              textTheme: GoogleFonts.getTextTheme(
                theme.fontFamily.nameGoogle,
              ).apply(
                bodyColor: theme.onBackgroundColor,
                displayColor: theme.onBackgroundColor,
              ),
            ),

            routerConfig: router,
            builder: (context, child) => BotToastInit()(context, child),
          );
        },
      ),
    );
  }






}

class CleanScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(); // Remove o bounce
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Remove o efeito visual (onda/reflexo)
  }
}
