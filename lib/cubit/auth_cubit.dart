import 'package:flutter/material.dart';
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
import 'package:bot_toast/bot_toast.dart';
import 'package:web/web.dart' as web;
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
      AppLogger.i(
        'Processando item pendente: ${pendingPayload.productId}',
        tag: 'AUTH',
      );
      try {
        await cartCubit.updateItem(pendingPayload);
        await PendingCartService.clearPendingCartItem();
        AppLogger.i('Item pendente adicionado ao carrinho', tag: 'AUTH');
      } catch (e) {
        AppLogger.e('Erro ao adicionar item pendente', error: e, tag: 'AUTH');
        // Não falha o login se houver erro ao adicionar item
      }
    }
  }

  Future<void> checkInitialAuthStatus() async {
    print('🚀 [DEBUG_AUTH] checkInitialAuthStatus started');

    // No Web, sempre verificamos se acabamos de voltar de um redirect de login
    if (kIsWeb) {
      print('🚀 [DEBUG_AUTH] Web detected. Checking for redirect result...');
      await _handleRedirectResult();
    }

    final initialCustomer = customerController.value;
    if (initialCustomer != null) {
      try {
        await realtimeRepository.linkCustomerToSession(initialCustomer.id!);
        emit(
          state.copyWith(status: AuthStatus.success, customer: initialCustomer),
        );
        cartCubit.fetchCart();
        addressCubit.loadAddresses(initialCustomer.id!);
        ordersCubit.loadOrders(initialCustomer.id!);
        await _processPendingCartItem();
      } catch (e) {
        await signOut();
      }
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signInWithGoogle() async {
    print('🎯 [DEBUG_AUTH] BOTÃO GOOGLE CLICADO!');
    AppLogger.i('Iniciando login com Google (Redirect mode)', tag: 'AUTH');

    try {
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Firebase não está configurado.',
          ),
        );
        return;
      }

      final auth = FirebaseAuth.instanceFor(app: apps.first);
      final authProvider = GoogleAuthProvider();

      if (kIsWeb) {
        print('🌐 [DEBUG_AUTH] Abrindo POPUP de login Google (Modo Original)');
        final userCredential = await auth.signInWithPopup(authProvider);
        print('✅ [DEBUG_AUTH] Popup concluído com sucesso');
        await _processUserCredential(userCredential);
      } else {
        print('📱 [DEBUG_AUTH] Usando fluxo mobile de login Google');
        final userCredential = await auth.signInWithPopup(authProvider);
        await _processUserCredential(userCredential);
      }
    } on FirebaseAuthException catch (e) {
      print('❌ [DEBUG_AUTH] ERRO Firebase Auth: ${e.code}');
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Erro no login: ${e.message}',
        ),
      );
    } catch (e) {
      print('❌ [DEBUG_AUTH] ERRO Inesperado: $e');
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Ocorreu um erro inesperado.',
        ),
      );
    }
  }

  /// ✅ Processa o resultado de um login (seja via popup ou redirect) com persistência
  Future<void> _handleRedirectResult() async {
    try {
      final auth = FirebaseAuth.instance;

      // ✅ 1. Tenta pegar o resultado do redirect (tenta 3 vezes com delay)
      UserCredential? userCredential;
      for (int i = 0; i < 3; i++) {
        userCredential = await auth.getRedirectResult();
        if (userCredential != null) break;
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }

      if (userCredential != null && userCredential.user != null) {
        print(
          '✅ [DEBUG_AUTH] Redirect Result encontrado para: ${userCredential.user?.email}',
        );
        await _processUserCredential(userCredential);
        return;
      }

      // ✅ 2. Backup: Se não veio no redirect, talvez o Firebase já tenha logado em background
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        print(
          '👤 [DEBUG_AUTH] Usuário já persistido encontrado: ${currentUser.email}',
        );
        // Criamos um UserCredential fake ou apenas processamos o user
        // Como _processUserCredential usa UserCredential, vamos criar um mock
        // Mas o mais seguro é chamar o repositório direto com o currentUser
        await _processFirebaseUser(currentUser);
        return;
      }

      print(
        'ℹ️ [DEBUG_AUTH] Nenhum resultado de redirect ou usuário logado após 3 tentativas.',
      );
    } catch (e) {
      print('❌ [DEBUG_AUTH] Erro ao processar resultado do redirect: $e');
    }
  }

  Future<void> _processUserCredential(UserCredential userCredential) async {
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return;
    await _processFirebaseUser(firebaseUser);
  }

  Future<void> _processFirebaseUser(User firebaseUser) async {
    emit(state.copyWith(status: AuthStatus.loading));
    print(
      '🚀 [DEBUG_AUTH] Calling processGoogleSignInCustomer for: ${firebaseUser.email}',
    );

    try {
      final customerResult = await customerRepository
          .processGoogleSignInCustomer(firebaseUser: firebaseUser)
          .timeout(const Duration(seconds: 15));

      print(
        '🚀 [DEBUG_AUTH] processGoogleSignInCustomer result: ${customerResult.isRight ? "SUCCESS" : "ERROR"}',
      );

      customerResult.fold(
        (errorMessage) {
          print('🚀 [DEBUG_AUTH] Error message from backend: $errorMessage');
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: errorMessage,
            ),
          );
          if (kIsWeb) web.window.alert("Backend error: $errorMessage");
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            print(
              '🚀 [DEBUG_AUTH] Finalizing login for customer: ${customer.id}',
            );

            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(
              state.copyWith(status: AuthStatus.success, customer: customer),
            );
            cartCubit.fetchCart();

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

            await _processPendingCartItem();
            print('🎉 [DEBUG_AUTH] AUTH SUCCESSFUL!');
          } catch (e) {
            print('❌ [DEBUG_AUTH] Error linking session: $e');
            emit(
              state.copyWith(
                status: AuthStatus.error,
                errorMessage: 'Erro ao vincular sessão.',
              ),
            );
          }
        },
      );
    } catch (e) {
      print('❌ [DEBUG_AUTH] Timeout ou Erro na API: $e');
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'O servidor demorou a responder.',
        ),
      );
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
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                'Firebase não está configurado. Por favor, reinicie o aplicativo.',
          ),
        );
        return;
      }

      final auth = FirebaseAuth.instanceFor(app: apps.first);
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Não foi possível obter os dados do usuário.',
          ),
        );
        return;
      }

      // Processa o cliente no backend
      final customerResult = await customerRepository
          .processGoogleSignInCustomer(firebaseUser: firebaseUser);

      customerResult.fold(
        (errorMessage) {
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: errorMessage,
            ),
          );
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(
              state.copyWith(status: AuthStatus.success, customer: customer),
            );
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
            emit(
              state.copyWith(
                status: AuthStatus.error,
                errorMessage: 'Erro ao vincular sessão ao carrinho.',
              ),
            );
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
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: errorMessage),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Erro inesperado: $e',
        ),
      );
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
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                'Firebase não está configurado. Por favor, reinicie o aplicativo.',
          ),
        );
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
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Não foi possível criar a conta.',
          ),
        );
        return;
      }

      // Atualiza o display name
      await firebaseUser.updateDisplayName(name);
      await firebaseUser.reload();
      final updatedUser = auth.currentUser;

      if (updatedUser == null) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Erro ao atualizar dados do usuário.',
          ),
        );
        return;
      }

      // Processa o cliente no backend
      final customerResult = await customerRepository
          .processGoogleSignInCustomer(firebaseUser: updatedUser);

      customerResult.fold(
        (errorMessage) {
          emit(
            state.copyWith(
              status: AuthStatus.error,
              errorMessage: errorMessage,
            ),
          );
        },
        (loginResponse) async {
          try {
            final customer = loginResponse.customer;
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(
              state.copyWith(status: AuthStatus.success, customer: customer),
            );
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
            emit(
              state.copyWith(
                status: AuthStatus.error,
                errorMessage: 'Erro ao vincular sessão ao carrinho.',
              ),
            );
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
      emit(
        state.copyWith(status: AuthStatus.error, errorMessage: errorMessage),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Erro inesperado: $e',
        ),
      );
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
      AppLogger.d('⚠️ Erro ao fazer logout do Firebase: $e');
    }
    customerController.clearCustomer();
    realtimeRepository
        .clearCustomer(); // ✅ NOVO: Limpa ID vinculado no repositório
    cartCubit.clearCart();
    ordersCubit.clearOrders(); // ✅ NOVO: Limpa pedidos
    //  addressCubit.clearAddresses();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
