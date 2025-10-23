// Em: lib/core/di.dart

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Importe todos os seus cubits, repositórios e controllers
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
  final dio = Dio(BaseOptions(baseUrl: '$apiUrl/app'))
    ..interceptors.add(PrettyDioLogger(
      requestBody: true,
      requestHeader: true,
      responseBody: true,
    ));

  // --- Pacotes e Serviços Externos ---
  getIt.registerSingleton(dio);
  getIt.registerSingleton(const FlutterSecureStorage());

  // --- Controllers e Notifiers ---
  getIt.registerSingleton<DsThemeSwitcher>(DsThemeSwitcher());
  getIt.registerSingleton<MenuAppController>(MenuAppController());
  // ✅ Melhor ser explícito com o tipo e usar lazySingleton
  getIt.registerLazySingleton<CustomerController>(() => CustomerController());
  // ✅ ADICIONE ESTA LINHA
 // getIt.registerFactory(() => ProductRepository(getIt()));


  getIt.registerLazySingleton<AddressCubit>(() => AddressCubit(customerRepository: getIt()));
  getIt.registerLazySingleton<DeliveryFeeCubit>(() => DeliveryFeeCubit());
  getIt.registerLazySingleton<CheckoutCubit>(() => CheckoutCubit(
    realtimeRepository: getIt(),
    customerRepository: getIt(),
  ));

  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(getIt(), getIt()));
  getIt.registerLazySingleton<StoreRepository>(() => StoreRepository(getIt(), getIt()));
  getIt.registerLazySingleton<RealtimeRepository>(() => RealtimeRepository(getIt()));
  getIt.registerLazySingleton<CustomerRepository>(() => CustomerRepository(getIt()));

  // --- CUBITS ---
  // Registramos os Cubits como singletons para que o estado seja compartilhado
  // por todo o app, como planejamos.
  getIt.registerLazySingleton<CartCubit>(
        () => CartCubit(getIt<RealtimeRepository>()),
  );


  getIt.registerLazySingleton<OrderRepository>(
        () => OrderRepository(getIt()),
  );

  getIt.registerLazySingleton<AuthCubit>(
        () => AuthCubit(
      customerRepository: getIt<CustomerRepository>(),
      customerController: getIt<CustomerController>(),
      realtimeRepository: getIt<RealtimeRepository>(),
      cartCubit: getIt<CartCubit>(),
      addressCubit: getIt<AddressCubit>(),
    ),
  );

  getIt.registerLazySingleton<StoreCubit>(
        () => StoreCubit(getIt<RealtimeRepository>()),
  );


}