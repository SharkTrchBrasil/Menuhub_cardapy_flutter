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
import 'package:intl/date_symbol_data_local.dart';
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
import 'cubit/orders_cubit.dart';
import 'cubit/store_cubit.dart';
import 'package:web/web.dart' as web;
import 'utils/performance_optimizer.dart';

void main() {
  // ✅ ENTERPRISE: Inicialização Imediata (Splash Screen)
  // Removemos todos os 'await' antes do runApp para garantir feedback visual instantâneo.
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();
  runApp(const AppBootstrapper());
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key});

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // ✅ Carrega variáveis de ambiente
      await dotenv.load(fileName: 'assets/env');
      
      // ✅ NOVO: Inicializa locale pt_BR para formatação de datas
      await initializeDateFormatting('pt_BR', null);
      
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

      if (firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty) {
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
      }
      
      await configureDependencies();
      
      // Carrega dados iniciais essenciais
      await getIt<CustomerController>().loadCustomerFromSecureStorage();
      
      // --- 🔐 FLUXO DE AUTENTICAÇÃO ---
      try {
        String storeUrl = _extractStoreUrlFromBrowser();
        getIt.registerSingleton<String>(storeUrl, instanceName: 'storeUrl');
        
        final authRepo = getIt<AuthRepository>();
        final authResult = await authRepo.getToken(storeUrl);
        
        if (authResult.isRight) {
           final totemAuth = authResult.right;
           final realtimeRepo = getIt<RealtimeRepository>();
           await realtimeRepo.initialize(totemAuth.connectionToken);
           
           final authCubit = getIt<AuthCubit>();
           await authCubit.checkInitialAuthStatus();
           
           getIt.registerSingleton<bool>(true, instanceName: 'isInitialized');
           if (kIsWeb) {
             web.window.dispatchEvent(web.Event('flutter_ready'));
           }
        } else {
          // ✅ SEGURANÇA: Loja não encontrada ou erro de autenticação
          print('❌ Falha na autenticação: ${authResult.left}');
          getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');
          getIt.registerSingleton<String>(authResult.left, instanceName: 'authError');
        }
      } catch (e) {
        print("❌ Erro crítico na auth: $e");
        getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');
        getIt.registerSingleton<String>('Erro ao conectar com a loja', instanceName: 'authError');
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('💥 ERRO CRÍTICO NA INICIALIZAÇÃO: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  // ✅ Função auxiliar para extrair slug da URL
  String _extractStoreUrlFromBrowser() {
    if (kIsWeb) {
      final hostname = web.window.location.hostname;
      if (hostname.contains('.menuhub.com.br')) {
        return hostname.split('.').first;
      }
    }
    return 'topburguer';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Erro fatal: $_error")),
        ),
      );
    }

    if (!_initialized) {
      // ✅ OTIMIZAÇÃO: Retorna widget vazio e deixa splash nativo do web aparecer
      // Isso evita splash duplicado e melhora percepção de performance
      return const SizedBox.shrink();
    }
    
    // ✅ SEGURANÇA: Verifica se houve erro de autenticação
    final authError = getIt.isRegistered<String>(instanceName: 'authError') 
        ? getIt.get<String>(instanceName: 'authError') 
        : null;
    
    if (authError != null) {
      // ✅ SEGURANÇA: Mostra tela de erro ao invés de loading infinito
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Color(0xFFEA1D2C),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Loja não encontrada',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authError,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Verifique se o endereço está correto ou entre em contato com o estabelecimento.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MyApp();
  }
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
        BlocProvider<OrdersCubit>.value(value: getIt<OrdersCubit>()),  // ✅ NOVO: Pedidos globais
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