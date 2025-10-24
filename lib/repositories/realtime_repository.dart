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


  Future<void> initialize(String connectionToken) async {
    final completer = Completer<void>();

    final apiUrl = dotenv.env['API_URL'];

    // --- ✅ 2. MUDANÇA NA CONSTRUÇÃO DA URL ---
    // O parâmetro da query agora é `connection_token`.
    final uri = '$apiUrl?connection_token=$connectionToken';

    print("🔌 RealtimeRepository: Conectando ao servidor...");
    print('🛠️ URL de conexão: $uri');

    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    // ✅ LISTENERS ESSENCIAIS (permanecem iguais)
    _socket.on('connect', (_) {
      print('✅ Socket.IO: Conectado com sucesso!');
      if (!completer.isCompleted) completer.complete();
    });

    _socket.on('connect_error', (error) {
      print('❌ Socket.IO: Erro de conexão: $error');
      if (!completer.isCompleted) {
        completer.completeError('Erro ao conectar: $error');
      }
    });

    _socket.on('disconnect', (_) {
      print('⚠️ Socket.IO: Desconectado do servidor');
    });

    // ✅ EVENTOS DE DADOS DO BACKEND (permanecem iguais)
    _socket.on('products_update', (data) {
      print('📦 Produtos atualizados recebidos');
      final List<Product> products = (data as List).map((json) => Product.fromJson(json)).toList();
      productsController.add(products);
    });

    _socket.on('banners_update', (data) {
      print('🎨 Banners atualizados recebidos');
      final List<BannerModel> banners = (data as List).map((json) => BannerModel.fromJson(json)).toList();
      bannersController.add(banners);
    });

    // O evento `initial_state_loaded` agora é manipulado no handler de conexão do backend,
    // então não precisamos de um listener específico para ele aqui, mas para outros eventos sim.
    _socket.on('order_update', (data) {
      print('🛒 Atualização de pedido recebida');
      final Order order = Order.fromJson(data);
      orderController.add(order);
    });

    _socket.connect();

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Timeout ao conectar ao servidor');
      },
    );
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