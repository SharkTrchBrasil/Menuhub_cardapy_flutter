import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/core/di.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/auth_repository.dart';
import 'package:totem/core/utils/app_logger.dart';

import 'package:totem/cubit/orders_cubit.dart';

import '../pages/address/cubits/address_cubit.dart';
import '../pages/address/cubits/delivery_fee_cubit.dart';
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
  }) : super(
         customerController.value != null
             ? AuthState(
               status: AuthStatus.success,
               customer: customerController.value,
             )
             : const AuthState(),
       ) {
    // ✅ Sincroniza o estado do Cubit com o Controller
    customerController.addListener(_syncCustomerFromController);
  }

  final CustomerRepository customerRepository;
  final CustomerController customerController;
  final RealtimeRepository realtimeRepository;
  final CartCubit cartCubit;
  final AddressCubit addressCubit;
  final OrdersCubit ordersCubit;

  void _syncCustomerFromController() {
    if (customerController.value != state.customer) {
      emit(state.copyWith(customer: customerController.value));
    }
  }

  @override
  Future<void> close() {
    customerController.removeListener(_syncCustomerFromController);
    return super.close();
  }

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
    AppLogger.d('🚀 [DEBUG_AUTH] checkInitialAuthStatus started', tag: 'AUTH');

    final initialCustomer = customerController.value;

    // No Web, sempre verificamos se acabamos de voltar de um redirect de login
    // APENAS se não houver um customer logado localmente
    if (kIsWeb && initialCustomer == null) {
      AppLogger.d('🚀 [DEBUG_AUTH] Web detected. Checking for redirect result...', tag: 'AUTH');
      await _handleRedirectResult();

      // Se _handleRedirectResult encontrou login, o controller terá sido atualizado e _processFirebaseUser chamado,
      // então nós abortamos aqui para não duplicar o fluxo abaixo.
      if (customerController.value != null) {
        return;
      }
    }

    if (initialCustomer != null) {
      try {
        try {
          await realtimeRepository.linkCustomerToSession(initialCustomer.id!);
        } catch (e) {
          // ✅ NÃO desloga se falhar o vínculo de sessão (pode ser apenas socket offline)
          // O RealtimeRepository tentará novamente ao conectar.
          AppLogger.w(
            '⚠️ [AuthCubit] Falha ao vincular sessão na inicialização (ignorado): $e',
            tag: 'AUTH',
          );
        }

        emit(
          state.copyWith(status: AuthStatus.success, customer: initialCustomer),
        );

        // ✅ CRITICAL FIX: Aguarda Socket estar pronto antes de fetchCart
        // Evita erro "Usuário não autenticado na sessão" quando Socket ainda não conectou
        if (realtimeRepository.isSocketReady) {
          cartCubit.fetchCart();
        } else {
          AppLogger.d(
            '⏳ [AuthCubit] Socket não está pronto. CartCubit irá auto-retry quando conectar.',
            tag: 'AUTH',
          );
          // CartCubit tem listener que tentará novamente quando Socket ficar pronto
        }

        try {
          await Future.wait([
            addressCubit.loadAddresses(initialCustomer.id!),
            ordersCubit.loadOrders(initialCustomer.id!),
          ]);
        } catch (e) {
          AppLogger.e('Falha ao carregar dados pós-login: $e', tag: 'AUTH');
        }
        await _processPendingCartItem();
      } catch (e) {
        AppLogger.e('❌ [AuthCubit] Erro catastrófico na inicialização: $e', tag: 'AUTH');
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> signInWithGoogle() async {
    AppLogger.d('🎯 [DEBUG_AUTH] BOTÃO GOOGLE CLICADO!', tag: 'AUTH');
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
        AppLogger.d('🌐 [DEBUG_AUTH] Abrindo POPUP de login Google (Modo Original)', tag: 'AUTH');
        final userCredential = await auth.signInWithPopup(authProvider);
        AppLogger.i('✅ [DEBUG_AUTH] Popup concluído com sucesso', tag: 'AUTH');
        await _processUserCredential(userCredential);
      } else {
        AppLogger.d('📱 [DEBUG_AUTH] Usando fluxo mobile de login Google', tag: 'AUTH');
        final userCredential = await auth.signInWithPopup(authProvider);
        await _processUserCredential(userCredential);
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.e('❌ [DEBUG_AUTH] ERRO Firebase Auth: ${e.code}', error: e, tag: 'AUTH');
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Erro no login: ${e.message}',
        ),
      );
    } catch (e) {
      AppLogger.e('❌ [DEBUG_AUTH] ERRO Inesperado: $e', error: e, tag: 'AUTH');
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
        AppLogger.i(
          '✅ [DEBUG_AUTH] Redirect Result encontrado para: ${userCredential.user?.email}',
          tag: 'AUTH',
        );
        await _processUserCredential(userCredential);
        return;
      }

      // ✅ 2. Backup: Se não veio no redirect, talvez o Firebase já tenha logado em background
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        AppLogger.i(
          '👤 [DEBUG_AUTH] Usuário já persistido encontrado: ${currentUser.email}',
          tag: 'AUTH',
        );
        // Criamos um UserCredential fake ou apenas processamos o user
        // Como _processUserCredential usa UserCredential, vamos criar um mock
        // Mas o mais seguro é chamar o repositório direto com o currentUser
        await _processFirebaseUser(currentUser);
        return;
      }

      AppLogger.d(
        'ℹ️ [DEBUG_AUTH] Nenhum resultado de redirect ou usuário logado após 3 tentativas.',
        tag: 'AUTH',
      );
    } catch (e) {
      AppLogger.e('❌ [DEBUG_AUTH] Erro ao processar resultado do redirect: $e', error: e, tag: 'AUTH');
    }
  }

  Future<void> _processUserCredential(UserCredential userCredential) async {
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return;
    await _processFirebaseUser(firebaseUser);
  }

  Future<void> _processFirebaseUser(User firebaseUser) async {
    emit(state.copyWith(status: AuthStatus.loading));
    AppLogger.d(
      '🚀 [DEBUG_AUTH] Calling processGoogleSignInCustomer for: ${firebaseUser.email}',
      tag: 'AUTH',
    );

    try {
      final customerResult = await customerRepository
          .processGoogleSignInCustomer(firebaseUser: firebaseUser)
          .timeout(const Duration(seconds: 15));

      AppLogger.d(
        '🚀 [DEBUG_AUTH] processGoogleSignInCustomer result: ${customerResult.isRight ? "SUCCESS" : "ERROR"}',
        tag: 'AUTH',
      );

      customerResult.fold(
        (errorMessage) {
          AppLogger.e('🚀 [DEBUG_AUTH] Error message from backend: $errorMessage', tag: 'AUTH');
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
            AppLogger.d(
              '🚀 [DEBUG_AUTH] Finalizing login for customer: ${customer.id}',
              tag: 'AUTH',
            );

            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(
              state.copyWith(status: AuthStatus.success, customer: customer),
            );
            cartCubit.fetchCart();

            // ✅ CORREÇÃO: Limpa endereços ANTES de carregar novos dados
            addressCubit.clearAddresses();

            if (loginResponse.addresses.isNotEmpty) {
              addressCubit.setAddressesFromLogin(loginResponse.addresses);
            } else {
              addressCubit.loadAddresses(customer.id!);
            }

            if (loginResponse.orders.isNotEmpty) {
              AppLogger.i(
                '📦 [AUTH] Login retornou ${loginResponse.orders.length} pedidos',
                tag: 'AUTH',
              );
              for (var order in loginResponse.orders.take(1)) {
                AppLogger.d('📦 [AUTH] Pedido ${order.id} - ${order.shortId}', tag: 'AUTH');
              }
              ordersCubit.setOrdersFromLogin(loginResponse.orders);
            } else {
              ordersCubit.loadOrders(customer.id!);
            }

            await _processPendingCartItem();
            AppLogger.s('🎉 [DEBUG_AUTH] AUTH SUCCESSFUL!', tag: 'AUTH');
          } catch (e) {
            AppLogger.e('❌ [DEBUG_AUTH] Error linking session: $e', error: e, tag: 'AUTH');
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
      AppLogger.e('❌ [DEBUG_AUTH] Timeout ou Erro na API: $e', error: e, tag: 'AUTH');
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
        AppLogger.e('Não foi possível obter os dados do usuário.', tag: 'AUTH');
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

            // ✅ CORREÇÃO: Limpa endereços ANTES de carregar novos dados
            addressCubit.clearAddresses();

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
          AppLogger.e('Erro ao processar cliente pós-signup: $errorMessage', tag: 'AUTH');
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

            // ✅ CORREÇÃO: Limpa endereços ANTES de carregar novos dados
            addressCubit.clearAddresses();

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

    try {
      await getIt<AuthRepository>().logoutCustomer();
    } catch (e) {
      AppLogger.d('⚠️ Erro ao limpar tokens do customer: $e');
    }

    try {
      await PendingCartService.clearPendingCartItem();
    } catch (e) {
      AppLogger.d('⚠️ Erro ao limpar payload pendente: $e');
    }

    customerController.clearCustomer();
    realtimeRepository
        .clearCustomer(); // ✅ NOVO: Limpa ID vinculado no repositório
    cartCubit.resetCartLocally();
    addressCubit.clearAddresses();
    getIt<DeliveryFeeCubit>().reset();
    ordersCubit.clearOrders(); // ✅ NOVO: Limpa pedidos
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
