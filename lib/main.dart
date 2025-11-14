/// main.dart
import 'dart:ui';
import 'package:bot_toast/bot_toast.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/router.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:url_strategy/url_strategy.dart';
import 'controllers/customer_controller.dart';
import 'controllers/menu_app_controller.dart';
import 'core/di.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/store_cubit.dart';
import 'package:web/web.dart' as web;
import 'utils/performance_optimizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Carrega variáveis de ambiente
  try {
    await dotenv.load(fileName: 'assets/env');
    print('✅ Arquivo .env carregado com sucesso');
    print('   API_URL: ${dotenv.env['API_URL']?.substring(0, 30)}...');
    print('   FIREBASE_API_KEY: ${dotenv.env['FIREBASE_API_KEY']?.substring(0, 10) ?? "NÃO ENCONTRADO"}...');
  } catch (e) {
    print('❌ Erro ao carregar arquivo .env: $e');
    print('   Certifique-se de que o arquivo assets/env existe e está configurado no pubspec.yaml');
  }
  
  setPathUrlStrategy();

  // ✅ Otimizações de performance para Flutter Web
  PerformanceOptimizer.configureForWeb();

  final storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorage.webStorageDirectory
        : await getApplicationDocumentsDirectory(),
  );

  HydratedBloc.storage = storage;

  // ✅ Load Firebase config from .env file
  final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
  final firebaseAuthDomain = dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  final firebaseStorageBucket = dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  final firebaseMessagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  final firebaseAppId = dotenv.env['FIREBASE_APP_ID'] ?? '';
  final firebaseMeasurementId = dotenv.env['FIREBASE_MEASUREMENT_ID'] ?? '';

  // ✅ Valida credenciais antes de inicializar
  if (firebaseApiKey.isEmpty || firebaseProjectId.isEmpty || firebaseAppId.isEmpty) {
    print('⚠️ Firebase credentials not found in .env.');
    print('   Required variables: FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_APP_ID');
    print('   Firebase initialization will be skipped.');
    print('   Google Sign-In will not be available.');
  } else {
    try {
      print('🔥 [Firebase] Inicializando Firebase...');
      print('   API Key: ${firebaseApiKey.substring(0, 10)}...');
      print('   Project ID: $firebaseProjectId');
      print('   Auth Domain: $firebaseAuthDomain');
      
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseApiKey,
          authDomain: firebaseAuthDomain,
          projectId: firebaseProjectId,
          storageBucket: firebaseStorageBucket,
          messagingSenderId: firebaseMessagingSenderId,
          appId: firebaseAppId,
          measurementId: firebaseMeasurementId.isEmpty ? null : firebaseMeasurementId,
        ),
      );
      
      // ✅ Verifica se Firebase foi inicializado corretamente
      final apps = Firebase.apps;
      if (apps.isNotEmpty) {
        print('✅ Firebase initialized successfully');
        print('   App Name: ${apps.first.name}');
        print('   Options: ${apps.first.options.projectId}');
      } else {
        print('⚠️ Firebase apps list is empty after initialization');
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing Firebase: $e');
      print('   Stack: $stackTrace');
      print('   Firebase features will be unavailable.');
    }
  }

  configureDependencies();
  // ✅ Carrega cliente do armazenamento seguro ao invés de SharedPreferences
  await getIt<CustomerController>().loadCustomerFromSecureStorage();

  // --- 🔐 FLUXO DE AUTENTICAÇÃO SEGURO E ROBUSTO ---
  try {
    // 1️⃣ Detecta o subdomínio da URL (ou usa padrão)
    String storeUrl = _extractStoreUrlFromBrowser();
    getIt.registerSingleton<String>(storeUrl, instanceName: 'storeUrl');
    print('🏪 Autenticando na loja: $storeUrl');

    // 2️⃣ Pega o repositório de autenticação
    final authRepo = getIt<AuthRepository>();

    // 3️⃣ Autentica na API REST. Esta chamada agora retorna:
    //    - Tokens JWT (para o cliente)
    //    - Um `connection_token` de uso único (para o WebSocket)
    final authResult = await authRepo.getToken(storeUrl);

    if (authResult.isLeft) {
      throw Exception('❌ Falha na autenticação HTTP: ${authResult.left}');
    }

    final totemAuth = authResult.right;
    print('✅ Autenticado via HTTP com sucesso na loja: ${totemAuth.storeName}');

    // --- ✅ 4. MUDANÇA CRÍTICA ---
    // Pega o repositório de tempo real e o inicializa com o token de conexão
    // de curta duração que acabamos de receber.
    final realtimeRepo = getIt<RealtimeRepository>();

    print('🔌 Usando connection_token para conectar ao Socket.IO...');
    await realtimeRepo.initialize(totemAuth.connectionToken);

    print('✅ Socket.IO conectado com sucesso!');

    // 5️⃣ O resto do fluxo continua normalmente
    final authCubit = getIt<AuthCubit>();
    await authCubit.checkInitialAuthStatus();

    getIt.registerSingleton<bool>(true, instanceName: 'isInitialized');

    if (kIsWeb) {
      web.window.dispatchEvent(web.Event('flutter_ready'));
    }

    print('🎉 Aplicação inicializada com sucesso!');
  } catch (e, stackTrace) {
    print('💥 ERRO CRÍTICO NA INICIALIZAÇÃO: $e');
    print('Stack: $stackTrace');
    getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');

    // TODO: Exibir tela de erro personalizada
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('Erro capturado: ${details.exception}');
      print('Stack: ${details.stack}');
    }
  };

  runApp(MyApp());
}
// ✅ Função auxiliar para extrair slug da URL
String _extractStoreUrlFromBrowser() {
  if (kIsWeb) {
    final hostname = web.window.location.hostname;

    // Exemplo: topburguer.menuhub.com.br -> retorna 'topburguer'
    if (hostname.contains('.menuhub.com.br')) {
      return hostname.split('.').first;
    }

    // Exemplo: localhost ou domínio customizado -> usa padrão
    print('⚠️ Hostname não reconhecido: $hostname, usando padrão');
  }

  // Fallback para desenvolvimento
  return 'topburguer';
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter router = createGoRouter();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CartCubit>.value(value: getIt<CartCubit>()),
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        BlocProvider<StoreCubit>.value(value: getIt<StoreCubit>()),
        BlocProvider<AddressCubit>.value(value: getIt<AddressCubit>()),
        BlocProvider<DeliveryFeeCubit>.value(value: getIt<DeliveryFeeCubit>()),
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
    return const ClampingScrollPhysics();
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
    return child;
  }
}