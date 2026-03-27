/// main.dart
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui';
import 'package:bot_toast/bot_toast.dart';
import 'package:either_dart/either.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:totem/models/totem_auth.dart';
import 'package:totem/widgets/skeleton_shimmer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:totem/core/services/timezone_service.dart';
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
import 'cubit/catalog_cubit.dart';
import 'cubit/orders_cubit.dart';
import 'cubit/store_cubit.dart';
import 'cubit/store_state.dart';
import 'package:web/web.dart' as web;
import 'utils/performance_optimizer.dart';
import 'core/utils/app_logger.dart';
import 'core/services/menu_warmup_barrier.dart';

/// ✅ Sinal global: SplashPage seta true quando navega para home.
/// O SkeletonShimmer overlay espera este sinal para fazer fade-out.
final ValueNotifier<bool> homeReadySignal = ValueNotifier(false);

/// ✅ PERF: Lê dados auth pre-fetched do index.html (evita chamada duplicada ~1000ms)
@JS('_getMenuhubAuth')
external JSString? _jsGetMenuhubAuth();

Map<String, dynamic>? _readPreFetchedAuthData() {
  if (!kIsWeb) return null;
  try {
    final jsStr = _jsGetMenuhubAuth();
    if (jsStr == null) return null;
    final str = jsStr.toDart;
    if (str.isEmpty) return null;
    final data = jsonDecode(str) as Map<String, dynamic>;
    // Valida campos obrigatórios
    if (data['access_token'] == null || data['connection_token'] == null) {
      return null;
    }
    if (kDebugMode) print('⚡ Pre-fetched auth data found from index.html!');
    return data;
  } catch (e) {
    if (kDebugMode) print('⚠️ Pre-fetched auth not available: $e');
    return null;
  }
}

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
  bool _showSplashOverlay = true;
  String? _error;
  Widget? _cachedApp;

  @override
  void initState() {
    super.initState();
    // Remove HTML overlay as soon as Flutter renders first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        try {
          web.window.dispatchEvent(web.Event('flutter_ready'));
        } catch (_) {}
      }
    });
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final sw = Stopwatch()..start();
    try {
      // ═══════════════════════════════════════════════════════════
      // PHASE 1: Parallel — dotenv + locale + timezone (~500ms)
      // ═══════════════════════════════════════════════════════════
      await Future.wait([_initDotenv(), _initLocale(), _initTimezone()]);
      PerformanceOptimizer.configureForWeb();
      final p1 = sw.elapsedMilliseconds;

      // ═══════════════════════════════════════════════════════════
      // PHASE 2: DI only — Firebase/Sentry deferred (~200ms vs ~500ms)
      // ═══════════════════════════════════════════════════════════
      bool diOk = false;
      String? diErrorMsg;
      try {
        await configureDependencies().timeout(const Duration(seconds: 30));
        diOk = true;
      } catch (e) {
        print('❌ FATAL: DI failed: $e');
        diErrorMsg = e.toString();
      }
      final p2 = sw.elapsedMilliseconds;

      if (!diOk) {
        _registerSingleton<bool>('isInitialized', false);
        _registerSingleton<String>(
          'authError',
          'Erro ao configurar o sistema (DI). Detalhes: $diErrorMsg',
        );
        if (mounted) setState(() => _initialized = true);
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // PHASE 3: Parallel — customerStorage + auth token (~1000ms)
      // ✅ OPT: Tenta reusar auth pre-fetched do index.html JS
      //         Se disponível, elimina chamada de rede (~1000ms)
      // ═══════════════════════════════════════════════════════════
      final String storeUrl = _extractStoreUrlFromBrowser();
      _registerSingleton<String>('storeUrl', storeUrl);

      // Parallel: customer storage + auth token
      final authRepo = getIt<AuthRepository>();
      late Either<String, TotemAuth> authResult;

      await Future.wait([
        // 🔐 Customer storage (local — ~100ms)
        () async {
          try {
            await getIt<CustomerController>()
                .loadCustomerFromSecureStorage()
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            if (kDebugMode) print('⚠️ Customer storage load failed: $e');
          }
        }(),
        // 🔐 Auth token (pre-fetch ou rede)
        () async {
          final preFetched = _readPreFetchedAuthData();
          if (preFetched != null) {
            try {
              final totemAuth = authRepo.initFromPreFetchedData(preFetched);
              authResult = Right(totemAuth);
              return;
            } catch (e) {
              if (kDebugMode) print('⚠️ Pre-fetched auth parse failed: $e');
            }
          }
          authResult = await authRepo
              .getToken(storeUrl)
              .timeout(const Duration(seconds: 30));
        }(),
      ]);
      final p3 = sw.elapsedMilliseconds;

      // ═══════════════════════════════════════════════════════════
      // PHASE 4: Socket (NON-BLOCKING) + Auth status (~50ms)
      // ✅ PERF: initialize() é fire-and-forget — apenas cria socket
      // e chama connect(). Os dados chegam via initial_state_loaded
      // event assincronamente. A UI já mostra skeleton progressivo.
      // checkInitialAuthStatus é em background — não bloqueia frame.
      // ═══════════════════════════════════════════════════════════
      if (authResult.isRight) {
        final totemAuth = authResult.right;
        final realtimeRepo = getIt<RealtimeRepository>();

        // ✅ PERF: stale-while-revalidate — emite dados cacheados ANTES do socket
        realtimeRepo.loadCachedMenu(storeUrl);

        // ✅ PERF: initialize() registra handlers + connect() — não precisa de await
        // O socket conecta em background e emite dados progressivamente
        realtimeRepo.initialize(totemAuth.connectionToken);

        // ✅ PERF: checkInitialAuthStatus em background (não bloqueia frame)
        // Para usuários não-logados, retorna imediatamente (AuthStatus.unauthenticated)
        // Para logados, faz linkCustomerToSession em background
        final authCubit = getIt<AuthCubit>();
        // ignore: unawaited_futures
        authCubit.checkInitialAuthStatus().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            if (kDebugMode) print('⚠️ checkInitialAuthStatus timeout (60s)');
          },
        );

        _registerSingleton<bool>('isInitialized', true);

        // ✅ PERF: Splash fade-out driven by actual data arrival (not timeout)
        // catalogReady completes when store + categories are emitted (~500ms)
        MenuWarmupBarrier.instance.catalogReady.then((_) {
          if (!homeReadySignal.value) {
            print('🏠 [SPLASH] catalogReady → homeReadySignal = true');
            homeReadySignal.value = true;
          } else {
            print(
              '🏠 [SPLASH] catalogReady fired but homeReadySignal already true',
            );
          }
        });
      } else {
        if (kDebugMode) print('❌ Store auth failed: ${authResult.left}');
        _registerSingleton<bool>('isInitialized', false);
        _registerSingleton<String>(
          'authError',
          'Loja "$storeUrl" não encontrada no sistema.',
        );
      }

      print(
        '🚀 Init: P1=${p1}ms P2=${p2}ms P3=${p3}ms Total=${sw.elapsedMilliseconds}ms',
      );
      if (mounted) {
        setState(() => _initialized = true);
      }

      // ═══════════════════════════════════════════════════════════
      // DEFERRED: Firebase + AppLogger/Sentry (após home renderizar)
      // Não são necessários para o carregamento inicial.
      // ═══════════════════════════════════════════════════════════
      _initDeferredServices();
    } catch (e, stack) {
      print('💥 CRITICAL: $e\n$stack');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Inicializa Firebase + Sentry em background após home renderizar.
  void _initDeferredServices() {
    Future.wait([_initFirebase(), _initAppLogger()]).then((_) {}).catchError((
      Object e,
    ) {
      if (kDebugMode) print('⚠️ Deferred services failure: $e');
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Helper methods for parallel init
  // ═══════════════════════════════════════════════════════════

  Future<void> _initDotenv() async {
    // ✅ PERF: Single load com isOptional + mergeWith (fallback inline).
    // Evita double-load: antes, timeout de 500ms SEMPRE falhava no Web,
    // desperdiçando ~500ms antes de cair no fallback.
    // Agora: tenta carregar o arquivo, se não existir usa valores inline.
    await dotenv.load(
      fileName: 'assets/env',
      isOptional: true,
      mergeWith: {
        'API_URL': 'https://api.menuhub.com.br',
        'FIREBASE_PROJECT_ID': 'pdvix-c69fe',
        'FIREBASE_API_KEY': 'AIzaSyAvI8rSa8mgZcg4IJAqJOgMIQEF7IwtDt8',
        'FIREBASE_APP_ID': '1:209909701330:web:03ea9f309ce422c35e6b0b',
        'FIREBASE_AUTH_DOMAIN': 'pdvix-c69fe.firebaseapp.com',
        'FIREBASE_STORAGE_BUCKET': 'pdvix-c69fe.appspot.com',
        'FIREBASE_MESSAGING_SENDER_ID': '209909701330',
        'FIREBASE_MEASUREMENT_ID': 'G-R2QQ42E9T7',
      },
    );
  }

  Future<void> _initLocale() async {
    try {
      await initializeDateFormatting(
        'pt_BR',
        null,
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      if (kDebugMode) print('⚠️ Locale init failed');
    }
  }

  Future<void> _initTimezone() async {
    try {
      await TimezoneService.initialize();
    } catch (e) {
      if (kDebugMode) print('⚠️ Timezone init failed: $e');
    }
  }

  Future<void> _initFirebase() async {
    try {
      final firebaseApiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
      final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
      if (firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: firebaseApiKey,
            authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '',
            projectId: firebaseProjectId,
            storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
            messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
            appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
            measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
          ),
        ).timeout(const Duration(seconds: 5));
      } else {
        if (kDebugMode) print('⚠️ Firebase config missing in .env');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Firebase init failed: $e');
    }
  }

  Future<void> _initAppLogger() async {
    try {
      await AppLogger.initialize(
        minLevel: kDebugMode ? LogLevel.debug : LogLevel.info,
        enableSentry: true,
        enableCrashlytics: true,
        environment: kDebugMode ? 'development' : 'production',
        dsn: dotenv.env['SENTRY_DSN'],
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ AppLogger init failed: $e');
    }
  }

  void _registerSingleton<T extends Object>(String name, T value) {
    if (getIt.isRegistered<T>(instanceName: name)) {
      getIt.unregister<T>(instanceName: name);
    }
    getIt.registerSingleton<T>(value, instanceName: name);
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
    return 'lanchonetejeitomineiro';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(body: Center(child: Text("Erro fatal: $_error"))),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // PRE-INIT: SkeletonShimmer enquanto inicializa (mesmo visual
    // que o overlay, garantindo continuidade visual sem piscada)
    // ═══════════════════════════════════════════════════════════
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SkeletonShimmer(),
      );
    }

    // ═══════════════════════════════════════════════════════════
    // ERRO DE AUTH: Mostra tela de erro
    // ═══════════════════════════════════════════════════════════
    final authError =
        getIt.isRegistered<String>(instanceName: 'authError')
            ? getIt.get<String>(instanceName: 'authError')
            : null;

    if (authError != null) {
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

    // ═══════════════════════════════════════════════════════════
    // SEAMLESS TRANSITION: MyApp renderiza por baixo, splash
    // overlay faz fade-out só quando a home já pintou.
    // Zero piscada branca.
    // ═══════════════════════════════════════════════════════════
    _cachedApp ??= MyApp();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          _cachedApp!,
          if (_showSplashOverlay)
            _SplashOverlay(
              onFadeComplete: () {
                if (mounted) setState(() => _showSplashOverlay = false);
              },
            ),
        ],
      ),
    );
  }
}

/// Overlay que cobre o MyApp com o splash Lottie e faz fade-out
/// após a home ter renderizado por baixo.
class _SplashOverlay extends StatefulWidget {
  final VoidCallback onFadeComplete;
  const _SplashOverlay({required this.onFadeComplete});

  @override
  State<_SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<_SplashOverlay> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Espera SplashPage sinalizar que a home está pronta
    homeReadySignal.addListener(_onHomeReady);

    // ✅ FIX RACE CONDITION: Se o sinal já foi setado ANTES deste widget ser criado
    // (dados chegaram muito rápido), faz fade imediatamente.
    // ValueNotifier.addListener só dispara em FUTURAS mudanças, não no valor atual.
    if (homeReadySignal.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _opacity == 1.0) {
          setState(() => _opacity = 0.0);
        }
      });
    }

    // ✅ Fallback: se por algum motivo o sinal não chegar em 15s, faz fade
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _opacity == 1.0) {
        print('⚠️ SplashOverlay: fallback timeout (15s) — forçando fade');
        setState(() => _opacity = 0.0);
      }
    });
  }

  void _onHomeReady() {
    if (!homeReadySignal.value || !mounted) return;
    // Espera 1 frame para a home pintar, depois faz fade
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 0.0);
    });
  }

  @override
  void dispose() {
    homeReadySignal.removeListener(_onHomeReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _opacity < 1.0,
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 500),
        onEnd: widget.onFadeComplete,
        child: const SkeletonShimmer(),
      ),
    );
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
        BlocProvider<CatalogCubit>.value(value: getIt<CatalogCubit>()),
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

                  Future.microtask(() {
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
