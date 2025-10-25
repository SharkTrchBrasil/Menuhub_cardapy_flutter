import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/repositories/customer_repository.dart';

import '../pages/address/cubits/address_cubit.dart';
import '../pages/cart/cart_cubit.dart';
import '../repositories/realtime_repository.dart';

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

  Future<void> checkInitialAuthStatus() async {
    // ... (este método não precisa de prints por agora)
    final initialCustomer = customerController.value;
    if (initialCustomer != null) {
      try {
        await realtimeRepository.linkCustomerToSession(initialCustomer.id!);
        emit(state.copyWith(status: AuthStatus.success, customer: initialCustomer));
        cartCubit.fetchCart();
        addressCubit.loadAddresses(initialCustomer.id!);
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
      final auth = FirebaseAuth.instance;
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
          print("✅ [AuthCubit] 6. Cliente criado/obtido no backend: ${customer.name}. Vinculando sessão...");
          try {
            await realtimeRepository.linkCustomerToSession(customer.id!);
            print("✅ [AuthCubit] 7. Sessão vinculada. Emitindo estado de SUCESSO.");
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            cartCubit.fetchCart();
            addressCubit.loadAddresses(customer.id!);
          } catch (e) {
            print("❌ [AuthCubit] ERRO ao vincular sessão: $e");
            emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Erro ao vincular sessão ao carrinho.'));
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

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    customerController.clearCustomer();
    cartCubit.clearCart();
  //  addressCubit.clearAddresses();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}