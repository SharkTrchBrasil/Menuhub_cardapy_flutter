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
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:totem/core/router.dart';
import 'package:totem/pages/address/cubits/address_cubit.dart';
import 'package:totem/pages/address/cubits/delivery_fee_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/pages/cart/cart_state.dart';
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
import 'cubit/store_state.dart';
import 'package:web/web.dart' as web;
import 'utils/performance_optimizer.dart';
import 'core/utils/app_logger.dart';

void main() {
  print('🚀 App Starting...');
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
    print('ℹ️ Starting _initializeApp (Resilient Mode)...');
    try {
      // 1. Dotenv
      try {
        print('📂 Loading .env...');
        await dotenv
            .load(fileName: 'assets/env')
            .timeout(const Duration(seconds: 3));
        print('✅ .env loaded');
      } catch (e) {
        print(
          '⚠️ Dotenv failed to load in 3s or error: $e. Using fallback env.',
        );
        // ✅ FALLBACK MANUAL para caso de erro no carregamento do arquivo
        // Chamamos load com isOptional: true para garantir que o sistema seja inicializado mesmo sem o arquivo
        await dotenv.load(fileName: 'assets/env', isOptional: true);
        dotenv.env.addAll({
          'API_URL': 'https://back-end-pro-production.up.railway.app',
          'FIREBASE_PROJECT_ID': 'pdvix-c69fe',
          'FIREBASE_API_KEY': 'AIzaSyAvI8rSa8mgZcg4IJAqJOgMIQEF7IwtDt8',
          'FIREBASE_APP_ID': '1:209909701330:web:03ea9f309ce422c35e6b0b',
        });
      }

      // 2. Locale
      try {
        print('🌍 Initializing locale...');
        await initializeDateFormatting(
          'pt_BR',
          null,
        ).timeout(const Duration(seconds: 2));
        print('✅ Locale initialized');
      } catch (e) {
        print('⚠️ Locale initialization failed or timeout');
      }

      // 3. Performance
      PerformanceOptimizer.configureForWeb();
      print('✅ PerformanceOptimizer configured');

      // 4. Firebase
      try {
        final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
        final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

        if (firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty) {
          print('🔥 Initializing Firebase for project: $firebaseProjectId...');
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: firebaseApiKey,
              authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
              projectId: firebaseProjectId,
              storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
              messagingSenderId:
                  dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
              appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
              measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
            ),
          ).timeout(const Duration(seconds: 5));
          print('✅ Firebase initialized');
        } else {
          print('⚠️ Firebase config missing in .env');
        }
      } catch (e) {
        print('⚠️ Firebase initialization failed or timeout: $e');
      }

      // 4.1 AppLogger (Monitoring)
      try {
        print('📊 Initializing AppLogger...');
        await AppLogger.initialize(
          minLevel: kDebugMode ? LogLevel.debug : LogLevel.info,
          enableSentry: true,
          enableCrashlytics: true,
          environment: kDebugMode ? 'development' : 'production',
          dsn: dotenv.env['SENTRY_DSN'],
        );
        print('✅ AppLogger initialized');
      } catch (e) {
        print('⚠️ AppLogger initialization failed: $e');
      }

      // 5. DI (Critical)
      try {
        print('💉 Configuring dependencies...');
        // Aumentamos o timeout drasticamente pois o DB local (SharedPreferences/SecureStorage)
        // pode demorar a responder na primeira execução ou em máquinas lentas.
        await configureDependencies().timeout(const Duration(seconds: 30));
        print('✅ Dependencies configured');
      } catch (e) {
        print('❌ FATAL: Dependency configuration failed or timeout: $e');
        // Se o DI falhar, o app NÃO PODE continuar pois vai dar erro de GetIt logo à frente.
        if (getIt.isRegistered<bool>(instanceName: 'isInitialized'))
          getIt.unregister<bool>(instanceName: 'isInitialized');
        getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');

        if (getIt.isRegistered<String>(instanceName: 'authError'))
          getIt.unregister<String>(instanceName: 'authError');
        getIt.registerSingleton<String>(
          'Erro ao configurar o sistema (DI). Detalhes: $e',
          instanceName: 'authError',
        );

        if (mounted)
          setState(
            () => _initialized = true,
          ); // Para mostrar a tela de erro configurada
        return; // Sai do _initializeApp
      }

      // 6. Secure Storage (Critical Load)
      try {
        print('🔐 Loading customer from storage...');
        await getIt<CustomerController>()
            .loadCustomerFromSecureStorage()
            .timeout(const Duration(seconds: 10));
        print('✅ Customer loaded');
      } catch (e) {
        print('⚠️ Customer storage load failed: $e');
      }

      // 7. Auth Flow (Critical)
      print('🔐 Starting auth flow...');
      try {
        String storeUrl = _extractStoreUrlFromBrowser();
        print('🏪 Store Slug Detected: $storeUrl');

        if (getIt.isRegistered<String>(instanceName: 'storeUrl')) {
          getIt.unregister<String>(instanceName: 'storeUrl');
        }
        getIt.registerSingleton<String>(storeUrl, instanceName: 'storeUrl');

        final authRepo = getIt<AuthRepository>();
        print('📡 Fetching store token for: $storeUrl...');

        // Aumentamos o timeout para garantir que conexões oscilantes não quebrem o app
        final authResult = await authRepo
            .getToken(storeUrl)
            .timeout(const Duration(seconds: 30));
        print(
          '✅ Store token result received: ${authResult.isRight ? "SUCCESS" : "ERROR"}',
        );

        if (authResult.isRight) {
          final totemAuth = authResult.right;
          print(
            '🔌 Initializing realtime socket (Token: ${totemAuth.connectionToken.substring(0, 5)}...)',
          );
          final realtimeRepo = getIt<RealtimeRepository>();
          await realtimeRepo
              .initialize(totemAuth.connectionToken)
              .timeout(const Duration(seconds: 15));
          print('✅ Socket initialized');

          print('👤 Running checkInitialAuthStatus (Google Redirect check)...');
          final authCubit = getIt<AuthCubit>();
          // IMPORTANTE: Esse passo pode demorar muito se estiver voltando de um redirect do Google
          await authCubit.checkInitialAuthStatus().timeout(
            const Duration(seconds: 60),
          );
          print('✅ Auth status checked and verified.');

          if (getIt.isRegistered<bool>(instanceName: 'isInitialized')) {
            getIt.unregister<bool>(instanceName: 'isInitialized');
          }
          getIt.registerSingleton<bool>(true, instanceName: 'isInitialized');
        } else {
          print('❌ Store authentication failed: ${authResult.left}');

          if (getIt.isRegistered<bool>(instanceName: 'isInitialized'))
            getIt.unregister<bool>(instanceName: 'isInitialized');
          getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');

          if (getIt.isRegistered<String>(instanceName: 'authError'))
            getIt.unregister<String>(instanceName: 'authError');
          getIt.registerSingleton<String>(
            'Loja "$storeUrl" não encontrada no sistema.',
            instanceName: 'authError',
          );
        }
      } catch (e, stack) {
        print("❌ CRITICAL: Auth flow failed or timeout: $e");
        print(stack);

        if (getIt.isRegistered<bool>(instanceName: 'isInitialized'))
          getIt.unregister<bool>(instanceName: 'isInitialized');
        getIt.registerSingleton<bool>(false, instanceName: 'isInitialized');

        if (getIt.isRegistered<String>(instanceName: 'authError'))
          getIt.unregister<String>(instanceName: 'authError');
        getIt.registerSingleton<String>(
          'Erro de conexão crítica na inicialização. Detalhes: $e',
          instanceName: 'authError',
        );
      }

      if (mounted) {
        print('🚀 App Ready. Dispatching flutter_ready event.');
        setState(() => _initialized = true);

        if (kIsWeb) {
          try {
            web.window.dispatchEvent(web.Event('flutter_ready'));
          } catch (e) {
            print('⚠️ Failed to dispatch flutter_ready: $e');
          }
        }
      }
    } catch (e, stack) {
      print('💥 CRITICAL ERROR during _initializeApp: $e');
      print(stack);
      if (mounted) setState(() => _error = e.toString());
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
    // ✅ Fallback para localhost - mude para a loja que deseja testar
    return 'maxlanches';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(body: Center(child: Text("Erro fatal: $_error"))),
      );
    }

    if (!_initialized) {
      // ✅ Mostra loading idêntico ao do index.html para uma transição suave
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                backgroundColor: Color(0xFFF3F3F3), // Trilha cinza (#f3f3f3)
              ),
            ),
          ),
        ),
      );
    }

    // ✅ SEGURANÇA: Verifica se houve erro de autenticação
    final authError =
        getIt.isRegistered<String>(instanceName: 'authError')
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
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Store URL: ${_extractStoreUrlFromBrowser()}",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Verifique se o endereço está correto ou entre em contato com o estabelecimento.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
        Provider<RealtimeRepository>.value(value: getIt<RealtimeRepository>()),
        BlocProvider<CartCubit>.value(value: getIt<CartCubit>()),
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        BlocProvider<StoreCubit>.value(value: getIt<StoreCubit>()),
        BlocProvider<AddressCubit>.value(value: getIt<AddressCubit>()),
        BlocProvider<DeliveryFeeCubit>.value(value: getIt<DeliveryFeeCubit>()),
        BlocProvider<OrdersCubit>.value(
          value: getIt<OrdersCubit>(),
        ), // ✅ NOVO: Pedidos globais
        ChangeNotifierProvider<DsThemeSwitcher>.value(value: getIt()),
        ChangeNotifierProvider<MenuAppController>.value(value: getIt()),
      ],
      child: MultiBlocListener(
        listeners: [
          // ✅ AUTO-CÁLCULO DE FRETE: Quando endereço muda, recalcula frete automaticamente
          BlocListener<AddressCubit, AddressState>(
            listenWhen: (previous, current) {
              // Escuta quando: status muda para success OU selectedAddress muda
              return (previous.status != AddressStatus.success &&
                      current.status == AddressStatus.success) ||
                  (previous.selectedAddress?.id != current.selectedAddress?.id);
            },
            listener: (context, addressState) {
              if (addressState.selectedAddress != null &&
                  addressState.status == AddressStatus.success) {
                // Pega o store atual
                final storeState = context.read<StoreCubit>().state;
                if (storeState.store != null) {
                  // Calcula frete com subtotal 0 (apenas para mostrar estimativa inicial)
                  context.read<DeliveryFeeCubit>().calculate(
                    address: addressState.selectedAddress,
                    store: storeState.store!,
                    cartSubtotal: 0, // Sem itens no carrinho por enquanto
                  );
                }
              }
            },
          ),
          // ✅ RECALCULA FRETE: Quando loja é carregada OU quando regras de frete mudam
          BlocListener<StoreCubit, StoreState>(
            listenWhen: (previous, current) {
              // ✅ CORREÇÃO: Também escuta quando a loja é carregada pela primeira vez
              if (previous.store == null && current.store != null) return true;

              if (previous.store == null || current.store == null) return false;

              // Compara se as regras de frete mudaram
              final prevRules = previous.store!.deliveryFeeRules;
              final currRules = current.store!.deliveryFeeRules;

              // Se quantidade de regras mudou, recalcula
              if (prevRules.length != currRules.length) return true;

              // Verifica se alguma regra foi modificada (compara por updated_at ou config)
              for (int i = 0; i < currRules.length; i++) {
                if (i >= prevRules.length) return true;
                if (prevRules[i].id != currRules[i].id ||
                    prevRules[i].isActive != currRules[i].isActive ||
                    prevRules[i].ruleType != currRules[i].ruleType) {
                  return true;
                }
              }
              return false;
            },
            listener: (context, storeState) {
              if (storeState.store != null) {
                // Pega o endereço atual
                final addressState = context.read<AddressCubit>().state;
                if (addressState.selectedAddress != null) {
                  // Pega subtotal atual do carrinho
                  final cartState = context.read<CartCubit>().state;
                  final subtotal =
                      cartState.status == CartStatus.success
                          ? cartState.cart.subtotal / 100.0
                          : 0.0;

                  // ✅ Calcula/Recalcula frete
                  final deliveryFeeCubit = context.read<DeliveryFeeCubit>();

                  // Força recálculo chamando com um pequeno delay para garantir que o store foi atualizado
                  Future.microtask(() {
                    print('🚚 [MAIN] Calculando frete automaticamente...');
                    print(
                      '   ├─ Endereço: ${addressState.selectedAddress!.street}',
                    );
                    print('   └─ Subtotal: $subtotal');
                    deliveryFeeCubit.calculate(
                      address: addressState.selectedAddress,
                      store: storeState.store!,
                      cartSubtotal: subtotal,
                    );
                  });
                }
              }
            },
          ),
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
              builder: (context, child) {
                child = BotToastInit()(context, child);
                return child;
              },
            );
          },
        ),
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
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
