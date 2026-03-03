// lib/core/di.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/controllers/menu_app_controller.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/themes/ds_theme_switcher.dart';
import 'package:totem/services/encrypted_storage_service.dart';

import '../pages/address/cubits/address_cubit.dart';
import '../pages/address/cubits/delivery_fee_cubit.dart';
import '../pages/checkout/checkout_cubit.dart';
import '../repositories/order_repository.dart';
import '../repositories/storee_repository.dart';
import '../repositories/delivery_repository.dart';
import '../repositories/notification_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final apiUrl = dotenv.env['API_URL'];
  final secureStorage = const FlutterSecureStorage();

  // ✅ Cria o Dio com interceptor JWT E timeouts
  final dio = Dio(
    BaseOptions(
      baseUrl: '$apiUrl/app',
      // ✅ ADICIONAR TIMEOUTS
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // ✅ CORREÇÃO: sendTimeout removido para evitar problemas em requisições GET no Web
      // O Dio no Web tem problemas com sendTimeout em requisições sem body
      // sendTimeout será configurado por requisição quando necessário
    ),
  );

  // ✅ Adiciona interceptor de autenticação JWT e Customer ID
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ✅ Pula interceptor para requisições de refresh (evita loop infinito)
        if (options.path.contains('/auth/refresh') ||
            options.path.contains('/auth/subdomain') ||
            options.path.contains('/customer/refresh')) {
          return handler.next(options);
        }

        final authRepo = AuthRepository(dio, secureStorage);

        // ✅ CORREÇÃO CRÍTICA: Detecta se é requisição de CUSTOMER ou MENU
        // Rotas de customer começam com /customer ou são operações do cliente
        final isCustomerRequest =
            options.path.startsWith('/customer') ||
            options.path.contains('/customer/') ||
            options.path.startsWith('/orders') ||
            options.path.startsWith('/reviews');

        String? token;

        if (isCustomerRequest) {
          // ✅ Para requisições de customer, usa token de CUSTOMER
          token = await authRepo.getValidCustomerAccessToken();
          print(
            '🔍 [INTERCEPTOR] Usando token de CUSTOMER para: ${options.path}',
          );
        } else {
          // ✅ Para outras requisições, usa token de MENU/TOTEM
          token = await authRepo.getValidAccessToken();
          print('🔍 [INTERCEPTOR] Usando token de MENU para: ${options.path}');
        }

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // ✅ CORREÇÃO: Configura timeouts padrão
        options.connectTimeout = const Duration(seconds: 10);
        options.receiveTimeout = const Duration(seconds: 30);

        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Se receber 401, tenta renovar o token
        if (e.response?.statusCode == 401) {
          // ✅ PROTEÇÃO CONTRA LOOP INFINITO: verifica se já tentou renovar
          final isRetry = e.requestOptions.extra['_isRetryFor401'] == true;
          if (isRetry) {
            print('❌ Já tentou renovar token, evitando loop infinito');
            return handler.next(e);
          }

          print('⚠️ Token expirado (401), tentando renovar...');

          final authRepo = AuthRepository(dio, secureStorage);

          // ✅ CORREÇÃO CRÍTICA: Detecta se é requisição de CUSTOMER ou MENU
          final isCustomerRequest =
              e.requestOptions.path.startsWith('/customer') ||
              e.requestOptions.path.contains('/customer/') ||
              e.requestOptions.path.startsWith('/orders') ||
              e.requestOptions.path.startsWith('/reviews');

          String? newToken;

          if (isCustomerRequest) {
            // ✅ Para requisições de customer, renova token de CUSTOMER
            print('🔄 Renovando token de CUSTOMER...');
            newToken = await authRepo.forceRefreshCustomerToken();
          } else {
            // ✅ Para outras requisições, renova token de MENU
            print('🔄 Renovando token de MENU...');
            newToken = await authRepo.forceRefreshToken();
          }

          if (newToken != null) {
            // ✅ Marca como retry para evitar loop
            e.requestOptions.extra['_isRetryFor401'] = true;

            // Retenta a requisição com o novo token
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';

            try {
              return handler.resolve(await dio.fetch(e.requestOptions));
            } catch (retryError) {
              print('❌ Falha ao retentar requisição: $retryError');
              return handler.next(e);
            }
          } else {
            print('❌ Falha ao renovar token');
            if (isCustomerRequest) {
              await authRepo.logoutCustomer();
            } else {
              await authRepo.logout();
            }
          }
        }

        return handler.next(e);
      },
    ),
  );

  // Logger de debug
  dio.interceptors.add(
    PrettyDioLogger(requestBody: true, requestHeader: true, responseBody: true),
  );

  // --- Registro de dependências ---
  getIt.registerSingleton(dio);
  getIt.registerSingleton(secureStorage);

  // 🔐 Register EncryptedStorageService (AES-256 GCM encryption for all platforms)
  final encryptedStorageService = await EncryptedStorageService.create();
  getIt.registerSingleton<EncryptedStorageService>(encryptedStorageService);

  // Controllers e Notifiers
  getIt.registerSingleton<DsThemeSwitcher>(DsThemeSwitcher());
  getIt.registerSingleton<MenuAppController>(MenuAppController());
  getIt.registerLazySingleton<CustomerController>(() => CustomerController());

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt(), getIt()),
  );
  getIt.registerLazySingleton<StoreRepository>(
    () => StoreRepository(getIt(), getIt()),
  );
  getIt.registerLazySingleton<RealtimeRepository>(() => RealtimeRepository());
  getIt.registerLazySingleton<CustomerRepository>(
    () => CustomerRepository(getIt()),
  );
  getIt.registerLazySingleton<OrderRepository>(() => OrderRepository(getIt()));
  getIt.registerLazySingleton<DeliveryFeeRepository>(
    () => DeliveryFeeRepository(getIt()),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(getIt(), getIt()),
  );

  // Cubits
  getIt.registerLazySingleton<AddressCubit>(
    () => AddressCubit(customerRepository: getIt()),
  );
  getIt.registerLazySingleton<DeliveryFeeCubit>(
    () => DeliveryFeeCubit(repository: getIt()),
  );
  getIt.registerLazySingleton<CheckoutCubit>(
    () =>
        CheckoutCubit(realtimeRepository: getIt(), customerRepository: getIt()),
  );

  // Cubits com dependências
  getIt.registerLazySingleton<CartCubit>(
    () => CartCubit(getIt<RealtimeRepository>()),
  );
  getIt.registerLazySingleton<OrdersCubit>(
    () => OrdersCubit(orderRepository: getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<AuthCubit>(
    () => AuthCubit(
      customerRepository: getIt<CustomerRepository>(),
      customerController: getIt<CustomerController>(),
      realtimeRepository: getIt<RealtimeRepository>(),
      cartCubit: getIt<CartCubit>(),
      addressCubit: getIt<AddressCubit>(),
      ordersCubit: getIt<OrdersCubit>(),
    ),
  );

  getIt.registerLazySingleton<StoreCubit>(
    () => StoreCubit(getIt<RealtimeRepository>()),
  );

  getIt.registerLazySingleton<CatalogCubit>(
    () => CatalogCubit(getIt<RealtimeRepository>()),
  );
}
