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

final getIt = GetIt.instance;

void configureDependencies() {
  final apiUrl = dotenv.env['API_URL'];
  final secureStorage = const FlutterSecureStorage();

  // ✅ Cria o Dio com interceptor JWT
  final dio = Dio(BaseOptions(baseUrl: '$apiUrl/app'));

  // ✅ Adiciona interceptor de autenticação JWT
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Pega o token válido (renova se necessário)
        final authRepo = AuthRepository(dio, secureStorage);
        final token = await authRepo.getValidAccessToken();

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('🔐 Token JWT adicionado ao header');
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

  // Cubits
  getIt.registerLazySingleton<AddressCubit>(() => AddressCubit(customerRepository: getIt()));
  getIt.registerLazySingleton<DeliveryFeeCubit>(() => DeliveryFeeCubit());
  getIt.registerLazySingleton<CheckoutCubit>(() => CheckoutCubit(
    realtimeRepository: getIt(),
    customerRepository: getIt(),
  ));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt(), getIt()));
  getIt.registerLazySingleton<StoreRepository>(() => StoreRepository(getIt(), getIt()));
  getIt.registerLazySingleton<RealtimeRepository>(() => RealtimeRepository(getIt()));
  getIt.registerLazySingleton<CustomerRepository>(() => CustomerRepository(getIt()));
  getIt.registerLazySingleton<OrderRepository>(() => OrderRepository(getIt()));

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