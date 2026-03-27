// core/router.dart
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:totem/core/responsive_builder.dart';
import 'package:totem/cubit/catalog_cubit.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/orders_cubit.dart';
import 'package:totem/pages/splash/splash_page_cubit.dart';
import 'package:totem/pages/splash/splash_page.dart';
import '../helpers/enums/product_status.dart';
import '../helpers/enums/product_type.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/product_category_link.dart';
import '../core/enums/available_type.dart'; // ✅ Import correto
import 'package:collection/collection.dart';
import '../pages/address/address_page.dart';
import '../pages/address/address_selection_page.dart';
import '../pages/cart/cart_page.dart';
import '../pages/checkout/checkout_page.dart';
import '../pages/checkout/desktop_checkout_page.dart';
import '../pages/coupon/coupon_page.dart';
import '../pages/not_found/error_505_Page.dart';
import '../pages/order/order_confirmation_page.dart';
import '../pages/product/product_page_adaptive.dart';
import '../pages/product/product_page_cubit.dart';
import '../pages/signin/signin_page.dart';
import '../pages/store/store_details.dart';
import '../pages/profile/profile_screem.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/orders/order_history_page.dart';
import '../pages/order/order_details_page.dart';
import '../pages/order/order_evaluation_page.dart';
import '../pages/orders/order_review_page.dart';
import '../pages/auth/email_auth_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/search/search_page.dart';
import '../pages/delivery_persons/delivery_persons_page.dart';
import '../pages/address/address_onboarding_page.dart';
import '../pages/address/cubits/address_cubit.dart';
import '../cubit/auth_cubit.dart';
import '../repositories/realtime_repository.dart';
import '../repositories/storee_repository.dart';
import '../pages/home/desktop_home_wrapper.dart';
import '../pages/main_tab/main_tab_page.dart';
import '../widgets/desktop_page_wrapper.dart';
import '../pages/checkout/order_submission_page.dart'; // ✅ NOVO: Página de animação ao enviar pedido
import '../pages/checkout/checkout_cubit.dart'; // ✅ CORREÇÃO: Import para o cubit
import '../pages/pix_payment/pix_payment_page.dart'; // ✅ NOVO: Página de pagamento PIX
import '../core/utils/id_obfuscator.dart'; // ✅ ENTERPRISE: Ofuscação de IDs em URLs
import 'di.dart';

/// ✅ ENTERPRISE: Decodifica ID de produto da URL ofuscada
/// URL: /product/x-burguer-kX7h -> ID 123
int? _decodeProductId(String slugWithId) {
  return IdObfuscator.decodeFromProductUrl(slugWithId);
}

/// ✅ ENTERPRISE: Cria URL de produto com ID ofuscado
/// ID 123 + "X-Burguer" -> "x-burguer-kX7h"
String createProductUrl(int productId, String productName) {
  return IdObfuscator.createProductUrl(productName, productId);
}

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
        pageBuilder:
            (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => SplashPageCubit(),
                child: const SplashPage(),
              ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
      ),
      GoRoute(path: '/not-found', builder: (_, state) => const NotFoundPage()),

      // ✅ ROTA DE ONBOARDING/LOGIN RESTAURADA
      // Colocada no nível superior para ser acessível de qualquer lugar.
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // ✅ NOVO: Rota de onboarding de endereço obrigatório
      GoRoute(
        path: '/address-onboarding',
        builder: (context, state) => const AddressOnboardingPage(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          return BlocProvider.value(value: storeCubit, child: child);
        },
        routes: [
          // ✅ ROTAS PRINCIPAIS (nível superior para URLs funcionarem no navegador)
          // Essas rotas são navegáveis diretamente e aparecem na barra de endereço

          // 🛒 CARRINHO - /cart
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) {
              final isMobile = MediaQuery.of(context).size.width < 768;
              final page = const CartPage();

              if (isMobile) {
                // ✅ Mobile: Slide-up animation (vindo de baixo)
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: page,
                  opaque: true, // Página completa, não overlay
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 1), // Começa de baixo
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                );
              } else {
                // Desktop: usa wrapper com navegação
                return MaterialPage(child: DesktopPageWrapper(child: page));
              }
            },
          ),

          // 🛒 CARRINHO ABANDONADO (deep link) - /cart/:cartId
          GoRoute(
            path: '/cart/:cartId',
            redirect: (context, state) async {
              final token = state.uri.queryParameters['token'];
              final cartIdStr = state.pathParameters['cartId'];

              if (token != null && cartIdStr != null) {
                final cartId = int.tryParse(cartIdStr);
                if (cartId != null) {
                  await _validateAndOpenCart(context, cartId, token);
                  return '/cart';
                }
              }
              return '/';
            },
          ),

          // 📍 SELEÇÃO DE ENDEREÇO - /address
          GoRoute(
            path: '/address',
            pageBuilder: (context, state) {
              final isMobile = MediaQuery.of(context).size.width < 768;
              final page = const AddressPage();

              if (isMobile) {
                // ✅ Mobile: Slide-up animation
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: page,
                  opaque: true,
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                );
              } else {
                return MaterialPage(child: DesktopPageWrapper(child: page));
              }
            },
          ),

          // 📍 SELEÇÃO DE ENDEREÇO (gerenciamento) - /select-address
          GoRoute(
            path: '/select-address',
            pageBuilder: (context, state) {
              final isManagement = state.extra as bool? ?? false;
              final isMobile = MediaQuery.of(context).size.width < 768;
              final page = AddressSelectionPage(isManagement: isManagement);

              if (isMobile) {
                return CustomTransitionPage(
                  key: state.pageKey,
                  child: page,
                  opaque: true,
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                );
              } else {
                return MaterialPage(child: DesktopPageWrapper(child: page));
              }
            },
          ),

          // 💳 CHECKOUT - /checkout
          GoRoute(
            path: '/checkout',
            pageBuilder: (context, state) {
              final isDesktop = MediaQuery.of(context).size.width >= 768;

              if (isDesktop) {
                return MaterialPage(
                  child: DesktopPageWrapper(child: const DesktopCheckoutPage()),
                );
              }

              // ✅ Mobile: Slide-up animation
              return CustomTransitionPage(
                key: state.pageKey,
                child: const CheckoutPage(),
                opaque: true,
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              );
            },
          ),

          // ⏳ SUBMISSÃO DE PEDIDO (animação) - /order/submitting
          GoRoute(
            path: '/order/submitting',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final checkoutCubit = extra?['checkoutCubit'] as CheckoutCubit?;

              if (checkoutCubit != null) {
                return BlocProvider.value(
                  value: checkoutCubit,
                  child: const OrderSubmissionPage(),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/checkout');
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          ),

          // ✅ SUCESSO - /success (simplificado de /order/success)
          GoRoute(
            path: '/success',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final order = extra?['order'] as Order?;
              final paymentMethod =
                  extra?['paymentMethod'] as PlatformPaymentMethod?;
              return OrderConfirmationPage(
                order: order,
                paymentMethod: paymentMethod,
              );
            },
          ),

          // 🏠 HOME - /
          GoRoute(
            path: '/',
            pageBuilder: (context, state) {
              final isMobile = MediaQuery.of(context).size.width < 768;
              final child =
                  isMobile ? const MainTabPage() : const DesktopHomeWrapper();
              return CustomTransitionPage(
                key: state.pageKey,
                child: child,
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300),
              );
            },
            routes: [
              // Subrotas que ainda fazem sentido estar aninhadas na home
              GoRoute(
                path: 'add-coupon',
                pageBuilder:
                    (context, __) => CustomTransitionPage(
                      child: const CouponPage(),
                      opaque: false,
                      barrierDismissible: true,
                      barrierColor: Colors.black45,
                      transitionsBuilder:
                          (_, animation, __, child) =>
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
                    transitionsBuilder:
                        (_, animation, __, child) =>
                            FadeTransition(opacity: animation, child: child),
                  );
                },
              ),
              // ✅ NOVO: Rota para categorias customizáveis (Pizzas) sem produto base
              GoRoute(
                path: 'category/:slug/:categoryId',
                pageBuilder: (context, state) {
                  final categoryId = int.tryParse(
                    state.pathParameters['categoryId'] ?? '',
                  );
                  final sizeId = int.tryParse(
                    state.uri.queryParameters['size'] ?? '',
                  );
                  var category = state.extra as Category?;

                  // Se não veio no extra, tenta buscar no CatalogCubit
                  if (category == null && categoryId != null) {
                    final catalogState = context.read<CatalogCubit>().state;
                    category = catalogState.categories?.firstWhereOrNull(
                      (c) => c.id == categoryId,
                    );
                  }

                  if (categoryId == null || category == null) {
                    return const MaterialPage(
                      child: Scaffold(
                        body: Center(child: Text("Categoria não encontrada")),
                      ),
                    );
                  }

                  // Cria produto virtual para o Cubit
                  final virtualProduct = Product(
                    id: 0, // ID virtual
                    name: category.name,
                    description: category.description,
                    images: category.image != null ? [category.image!] : [],
                    prices: [],
                    categoryLinks: [
                      ProductCategoryLink(
                        productId: 0,
                        categoryId: category.id!,
                        price: 0,
                      ),
                    ], // ✅ Corrigido: productId=0, sem position
                    status: ProductStatus.ACTIVE,
                    storeId: 0,
                    productType:
                        ProductType.INDIVIDUAL, // ✅ Corrigido: INDIVIDUAL
                    availabilityType:
                        AvailabilityType
                            .always, // ✅ Corrigido: always (minúsculo)
                  );

                  final isDesktop = MediaQuery.of(context).size.width >= 768;

                  final pageContent = BlocProvider<ProductPageCubit>(
                    create:
                        (context) => ProductPageCubit(
                          productId: 0,
                          repository: getIt<StoreRepository>(),
                          storeCubit: context.read<StoreCubit>(),
                          catalogCubit: context.read<CatalogCubit>(),
                        )..loadProduct(
                          initialProduct: virtualProduct,
                          sizeId: sizeId,
                        ),
                    child: const ProductPageAdaptive(),
                  );

                  if (isDesktop) {
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                      barrierDismissible: true,
                      barrierColor: Colors.black.withOpacity(0.6),
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 200),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    );
                  } else {
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                    );
                  }
                },
              ),
              // ✅ NOVO: Rota para URLs com ID criptografado (compartilhamento)
              // URL: /produto/x-burguer-xK7hG2n
              GoRoute(
                path: 'produto/:encodedSlug',
                pageBuilder: (context, state) {
                  final encodedSlug = state.pathParameters['encodedSlug'] ?? '';
                  final shareToken = state.uri.queryParameters['t'];

                  if (encodedSlug.isEmpty) {
                    return const MaterialPage(
                      child: Scaffold(
                        body: Center(child: Text("Produto não encontrado")),
                      ),
                    );
                  }

                  final isDesktop = MediaQuery.of(context).size.width >= 768;

                  // Widget que resolve o ID e carrega o produto
                  final pageContent = _ProductResolver(
                    encodedSlug: encodedSlug,
                    shareToken: shareToken,
                    isDesktop: isDesktop,
                  );

                  if (isDesktop) {
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                      barrierDismissible: true,
                      barrierColor: Colors.black.withOpacity(0.6),
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 200),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    );
                  } else {
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                    );
                  }
                },
              ),
              // ✅ ENTERPRISE: Rota com ID ofuscado (novo formato)
              // URL: /product/x-burguer-kX7h (slug + ID ofuscado)
              GoRoute(
                path: 'product/:productSlugWithId',
                pageBuilder: (context, state) {
                  final slugWithId =
                      state.pathParameters['productSlugWithId'] ?? '';

                  // Importa o ofuscador
                  final productId = _decodeProductId(slugWithId);

                  if (productId == null) {
                    return const MaterialPage(
                      child: Scaffold(
                        body: Center(child: Text("Produto não encontrado")),
                      ),
                    );
                  }

                  // ✅ Extrai sizeId da query string (para pizzas)
                  final sizeId = int.tryParse(
                    state.uri.queryParameters['size'] ?? '',
                  );

                  final initialProduct =
                      state.extra is Product ? state.extra as Product : null;
                  final cartItemToEdit =
                      state.extra is CartItem ? state.extra as CartItem : null;
                  final isDesktop = MediaQuery.of(context).size.width >= 768;

                  final pageContent = BlocProvider<ProductPageCubit>(
                    create:
                        (context) => ProductPageCubit(
                          productId: productId,
                          repository: getIt<StoreRepository>(),
                          storeCubit: context.read<StoreCubit>(),
                          catalogCubit: context.read<CatalogCubit>(),
                        )..loadProduct(
                          initialProduct: initialProduct,
                          cartItemToEdit: cartItemToEdit,
                          sizeId: sizeId, // ✅ Passa o sizeId para o cubit
                        ),
                    child: const ProductPageAdaptive(),
                  );

                  if (isDesktop) {
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                      barrierDismissible: true,
                      barrierColor: Colors.black.withOpacity(0.6),
                      opaque: false,
                      transitionDuration: const Duration(milliseconds: 200),
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    );
                  } else {
                    return MaterialPage<void>(
                      key: state.pageKey,
                      child: pageContent,
                    );
                  }
                },
              ),
              GoRoute(
                path: 'order/success',
                builder: (context, state) {
                  // ✅ CORREÇÃO: Recebe order e paymentMethod do extra
                  final extra = state.extra as Map<String, dynamic>?;
                  final order = extra?['order'] as Order?;
                  final paymentMethod =
                      extra?['paymentMethod'] as PlatformPaymentMethod?;
                  return OrderConfirmationPage(
                    order: order,
                    paymentMethod: paymentMethod,
                  );
                },
              ),
              // ✅ NOVO: Página de pagamento PIX com QR Code
              GoRoute(
                path: 'pix-payment',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  if (extra == null) {
                    // Sem dados, volta para home
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) context.go('/');
                    });
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return PixPaymentPage(
                    totalCents: extra['totalCents'] as int? ?? 0,
                    pixKey: extra['pixKey'] as String? ?? '',
                    pixKeyType: extra['pixKeyType'] as String?,
                    storeName: extra['storeName'] as String? ?? '',
                    storeCity: extra['storeCity'] as String? ?? '',
                    orderNumber: extra['orderNumber'] as String?,
                    orderId: extra['orderId'] as int?,
                    order:
                        extra['order']
                            as Order?, // ✅ NOVO: Order completo para navegação
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
                path: 'orders/waiting',
                builder: (context, state) {
                  final publicId = state.uri.queryParameters['order'] ?? '';

                  // Tenta buscar da lista já carregada se o cliente estiver logado
                  final ordersCubit = context.read<OrdersCubit>();
                  final order =
                      ordersCubit.state.orders
                          .where((o) => o.publicId == publicId)
                          .firstOrNull;

                  if (order != null) {
                    return OrderDetailsPage(order: order);
                  }

                  // Fallback se não estiver carregado ou não existir na sessão atual
                  return Scaffold(
                    appBar: AppBar(title: const Text('Rastrear Pedido')),
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Pedido $publicId',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Para acompanhar seu pedido, faça login ou acesse a aba Meus Pedidos se já estiver conectado.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.go('/orders/history'),
                            child: const Text('Meus Pedidos'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                  // ✅ OTIMIZADO: Recebe Order via extra, sem fazer GET
                  final order = state.extra as Order?;

                  if (order == null) {
                    // Fallback: se não recebeu o Order, volta para histórico
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('Pedido não encontrado'),
                      ),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            const Text('Pedido não encontrado.'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context.go('/orders/history'),
                              child: const Text('Ir para Pedidos'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return OrderDetailsPage(
                    order: order,
                    showActions: true,
                    showRating: false,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'evaluate',
                    builder: (context, state) {
                      final order = state.extra as Order?;
                      if (order == null) return const SizedBox();
                      return OrderEvaluationPage(order: order);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'orders/:publicId/review',
                builder: (context, state) {
                  final publicId = state.pathParameters['publicId'] ?? '';
                  if (publicId.isEmpty) {
                    return const Scaffold(
                      body: Center(child: Text('ID inválido')),
                    );
                  }
                  return OrderReviewPage(orderPublicId: publicId);
                },
              ),
              GoRoute(
                path: 'auth/signin',
                builder:
                    (context, state) => const EmailAuthPage(isSignUp: false),
              ),
              GoRoute(
                path: 'auth/signup',
                builder:
                    (context, state) => const EmailAuthPage(isSignUp: true),
              ),
              GoRoute(
                path: 'reset-password',
                builder: (context, state) => const ResetPasswordPage(),
              ),
              GoRoute(
                path: 'search',
                builder: (context, state) => const SearchPage(),
              ),
              // ✅ NOVO: Rotas para configurações de entregas, entregadores e horários
              GoRoute(
                path: 'stores/:storeId/settings/hours',
                builder: (context, state) {
                  final storeId = int.tryParse(
                    state.pathParameters['storeId'] ?? '',
                  );
                  if (storeId == null) {
                    return const Scaffold(
                      body: Center(child: Text('ID da loja inválido')),
                    );
                  }
                  // Redireciona para store-details na aba de informações (onde há horários)
                  return const StoreDetails(initialTabIndex: 1);
                },
              ),
              GoRoute(
                path: 'stores/:storeId/settings/shipping',
                builder: (context, state) {
                  final storeId = int.tryParse(
                    state.pathParameters['storeId'] ?? '',
                  );
                  if (storeId == null) {
                    return const Scaffold(
                      body: Center(child: Text('ID da loja inválido')),
                    );
                  }
                  // Redireciona para store-details na aba de informações (onde há configurações de entrega)
                  return const StoreDetails(initialTabIndex: 1);
                },
              ),
              GoRoute(
                path: 'stores/:storeId/delivery-persons',
                builder: (context, state) {
                  final storeId = int.tryParse(
                    state.pathParameters['storeId'] ?? '',
                  );
                  if (storeId == null) {
                    return const Scaffold(
                      body: Center(child: Text('ID da loja inválido')),
                    );
                  }
                  return DeliveryPersonsPage(storeId: storeId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      // 🕵️‍♂️ DEBUG PRINT: Este é o nosso "dedo-duro" de navegação.
      print(
        "🔀 [GoRouter] Redirect sendo verificado. Localização atual: ${state.matchedLocation}. Tentando ir para: ${state.uri}",
      );

      final initialized =
          getIt.isRegistered<bool>(instanceName: 'isInitialized') &&
          getIt.get<bool>(instanceName: 'isInitialized');
      final isSplash = state.matchedLocation == '/splash';

      if (!initialized) {
        print(
          "🔀 [GoRouter] App não inicializado. Redirecionando para /splash.",
        );
        return isSplash
            ? null
            : '/splash?redirectTo=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (isSplash) {
        // ✅ CORRIGIDO: Verifica se usuário está logado sem endereço
        // Agora aguarda o carregamento dos endereços antes de decidir
        try {
          final authCubit = getIt<AuthCubit>();
          final addressCubit = getIt<AddressCubit>();
          final customer = authCubit.state.customer;

          if (customer != null && customer.id != null) {
            print(
              "📍 [GoRouter] Usuário logado (${customer.name}). Verificando endereços...",
            );

            // ✅ CORREÇÃO: Sempre carrega endereços e AGUARDA se ainda não carregou
            if (addressCubit.state.status == AddressStatus.initial ||
                (addressCubit.state.addresses.isEmpty &&
                    addressCubit.state.status != AddressStatus.success)) {
              print("📍 [GoRouter] Carregando endereços do servidor...");
              await addressCubit.loadAddresses(customer.id!);
              print(
                "📍 [GoRouter] Endereços carregados: ${addressCubit.state.addresses.length}",
              );
            }

            // ✅ CORREÇÃO: Só verifica após o carregamento ter sido concluído (success ou error)
            final hasAddresses = addressCubit.state.addresses.isNotEmpty;

            if (!hasAddresses &&
                addressCubit.state.status == AddressStatus.success) {
              // ✅ CORREÇÃO: Só redireciona se os endereços foram carregados com sucesso E a lista está vazia
              print(
                "📍 [GoRouter] Usuário SEM endereço (confirmado). Redirecionando para /address-onboarding",
              );
              return '/address-onboarding';
            }

            print(
              "✅ [GoRouter] Usuário tem ${addressCubit.state.addresses.length} endereço(s). Indo para home.",
            );
          } else {
            // ✅ CORREÇÃO: Usuário não logado não precisa de endereço obrigatório
            print(
              "👤 [GoRouter] Usuário não está logado. Indo para home (sem exigir endereço).",
            );
          }
        } catch (e) {
          print(
            "❌ [GoRouter] Erro ao verificar endereços: $e. Indo para home.",
          );
        }

        final redirectTo = state.uri.queryParameters['redirectTo'] ?? '/';
        print(
          "_ [GoRouter] Saindo do Splash. Redirecionando para: $redirectTo",
        );
        return redirectTo;
      }

      print(
        "🔀 [GoRouter] Nenhuma regra de redirect foi aplicada. Continuando navegação normal.",
      );
      return null; // Nenhuma outra regra de redirecionamento
    },

    errorPageBuilder:
        (context, state) => const MaterialPage(child: NotFoundPage()),
  );
}

/// ✅ NOVO: Valida token de deep link de carrinho e navega para o carrinho
Future<void> _validateAndOpenCart(
  BuildContext context,
  int cartId,
  String token,
) async {
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
            content: Text(
              'Link expirado ou inválido. Por favor, adicione os produtos novamente ao carrinho.',
            ),
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
          content: Text(
            'Erro ao acessar o carrinho. Por favor, tente novamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/');
    }
  }
}

/// ✅ NOVO: Widget que resolve ID criptografado e carrega página do produto
class _ProductResolver extends StatefulWidget {
  final String encodedSlug;
  final String? shareToken;
  final bool isDesktop;

  const _ProductResolver({
    required this.encodedSlug,
    this.shareToken,
    required this.isDesktop,
  });

  @override
  State<_ProductResolver> createState() => _ProductResolverState();
}

class _ProductResolverState extends State<_ProductResolver> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveProduct();
  }

  Future<void> _resolveProduct() async {
    try {
      final dio = GetIt.I<Dio>();

      // Chama API para resolver o ID criptografado
      final response = await dio.get(
        '/products/resolve/${widget.encodedSlug}',
        queryParameters:
            widget.shareToken != null ? {'t': widget.shareToken} : null,
      );

      if (response.statusCode == 200) {
        final productId = response.data['product_id'] as int;
        final productName = response.data['product_name'] as String;

        // ✅ ENTERPRISE: Usa ID ofuscado na URL
        final productUrl = IdObfuscator.createProductUrl(
          productName,
          productId,
        );

        // Redireciona para a rota existente com ID ofuscado
        if (mounted) {
          context.go('/product/$productUrl');
        }
      } else {
        setState(() {
          _error = 'Produto não encontrado';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erro ao resolver produto: $e');
      setState(() {
        _error = 'Erro ao carregar produto';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando produto...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produto')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Voltar ao Cardápio'),
              ),
            ],
          ),
        ),
      );
    }

    // Não deve chegar aqui (redirect acontece antes)
    return const SizedBox.shrink();
  }
}
