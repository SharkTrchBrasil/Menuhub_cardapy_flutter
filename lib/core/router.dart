// core/router.dart
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../pages/address/address_page.dart';
import '../pages/address/address_selection_page.dart';
import '../pages/cart/cart_page.dart';
import '../pages/checkout/checkout_page.dart';
import '../pages/coupon/coupon_page.dart';
import '../pages/not_found/error_505_Page.dart';
import '../pages/order/order_confirmation_page.dart';
import '../pages/product/product_page.dart';
import '../pages/product/product_page_cubit.dart';
import '../pages/signin/signin_page.dart'; // ✅ Importe a OnboardingPage
import '../pages/store/store_details.dart';
import '../pages/success/order_success.dart';
import '../pages/profile/profile_screem.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/orders/order_history_page.dart';
import '../pages/orders/order_detail_page.dart';
import '../pages/orders/order_review_page.dart';
import '../pages/auth/email_auth_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/search/search_page.dart';
import '../repositories/realtime_repository.dart';
import '../repositories/storee_repository.dart';
import '../pages/home/simple_home_page.dart';
import '../pages/home/desktop_home_wrapper.dart';
import '../pages/main_tab/main_tab_page.dart';
import '../widgets/desktop_page_wrapper.dart';
import '../core/responsive_builder.dart';
import 'di.dart';

GoRouter createGoRouter() {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final storeCubit = StoreCubit(GetIt.I<RealtimeRepository>());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    observers: [BotToastNavigatorObserver()],
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, state) => BlocProvider(
          create: (_) => SplashPageCubit(),
          child: const SplashPage(),
        ),
      ),
      GoRoute(path: '/not-found', builder: (_, state) => const NotFoundPage()),

      // ✅ ROTA DE ONBOARDING/LOGIN RESTAURADA
      // Colocada no nível superior para ser acessível de qualquer lugar.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider.value(
            value: storeCubit,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              // Mobile usa tabs, Desktop usa rotas
              final isMobile = MediaQuery.of(context).size.width < 768;
              if (isMobile) {
                return const MainTabPage();
              } else {
                return const DesktopHomeWrapper();
              }
            },
            routes: [
              GoRoute(
                path: 'cart',
                pageBuilder: (context, state) {
                  final isMobile = MediaQuery.of(context).size.width < 768;
                  final page = const CartPage();
                  
                  if (isMobile) {
                    return CustomTransitionPage(
                      child: page,
                      opaque: false,
                      barrierDismissible: true,
                      barrierColor: Colors.black45,
                      transitionsBuilder: (_, animation, __, child) =>
                          FadeTransition(opacity: animation, child: child),
                    );
                  } else {
                    // Desktop: usa wrapper com navegação
                    return MaterialPage(
                      child: DesktopPageWrapper(child: page),
                    );
                  }
                },
              ),
              // ✅ NOVO: Rota para deep link de carrinho abandonado (menuhub://cart/{cartId}?token={token})
              GoRoute(
                path: 'cart/:cartId',
                redirect: (context, state) async {
                  final token = state.uri.queryParameters['token'];
                  final cartIdStr = state.pathParameters['cartId'];
                  
                  if (token != null && cartIdStr != null) {
                    // Valida token e redireciona para o carrinho
                    final cartId = int.tryParse(cartIdStr);
                    if (cartId != null) {
                      await _validateAndOpenCart(context, cartId, token);
                      return '/cart'; // Redireciona para o carrinho normal
                    }
                  }
                  
                  // Sem token, redireciona para home
                  return '/';
                },
              ),
              GoRoute(
                path: 'checkout',
                pageBuilder: (context, state) => CustomTransitionPage(
                  child: const CheckoutPage(),
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black45,
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
              GoRoute(
                path: 'address',
                pageBuilder: (context, state) => CustomTransitionPage(
                  child: const AddressPage(),
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black45,
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
              GoRoute(
                path: 'select-address',
                builder: (context, state) => const AddressSelectionPage(),
              ),
              GoRoute(
                path: 'add-coupon',
                pageBuilder: (context, __) => CustomTransitionPage(
                  child: CouponPage(realtimeRepository: getIt<RealtimeRepository>()),
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black45,
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),
              GoRoute(
                path: 'store-details',
                pageBuilder: (_, state) {
                  final int? initialTabIndex = state.extra as int?;
                  return CustomTransitionPage(
                    child: StoreDetails(initialTabIndex: initialTabIndex ?? 0),
                    opaque: false,
                    barrierDismissible: true,
                    barrierColor: Colors.black45,
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                },
              ),
              GoRoute(
                path: 'product/:productSlug/:id',
                pageBuilder: (context, state) {
                  final productId = int.tryParse(state.pathParameters['id'] ?? '');
                  if (productId == null) {
                    return const MaterialPage(child: Scaffold(body: Center(child: Text("Produto não encontrado"))));
                  }

                  final initialProduct = state.extra is Product ? state.extra as Product : null;
                  final cartItemToEdit = state.extra is CartItem ? state.extra as CartItem : null;
                  final isDesktop = MediaQuery.of(context).size.width >= 768;

                  final pageContent = BlocProvider<ProductPageCubit>(
                    create: (context) => ProductPageCubit(
                      productId: productId,
                      repository: getIt<StoreRepository>(),
                      storeCubit: context.read<StoreCubit>(),
                    )..loadProduct(
                      initialProduct: initialProduct,
                      cartItemToEdit: cartItemToEdit,
                    ),
                    child: const ProductPage(),
                  );

                  if (isDesktop) {
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                      barrierDismissible: true,
                      barrierColor: Colors.black.withOpacity(0.6),
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 200),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    );
                  } else {
                    return MaterialPage<void>(key: state.pageKey, child: pageContent);
                  }
                },
              ),
              GoRoute(
                path: 'order/success',
                builder: (context, state) {
                  // ✅ CORREÇÃO: Recebe order e paymentMethod do extra
                  final extra = state.extra as Map<String, dynamic>?;
                  final order = extra?['order'] as Order?;
                  final paymentMethod = extra?['paymentMethod'] as PlatformPaymentMethod?;
                  return OrderConfirmationPage(
                    order: order,
                    paymentMethod: paymentMethod,
                  );
                },
              ),
              GoRoute(
                path: 'profile',
                builder: (context, state) {
                  final isMobile = MediaQuery.of(context).size.width < 768;
                  final page = const ProfileScreen();
                  
                  if (isMobile) {
                    return page;
                  } else {
                    // Desktop: usa wrapper com navegação
                    return DesktopPageWrapper(child: page);
                  }
                },
              ),
              GoRoute(
                path: 'profile/edit',
                builder: (context, state) => const EditProfilePage(),
              ),
              GoRoute(
                path: 'orders/history',
                builder: (context, state) {
                  final isMobile = MediaQuery.of(context).size.width < 768;
                  final page = const OrderHistoryPage();
                  
                  if (isMobile) {
                    return page;
                  } else {
                    // Desktop: usa wrapper com navegação
                    return DesktopPageWrapper(child: page);
                  }
                },
              ),
              GoRoute(
                path: 'order/:id',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) {
                    return const Scaffold(body: Center(child: Text('ID inválido')));
                  }
                  return OrderDetailPage(orderId: id);
                },
              ),
              GoRoute(
                path: 'orders/:publicId/review',
                builder: (context, state) {
                  final publicId = state.pathParameters['publicId'] ?? '';
                  if (publicId.isEmpty) {
                    return const Scaffold(body: Center(child: Text('ID inválido')));
                  }
                  return OrderReviewPage(orderPublicId: publicId);
                },
              ),
              GoRoute(
                path: 'auth/signin',
                builder: (context, state) => const EmailAuthPage(isSignUp: false),
              ),
              GoRoute(
                path: 'auth/signup',
                builder: (context, state) => const EmailAuthPage(isSignUp: true),
              ),
              GoRoute(
                path: 'reset-password',
                builder: (context, state) => const ResetPasswordPage(),
              ),
              GoRoute(
                path: 'search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // 🕵️‍♂️ DEBUG PRINT: Este é o nosso "dedo-duro" de navegação.
      print("🔀 [GoRouter] Redirect sendo verificado. Localização atual: ${state.matchedLocation}. Tentando ir para: ${state.uri}");

      final initialized = getIt.isRegistered<bool>(instanceName: 'isInitialized') && getIt.get<bool>(instanceName: 'isInitialized');
      final isSplash = state.matchedLocation == '/splash';

      if (!initialized) {
        print("🔀 [GoRouter] App não inicializado. Redirecionando para /splash.");
        return isSplash ? null : '/splash?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (isSplash) {
        final redirectTo = state.uri.queryParameters['redirectTo'] ?? '/';
        print("_ [GoRouter] Saindo do Splash. Redirecionando para: $redirectTo");
        return redirectTo;
      }

      print("🔀 [GoRouter] Nenhuma regra de redirect foi aplicada. Continuando navegação normal.");
      return null; // Nenhuma outra regra de redirecionamento
    },

    errorPageBuilder: (context, state) => const MaterialPage(child: NotFoundPage()),
  );
}

/// ✅ NOVO: Valida token de deep link de carrinho e navega para o carrinho
Future<void> _validateAndOpenCart(BuildContext context, int cartId, String token) async {
  try {
    final dio = GetIt.I<Dio>();
    
    // Valida token no backend
    final response = await dio.get(
      '/cart/$cartId/validate-token',
      queryParameters: {'token': token},
    );
    
    if (response.statusCode == 200 && response.data['valid'] == true) {
      // Token válido - navega para o carrinho
      // O CartCubit já vai carregar o carrinho automaticamente
      if (context.mounted) {
        context.go('/cart');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carrinho recuperado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Token inválido ou expirado
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link expirado ou inválido. Por favor, adicione os produtos novamente ao carrinho.'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/');
      }
    }
  } catch (e) {
    // Erro ao validar token
    print('❌ Erro ao validar token de carrinho: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao acessar o carrinho. Por favor, tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/');
    }
  }
}