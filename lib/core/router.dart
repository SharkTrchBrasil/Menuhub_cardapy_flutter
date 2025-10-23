// core/router.dart
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

// Importe todos os cubits e páginas
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/cart_product.dart';
import '../models/coupon.dart';
import '../models/order.dart';
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
import '../pages/signin/signin_page.dart';
import '../pages/store/store_details.dart';

import '../repositories/realtime_repository.dart';
import '../repositories/storee_repository.dart';
import '../themes/HomeSelectorPage.dart';
import 'di.dart';


GoRouter createGoRouter({String? initialSubdomain}) {
  return GoRouter(
    initialLocation: '/splash',
    observers: [BotToastNavigatorObserver()],
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, state) => BlocProvider(
          create: (_) => SplashPageCubit(),
          child: SplashPage(initialSubdomain: initialSubdomain),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/not-found', builder: (_, state) => const NotFoundPage()),

      // --- ROTA PRINCIPAL DA APLICAÇÃO ---
      GoRoute(
        path: '/',
        builder: (_, state) {
          return BlocProvider(
            create: (context) => StoreCubit(GetIt.I<RealtimeRepository>()),
            child: const HomeSelectorPage(),
          );
        },
        // ROTAS FILHAS DA HOME
        routes: [







          GoRoute(
            path: 'cart',
            pageBuilder: (_, state) => CustomTransitionPage(
              child: BlocProvider.value(
                value: GetIt.I<StoreCubit>(),
                child: const CartPage(),
              ),
              opaque: false,
              barrierDismissible: true,
              barrierColor: Colors.black45,
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
            routes: [
              // ✅ ROTA DE SUCESSO DO PEDIDO
              GoRoute(
                path: 'order-summary', // Agora é /cart/order-summary
                pageBuilder: (context, state) {
                  final order = state.extra as Order?;
                  return CustomTransitionPage(
                    child: OrderSummaryPage(order: order),
                    opaque: false,
                    barrierDismissible: true,
                    barrierColor: Colors.black45,
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  );
                },
              ),
            ],
          ),



          // ✅ A NOVA ESTRUTURA PARA O FLUXO DE CHECKOUT
          ShellRoute(
            // O builder da ShellRoute usa o nosso widget "casca"
            builder: (context, state, child) {
              return child;
            },
            // As rotas de endereço e checkout agora são filhas da "casca"
            routes: [

              GoRoute(
                path: 'checkout', // Acessada via /checkout
                pageBuilder: (context, state) => CustomTransitionPage(
                  child: const CheckoutPage(), // A página não precisa mais de provider
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black45,
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),


              GoRoute(
                path: 'address', // Acessada via /address
                pageBuilder: (context, state) => CustomTransitionPage(
                  child: const AddressPage(), // A página não precisa mais de provider
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black45,
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                ),
              ),


              GoRoute(
                path: '/select-address', // ou o caminho que preferir
                builder: (context, state) => const AddressSelectionPage(),
              ),

            ],
          ),





















          GoRoute(
            path: 'add-coupon',
            pageBuilder:
                (context, __) => CustomTransitionPage(
              child: CouponPage(
                realtimeRepository: getIt<RealtimeRepository>(),
              ),
              opaque: false,
              barrierDismissible: true,
              barrierColor: Colors.black45,
              transitionsBuilder:
                  (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),







          // Mantenha suas outras rotas existentes aqui
          GoRoute(
            path: 'store-details', // Agora é /store-details
            pageBuilder: (_, state) {
              final int? initialTabIndex = state.extra as int?;
              return CustomTransitionPage(
                child: BlocProvider(
                  create:
                      (context) => StoreCubit(GetIt.I<RealtimeRepository>()),
                  child: StoreDetails(initialTabIndex: initialTabIndex ?? 0),
                ),
                opaque: false,
                barrierDismissible: true,
                barrierColor: Colors.black45,
                transitionsBuilder:
                    (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              );
            },
          ),

          // Em: seu arquivo de configuração de rotas (ex: lib/core/router.dart)

          GoRoute(
            path: 'product/:productSlug/:id',
            pageBuilder: (context, state) {
              final productId = int.tryParse(state.pathParameters['id'] ?? '');
              if (productId == null) {
                // Idealmente, redirecione para uma página de erro 404
                return const MaterialPage(child: Scaffold(body: Center(child: Text("Produto não encontrado"))));
              }

              final initialProduct = state.extra is Product ? state.extra as Product : null;
              final cartItemToEdit = state.extra is CartItem ? state.extra as CartItem : null;

              // ✅ LÓGICA CONDICIONAL RESTAURADA AQUI
              final isDesktop = MediaQuery.of(context).size.width >= 768; // Ou use seu ResponsiveBuilder

              final pageContent = BlocProvider<ProductPageCubit>(
                create: (context) => ProductPageCubit(
                  productId: productId,
                  repository: getIt<StoreRepository>(), // Supondo que você use get_it
                )..loadProduct(
                  initialProduct: initialProduct,
                  cartItemToEdit: cartItemToEdit,
                ),
                child: const ProductPage(),
              );

              // Se for desktop, cria a página como um "dialog" transparente
              if (isDesktop) {
                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: pageContent,
                  barrierDismissible: true, // Permite fechar clicando fora
                  barrierColor: Colors.black.withOpacity(0.6), // Fundo escurecido
                  opaque: false, // ESSENCIAL: Diz ao router que a página de baixo deve ser visível
                  transitionDuration: const Duration(milliseconds: 200),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                );
              }
              // Se for mobile, cria uma página de tela cheia padrão
              else {
                return MaterialPage<void>(
                  key: state.pageKey,
                  child: pageContent,
                );
              }
            },
          ),
        ],
      ),

    ],

    redirect: (context, state) {
      final initialized =
          getIt.isRegistered<bool>(instanceName: 'isInitialized') &&
              getIt.get<bool>(instanceName: 'isInitialized');
      final isSplash = state.matchedLocation == '/splash';
      if (!initialized) {
        return isSplash
            ? null
            : '/splash?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (isSplash) {
        return state.uri.queryParameters['redirectTo'] ?? '/';
      }
      return null;
    },
    errorPageBuilder:
        (context, state) => const MaterialPage(child: NotFoundPage()),
  );
}









