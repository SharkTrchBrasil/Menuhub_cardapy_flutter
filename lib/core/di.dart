// lib/core/di.dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/cart/cart_cubit.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/controllers/menu_app_controller.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/realtime_repository.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

import '../pages/address/cubits/address_cubit.dart';
import '../pages/address/cubits/delivery_fee_cubit.dart';
import '../pages/checkout/checkout_cubit.dart';
import '../repositories/order_repository.dart';
import '../repositories/storee_repository.dart';
import '../repositories/delivery_repository.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  final apiUrl = dotenv.env['API_URL'];
  final secureStorage = const FlutterSecureStorage();

  // ✅ Cria o Dio com interceptor JWT E timeouts
  final dio = Dio(BaseOptions(
    baseUrl: '$apiUrl/app',
    // ✅ ADICIONAR TIMEOUTS
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  // ✅ Adiciona interceptor de autenticação JWT e Customer ID
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // ✅ Pula interceptor para requisições de refresh (evita loop infinito)
        if (options.path.contains('/auth/refresh') || 
            options.path.contains('/auth/subdomain')) {
          return handler.next(options);
        }
        
        // Pega o token válido (renova se necessário)
        final authRepo = AuthRepository(dio, secureStorage);
        final token = await authRepo.getValidAccessToken();

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // ✅ NOVO: Adiciona customer_id do CustomerController se houver customer logado
        try {
          final customerController = getIt<CustomerController>();
          final customer = customerController.customer;
          if (customer != null && customer.id != null) {
            options.headers['X-Customer-ID'] = customer.id.toString();
          }
        } catch (e) {
          // Se não conseguir obter o CustomerController, continua sem o header
          // (pode ser que o customer não esteja logado ou o controller não esteja disponível)
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // Se receber 401, tenta renovar o token
        if (e.response?.statusCode == 401) {
          print('⚠️ Token expirado (401), tentando renovar...');

          final authRepo = AuthRepository(dio, secureStorage);
          final newToken = await authRepo.getValidAccessToken();

          if (newToken != null) {
            // Retenta a requisição com o novo token
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await dio.fetch(e.requestOptions));
          } else {
            print('❌ Falha ao renovar token, fazendo logout');
            await authRepo.logout();
          }
        }

        return handler.next(e);
      },
    ),
  );

  // Logger de debug
  dio.interceptors.add(
    PrettyDioLogger(
      requestBody: true,
      requestHeader: true,
      responseBody: true,
    ),
  );

  // --- Registro de dependências ---
  getIt.registerSingleton(dio);
  getIt.registerSingleton(secureStorage);

  // Controllers e Notifiers
  getIt.registerSingleton<DsThemeSwitcher>(DsThemeSwitcher());
  getIt.registerSingleton<MenuAppController>(MenuAppController());
  getIt.registerLazySingleton<CustomerController>(() => CustomerController());

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt(), getIt()));
  getIt.registerLazySingleton<StoreRepository>(() => StoreRepository(getIt(), getIt()));
  getIt.registerLazySingleton<RealtimeRepository>(() => RealtimeRepository(getIt()));
  getIt.registerLazySingleton<CustomerRepository>(() => CustomerRepository(getIt()));
  getIt.registerLazySingleton<OrderRepository>(() => OrderRepository(getIt()));
  getIt.registerLazySingleton<DeliveryFeeRepository>(() => DeliveryFeeRepository(getIt()));

  // Cubits
  getIt.registerLazySingleton<AddressCubit>(() => AddressCubit(customerRepository: getIt()));
  getIt.registerLazySingleton<DeliveryFeeCubit>(() => DeliveryFeeCubit(repository: getIt()));
  getIt.registerLazySingleton<CheckoutCubit>(() => CheckoutCubit(
    realtimeRepository: getIt(),
    customerRepository: getIt(),
  ));

  // Cubits com dependências
  getIt.registerLazySingleton<CartCubit>(() => CartCubit(getIt<RealtimeRepository>()));

  getIt.registerLazySingleton<AuthCubit>(() => AuthCubit(
    customerRepository: getIt<CustomerRepository>(),
    customerController: getIt<CustomerController>(),
    realtimeRepository: getIt<RealtimeRepository>(),
    cartCubit: getIt<CartCubit>(),
    addressCubit: getIt<AddressCubit>(),
  ));

  getIt.registerLazySingleton<StoreCubit>(() => StoreCubit(getIt<RealtimeRepository>()));
}