import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/controllers/customer_controller.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/repositories/customer_repository.dart';

import '../pages/address/cubits/address_cubit.dart'; // ✅ 1. IMPORTE O ADDRESSCUBIT
import '../pages/cart/cart_cubit.dart';
import '../repositories/realtime_repository.dart';

part 'auth_state.dart';


class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.customerRepository,
    required this.customerController,
    required this.realtimeRepository,
    required this.cartCubit,
    required this.addressCubit, // ✅ 2. ADICIONE A DEPENDÊNCIA
  }) : super(const AuthState());

  final CustomerRepository customerRepository;
  final CustomerController customerController;
  final RealtimeRepository realtimeRepository;
  final CartCubit cartCubit;
  final AddressCubit addressCubit; // ✅ 2. ADICIONE A DEPENDÊNCIA

  Future<void> checkInitialAuthStatus() async {
    final initialCustomer = customerController.value;
    if (initialCustomer != null) {
      print("✅ AuthCubit: Cliente encontrado. Sincronizando sessão...");
      try {
        await realtimeRepository.linkCustomerToSession(initialCustomer.id!);
        emit(state.copyWith(status: AuthStatus.success, customer: initialCustomer));
        // ✅ 3. DISPARA O CARREGAMENTO DO CARRINHO E DOS ENDEREÇOS
        cartCubit.fetchCart();
        addressCubit.loadAddresses(initialCustomer.id!);
        print("✅ AuthCubit: Sessão, carrinho e endereços sincronizados.");
      } catch (e) {
        print("❌ AuthCubit: Erro ao sincronizar sessão: $e. Deslogando.");
        await signOut();
      }
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }


  Future<void> signInWithGoogle() async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final auth = FirebaseAuth.instance;
      final authProvider = GoogleAuthProvider();
      final userCredential = await auth.signInWithPopup(authProvider);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Login com Google cancelado.'));
        return;
      }

      final customerResult = await customerRepository.processGoogleSignInCustomer(firebaseUser: firebaseUser);

      customerResult.fold(
            (errorMessage) {
          emit(state.copyWith(status: AuthStatus.error, errorMessage: errorMessage));
        },
            (customer) async {
          try {
            await realtimeRepository.linkCustomerToSession(customer.id!);
            emit(state.copyWith(status: AuthStatus.success, customer: customer));
            // ✅ 3. DISPARA O CARREGAMENTO DO CARRINHO E DOS ENDEREÇOS
            cartCubit.fetchCart();
            addressCubit.loadAddresses(customer.id!);
          } catch (e) {
            emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Erro ao vincular sessão ao carrinho.'));
          }
        },
      );
    } catch (e) {
      debugPrint('Erro no signInWithGoogle: $e');
      emit(state.copyWith(status: AuthStatus.error, errorMessage: 'Ocorreu um erro inesperado. Tente novamente.'));
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    customerController.clearCustomer();
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }
}