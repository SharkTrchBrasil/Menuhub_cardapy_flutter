import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/core/utils/app_logger.dart';
import 'package:totem/core/exceptions/app_exception.dart';
import 'package:totem/cubit/orders_cubit.dart';

import '../pages/address/cubits/address_cubit.dart';
import '../pages/cart/cart_cubit.dart';
import '../repositories/realtime_repository.dart';
import '../services/pending_cart_service.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.customerRepository,
    required this.customerController,
    required this.realtimeRepository,
    required this.cartCubit,
    required this.addressCubit,
    required this.ordersCubit,
  }) : super(const AuthState());

  final CustomerRepository customerRepository;
  final CustomerController customerController;
  final RealtimeRepository realtimeRepository;
  final CartCubit cartCubit;
  final AddressCubit addressCubit;
  final OrdersCubit ordersCubit;

  /// ✅ Método auxiliar para processar payload pendente após login bem-sucedido
  Future<void> _processPendingCartItem() async {
    final pendingPayload = await PendingCartService.getPendingCartItem();
    if (pendingPayload != null) {
      AppLogger.info('Processando item pendente: ${pendingPayload.productId}', tag: 'AUTH');
      try {
        await cartCubit.updateItem(pendingPayload);
        await PendingCartService.clearPendingCartItem();
        AppLogger.success('Item pendente adicionado ao carrinho', tag: 'AUTH');
      } catch (e) {
        AppLogger.error('Erro ao adicionar item pendente', error: e, tag: 'AUTH');
        // Não falha o login se houver erro ao adicionar item
      }
    }
  }

  Future<void> checkInitialAuthStatus() async {
    // ... (este método não precisa de prints por agora)
    final initialCustomer = customerController.value;
    if (initialCustomer != null) {
      try {
        await realtimeRepository.linkCustomerToSession(initialCustomer.id!);
        emit(state.copyWith(status: AuthStatus.success, customer: initialCustomer));
        cartCubit.fetchCart();
        addressCubit.loadAddresses(initialCustomer.id!);
        ordersCubit.loadOrders(initialCustomer.id!);  // ✅ NOVO: Carrega pedidos
        // ✅ Processa payload pendente se houver
        await _processPendingCartItem();
      } catch (e) {
        await signOut();
      }
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signInWithGoogle() async {
    AppLogger.info('Iniciando login com Google', tag: 'AUTH');

    try {
      // ✅ Verifica se Firebase está inicializado
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        AppLogger.error('Firebase não está inicializado', tag: 'AUTH');
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase não está configurado. Por favor, reinicie o aplicativo.'));
        return;
      }
      
      AppLogger.debug('Firebase configurado: ${apps.first.options.projectId}', tag: 'AUTH');
      
      final auth = FirebaseAuth.instanceFor(app: apps.first);
      final authProvider = GoogleAuthProvider();

      AppLogger.debug('Abrindo popup de login Google', tag: 'AUTH');
      final userCredential = await auth.signInWithPopup(authProvider);
      AppLogger.success('Login Google concluído', tag: 'AUTH');

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        AppLogger.error('Usuário nulo após login', tag: 'AUTH');
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Não foi possível obter os dados do usuário.'));
        return;
      }

      AppLogger.debug('Usuário: ${firebaseUser.displayName}', tag: 'AUTH');
      emit(state.copyWith(status: AuthStatus.loading));

      final customerResult = await customerRepository.processGoogleSignInCustomer(firebaseUser: firebaseUser);
      AppLogger.debug("🕵️‍♂️ [AuthCubit] 5. processGoogleSignInCustomer CONCLUÍDO.");

      customerResult.fold(
            (errorMessage) {
          AppLogger.debug("❌ [AuthCubit] ERRO no processGoogleSignInCustomer: $errorMessage");
          emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            
            // ✅ OTIMIZAÇÃO: Usa dados que já vieram no login (sem chamadas HTTP separadas)
            if (loginResponse.addresses.isNotEmpty) {
              AppLogger.info('✅ [AuthCubit] Usando ${loginResponse.addresses.length} endereços do login', tag: 'AUTH');
              addressCubit.setAddressesFromLogin(loginResponse.addresses);
            } else {
              // Fallback: carrega do servidor se não veio no login
              addressCubit.loadAddresses(customer.id!);
            }
            
            if (loginResponse.orders.isNotEmpty) {
              AppLogger.info('✅ [AuthCubit] Usando ${loginResponse.orders.length} pedidos do login', tag: 'AUTH');
              ordersCubit.setOrdersFromLogin(loginResponse.orders);
            } else {
              // Fallback: carrega do servidor se não veio no login
              ordersCubit.loadOrders(customer.id!);
            }
            
            // ✅ Processa payload pendente após login bem-sucedido
            await _processPendingCartItem();
          } catch (e) {
            emit(state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Erro ao vincular sessão ao carrinho.',
            ));
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        AppLogger.debug("⚠️ [AuthCubit] ERRO CAPTURADO: O popup foi fechado (pelo usuário ou pelo sistema). Código: ${e.code}");
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      } else {
        AppLogger.debug("❌ [AuthCubit] ERRO FIREBASE não esperado: ${e.code} - ${e.message}");
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Ocorreu um erro no login. Tente novamente.'));
      }
    } catch (e) {
      AppLogger.debug("❌ [AuthCubit] ERRO GENÉRICO não esperado: $e");
      emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Ocorreu um erro inesperado. Tente novamente.'));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      // ✅ Verifica se Firebase está inicializado
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase não está configurado. Por favor, reinicie o aplicativo.'));
        return;
      }
      
      final auth = FirebaseAuth.instanceFor(app: apps.first);
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Não foi possível obter os dados do usuário.',
        ));
        return;
      }

      // Processa o cliente no backend
      final customerResult = await customerRepository.processGoogleSignInCustomer(
        firebaseUser: firebaseUser,
      );

      customerResult.fold(
        (errorMessage) {
          emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            
            // ✅ OTIMIZAÇÃO: Usa dados que já vieram no login
            if (loginResponse.addresses.isNotEmpty) {
              addressCubit.setAddressesFromLogin(loginResponse.addresses);
            } else {
              addressCubit.loadAddresses(customer.id!);
            }
            
            if (loginResponse.orders.isNotEmpty) {
              ordersCubit.setOrdersFromLogin(loginResponse.orders);
            } else {
              ordersCubit.loadOrders(customer.id!);
            }
          } catch (e) {
            emit(state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Erro ao vincular sessão ao carrinho.',
            ));
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao fazer login';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Usuário não encontrado';
          break;
        case 'wrong-password':
          errorMessage = 'Senha incorreta';
          break;
        case 'invalid-email':
          errorMessage = 'E-mail inválido';
          break;
        case 'user-disabled':
          errorMessage = 'Usuário desabilitado';
          break;
      }
      emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Erro inesperado: $e',
      ));
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      // ✅ Verifica se Firebase está inicializado
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase não está configurado. Por favor, reinicie o aplicativo.'));
        return;
      }
      
      final auth = FirebaseAuth.instanceFor(app: apps.first);

      // Cria o usuário no Firebase
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Não foi possível criar a conta.',
        ));
        return;
      }

      // Atualiza o display name
      await firebaseUser.updateDisplayName(name);
      await firebaseUser.reload();
      final updatedUser = auth.currentUser;

      if (updatedUser == null) {
        emit(state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Erro ao atualizar dados do usuário.',
        ));
        return;
      }

      // Processa o cliente no backend
      final customerResult = await customerRepository.processGoogleSignInCustomer(
        firebaseUser: updatedUser,
      );

      customerResult.fold(
        (errorMessage) {
          emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            
            // ✅ OTIMIZAÇÃO: Usa dados que já vieram no login
            if (loginResponse.addresses.isNotEmpty) {
              addressCubit.setAddressesFromLogin(loginResponse.addresses);
            } else {
              addressCubit.loadAddresses(customer.id!);
            }
            
            if (loginResponse.orders.isNotEmpty) {
              ordersCubit.setOrdersFromLogin(loginResponse.orders);
            } else {
              ordersCubit.loadOrders(customer.id!);
            }
          } catch (e) {
            emit(state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Erro ao vincular sessão ao carrinho.',
            ));
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erro ao criar conta';
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Senha muito fraca';
          break;
        case 'email-already-in-use':
          errorMessage = 'E-mail já está em uso';
          break;
        case 'invalid-email':
          errorMessage = 'E-mail inválido';
          break;
      }
      emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Erro inesperado: $e',
      ));
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        throw Exception('Firebase não está configurado');
      }
      final auth = FirebaseAuth.instanceFor(app: apps.first);
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception('Erro ao enviar email de recuperação: ${e.message}');
    }
  }

  void updateCustomer(Customer updatedCustomer) {
    customerController.setCustomer(updatedCustomer);
    emit(state.copyWith(customer: updatedCustomer));
  }

  Future<void> signOut() async {
    try {
      final apps = Firebase.apps;
      if (apps.isNotEmpty) {
        final auth = FirebaseAuth.instanceFor(app: apps.first);
        await auth.signOut();
      }
    } catch (e) {
      AppLogger.debug('⚠️ Erro ao fazer logout do Firebase: $e');
    }
    customerController.clearCustomer();
    cartCubit.clearCart();
    ordersCubit.clearOrders();  // ✅ NOVO: Limpa pedidos
  //  addressCubit.clearAddresses();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}