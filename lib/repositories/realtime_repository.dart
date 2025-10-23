import 'dart:async';

import 'package:either_dart/either.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:totem/models/product.dart';
import 'package:totem/models/store.dart';
import 'package:totem/themes/ds_theme.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

import '../models/banners.dart';
import '../models/cart.dart';
import '../models/coupon.dart';
import '../models/create_order_payload.dart';
import '../models/new_order.dart';
import '../models/order.dart';
import '../models/rating_summary.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../models/update_cart_payload.dart';


class RealtimeRepository {

  RealtimeRepository(this._dsThemeSwitcher);

  late IO.Socket _socket;


  final DsThemeSwitcher _dsThemeSwitcher;

  final BehaviorSubject<Store> storeController = BehaviorSubject<Store>();

  final BehaviorSubject<List<Product>> productsController = BehaviorSubject<List<Product>>();

  final BehaviorSubject<List<BannerModel>> bannersController = BehaviorSubject<List<BannerModel>>();

// CHANGE THIS LINE:
  final BehaviorSubject<Order> orderController = BehaviorSubject<Order>(); // Changed to BehaviorSubject


  Future<void> initialize(String totemToken) async {
    // Usamos um Completer para controlar a conclusão do Future
    final completer = Completer<void>();


    final apiUrl = dotenv.env['API_URL'];
    // ✅ CORREÇÃO: Montamos a URL de conexão com o token diretamente.
    final uri = '$apiUrl?totem_token=$totemToken';

    print("🔌 RealtimeRepository: Preparando para inicializar com o token.");
    print('🛠️ Conectando a: $uri');

    _socket = IO.io(
      uri, // Usa a URL completa com o token
      IO.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
      // ❌ REMOVEMOS o .setAuth(), pois o token já está na URL.
          .build(),
    );



    // Remove listeners antigos para evitar duplicação em caso de reconexão manual
    _socket.clearListeners();



    print("📝 RealtimeRepository: Registrando listeners de eventos...");

    _socket.onConnect((_) {
      print("✅ [Socket.IO] Conectado com sucesso ao servidor!");
      // ✅ A conexão foi um sucesso, então completamos o Future.

      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    _socket.onDisconnect((_) {
      print("🔌 [Socket.IO] Desconectado do servidor.");
    });

    _socket.onError((error) {
      print("❌ [Socket.IO] Ocorreu um erro: $error");

    });

    _socket.on('initial_state_loaded', (data) {
    //  print('✅ [Socket.IO] Evento "initial_state_loaded" recebido!');

      if (data['store'] != null) {
        storeController.add(Store.fromJson(data['store']));
     //   print(data['store']);

      }
      if (data['products'] != null) {
        final products = (data['products'] as List).map((e) => Product.fromJson(e)).toList();

        productsController.add(products);

        print(data['products']);
      }
      if (data['theme'] != null) {
        _dsThemeSwitcher.changeTheme(DsTheme.fromJson(data['theme']));
      }
      if (data['banners'] != null) {
        final banners = (data['banners'] as List).map((e) => BannerModel.fromJson(e)).toList();
        bannersController.add(banners);
      }
    });


    _socket.on('order_updated', (data) {
      try {
        final order = Order.fromJson(data);
        orderController.add(order);
      } catch (e) {
        print('Error parsing order: $e');
      }
    });


    // Em lib/repositories/realtime_repository.dart

// ... dentro da sua função initialize ...

    // ✅ LISTENER CORRIGIDO
    // Em lib/repositories/realtime_repository.dart, dentro da função initialize

    // ... outros listeners ...

    // ✅ LISTENER CORRIGIDO PARA ESPERAR UMA LISTA
    _socket.on('products_updated', (data) { // O 'data' recebido aqui é a lista de produtos
      print('🔄 [Socket.IO] Evento "products_updated" recebido!');
      try {
        // 1. A correção principal: verificamos se o dado recebido é diretamente uma LISTA.
        if (data is List) {

          // 2. Converte a lista de JSON para uma lista de objetos Product
          final updatedProducts = data
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList();

          // 3. Emite a nova lista para quem estiver escutando
          productsController.add(updatedProducts);
          print('✅ Lista de produtos atualizada no cardápio.');

        } else {
          // Se não for uma lista, o formato está realmente errado.
          print('⚠️ Payload de "products_updated" não é uma lista como esperado. Formato recebido: ${data.runtimeType}');
        }
      } catch (e) {
        print('❌ Erro ao processar "products_updated": $e');
      }
    });

// ... resto da função ...




// ✅ ADICIONE ESTE NOVO LISTENER AQUI
    _socket.on('store_updated', (data) {
      print('🔄 [Socket.IO] Evento "store_updated" recebido!');
      try {
        // O payload do 'store_updated' geralmente é o próprio objeto da loja
        if (data != null && data is Map<String, dynamic>) {
          final updatedStore = Store.fromJson(data);

          // Emite a nova informação da loja para quem estiver escutando
          storeController.add(updatedStore);
          print('✅ Dados da loja atualizados no cardápio.');
        }
      } catch (e) {
        print('❌ Erro ao processar "store_updated": $e');
      }
    });


    _socket.onConnectError((error) {
      print("❌ [Socket.IO] Erro de conexão: $error");
      // ✅ A conexão falhou, então completamos o Future com um erro.
      if (!completer.isCompleted) {
        completer.completeError(Exception("Falha ao conectar ao servidor: $error"));
      }
    });




    print("📡 RealtimeRepository: Tentando conectar ao servidor...");
    _socket.connect();


    await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Tempo de conexão esgotado.');
    });

  }

  void dispose() {
    storeController.close();
    productsController.close();
    bannersController.close();
    orderController.close();

  }

  // ✅ MÉTODO `linkCustomerToSession` MAIS SEGURO
  Future<void> linkCustomerToSession(int customerId) async {
    final completer = Completer<void>();

    // Adiciona uma verificação extra para garantir que o socket está conectado
    if (!_socket.connected) {
      print("❌ RealtimeRepository: Tentativa de vincular cliente com socket desconectado.");
      completer.completeError(Exception('Socket não está conectado.'));
      return completer.future;
    }

    _socket.emitWithAck('link_customer_to_session', {'customer_id': customerId}, ack: (data) {
      if (data != null && data['success'] == true) {
        completer.complete();
      } else {
        completer.completeError(Exception(data?['error'] ?? 'Erro ao vincular cliente.'));
      }
    });

    return completer.future;
  }







  Future<Cart> getOrCreateCart() async {
    final completer = Completer<Cart>();

    // Usamos emitWithAck para esperar uma resposta do servidor.
    _socket.emitWithAck('get_or_create_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        // Se sucesso, converte o JSON para nosso modelo Dart.
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        // Se falhar, completa o Future com um erro.
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao buscar carrinho.'),
        );
      }
    });

    return completer.future;
  }


  Future<Cart> applyCoupon(String code) async {
    final completer = Completer<Cart>();
    _socket.emitWithAck('apply_coupon_to_cart', {'coupon_code': code}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        completer.complete(Cart.fromJson(data['cart']));
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao aplicar cupom.'));
      }
    });
    return completer.future;
  }

  Future<Cart> removeCoupon() async {
    final completer = Completer<Cart>();
    _socket.emitWithAck('remove_coupon_from_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        completer.complete(Cart.fromJson(data['cart']));
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao remover cupom.'));
      }
    });
    return completer.future;
  }


  /// Adiciona, atualiza ou remove um item do carrinho.
  Future<Cart> updateCartItem(UpdateCartItemPayload payload) async {
    final completer = Completer<Cart>();

    _socket.emitWithAck('update_cart_item', payload.toJson(), ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao atualizar item no carrinho.'),
        );
      }
    });

    return completer.future;
  }

  /// Remove todos os itens do carrinho.
  Future<Cart> clearCart() async {
    final completer = Completer<Cart>();

    _socket.emitWithAck('clear_cart', {}, ack: (data) {
      if (data['success'] == true && data['cart'] != null) {
        final cart = Cart.fromJson(data['cart']);
        completer.complete(cart);
      } else {
        completer.completeError(
          Exception(data['error'] ?? 'Erro ao limpar o carrinho.'),
        );
      }
    });

    return completer.future;
  }


  Future<Order> sendOrder(CreateOrderPayload payload) async {
    final completer = Completer<Order>();

    // Chama o NOVO evento do backend
    _socket.emitWithAck('create_order_from_cart', payload.toJson(), ack: (data) {
      if (data != null && data['success'] == true && data['order'] != null) {
        try {
          final order = Order.fromJson(data['order']);
          completer.complete(order);
        } catch (e) {
          completer.completeError(Exception('Erro ao processar resposta do pedido.'));
        }
      } else {
        completer.completeError(
          Exception(data?['error'] ?? 'Ocorreu um erro desconhecido ao finalizar o pedido.'),
        );
      }
    });

    return completer.future;
  }



  // Future<Either<String, Order>> sendOrder(NewOrder order) async {
  //   try {
  //     final result = await _socket.emitWithAckAsync('send_order', order.toJson());
  //     print('[SOCKET] Resposta recebida: $result');
  //
  //     if (result == null || result['success'] != true) {
  //       final errorMsg = result?['error'] ?? 'Erro desconhecido';
  //       print('[SOCKET] Erro ao enviar pedido: $errorMsg');
  //       return Left(errorMsg);
  //     }
  //
  //     return Right(Order.fromJson(result['order']));
  //   } catch (e, s) {
  //     print('Error sending order: $e\n$s');
  //     return Left('Erro ao enviar pedido');
  //   }
  // }

  /// Lista todos os cupons disponíveis.
  Future<List<Coupon>> listCoupons() async {
    final completer = Completer<List<Coupon>>();

    _socket.emitWithAck('list_coupons', {}, ack: (data) {
      if (data['error'] == null && data['coupons'] != null) {
        try {
          final coupons = (data['coupons'] as List)
              .map((json) => Coupon.fromJson(json))
              .toList();
          completer.complete(coupons);
        } catch (e) {
          completer.completeError(Exception('Erro ao processar a lista de cupons.'));
        }
      } else {
        completer.completeError(Exception(data['error'] ?? 'Erro ao buscar cupons.'));
      }
    });

    return completer.future;
  }






}