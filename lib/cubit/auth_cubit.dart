import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/repositories/customer_repository.dart';

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
  }) : super(const AuthState());

  final CustomerRepository customerRepository;
  final CustomerController customerController;
  final RealtimeRepository realtimeRepository;
  final CartCubit cartCubit;
  final AddressCubit addressCubit;

  /// ✅ Método auxiliar para processar payload pendente após login bem-sucedido
  Future<void> _processPendingCartItem() async {
    final pendingPayload = await PendingCartService.getPendingCartItem();
    if (pendingPayload != null) {
      print('🛒 Processando item pendente após login: ${pendingPayload.productId}');
      try {
        await cartCubit.updateItem(pendingPayload);
        await PendingCartService.clearPendingCartItem();
        print('✅ Item pendente adicionado ao carrinho com sucesso');
      } catch (e) {
        print('❌ Erro ao adicionar item pendente: $e');
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
    print("🕵️‍♂️ [AuthCubit] 1. signInWithGoogle INICIADO.");

    try {
      // ✅ Verifica se Firebase está inicializado
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        print("❌ [AuthCubit] Firebase não está inicializado!");
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Firebase não está configurado. Por favor, reinicie o aplicativo.'));
        return;
      }
      
      print("🔥 [AuthCubit] Firebase apps: ${apps.length}");
      print("🔥 [AuthCubit] Firebase project: ${apps.first.options.projectId}");
      print("🔥 [AuthCubit] Firebase API key: ${apps.first.options.apiKey.substring(0, 10)}...");
      
      final auth = FirebaseAuth.instanceFor(app: apps.first);
      final authProvider = GoogleAuthProvider();

      print("🕵️‍♂️ [AuthCubit] 2. Prestes a chamar signInWithPopup. O popup deve abrir AGORA.");
      final userCredential = await auth.signInWithPopup(authProvider);
      print("🕵️‍♂️ [AuthCubit] 3. signInWithPopup CONCLUÍDO com sucesso! O popup fechou porque o login funcionou.");

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        print("❌ [AuthCubit] ERRO: userCredential.user é nulo após o login.");
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Não foi possível obter os dados do usuário.'));
        return;
      }

      print("🕵️‍♂️ [AuthCubit] 4. Usuário do Firebase obtido: ${firebaseUser.displayName}. Emitindo estado de LOADING.");
      emit(state.copyWith(status: AuthStatus.loading));

      final customerResult = await customerRepository.processGoogleSignInCustomer(firebaseUser: firebaseUser);
      print("🕵️‍♂️ [AuthCubit] 5. processGoogleSignInCustomer CONCLUÍDO.");

      customerResult.fold(
            (errorMessage) {
          print("❌ [AuthCubit] ERRO no processGoogleSignInCustomer: $errorMessage");
          emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
        },
        (customer) async {
          try {
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            addressCubit.loadAddresses(customer.id!);
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
        print("⚠️ [AuthCubit] ERRO CAPTURADO: O popup foi fechado (pelo usuário ou pelo sistema). Código: ${e.code}");
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      } else {
        print("❌ [AuthCubit] ERRO FIREBASE não esperado: ${e.code} - ${e.message}");
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Ocorreu um erro no login. Tente novamente.'));
      }
    } catch (e) {
      print("❌ [AuthCubit] ERRO GENÉRICO não esperado: $e");
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
        (customer) async {
          try {
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            addressCubit.loadAddresses(customer.id!);
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
        (customer) async {
          try {
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            addressCubit.loadAddresses(customer.id!);
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
      print('⚠️ Erro ao fazer logout do Firebase: $e');
    }
    customerController.clearCustomer();
    cartCubit.clearCart();
  //  addressCubit.clearAddresses();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}