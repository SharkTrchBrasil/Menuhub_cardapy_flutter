// Em: lib/cubits/auth/auth_state.dart
part of 'auth_cubit.dart';

// Enum para representar os diferentes status do processo de autenticação
enum AuthStatus { initial, loading, success, error, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.customer,
    this.errorMessage,
  });

  final AuthStatus status;
  final Customer? customer;
  final String? errorMessage;

  // Atalho para saber se o usuário está logado
  bool get isLoggedIn => customer != null;

  AuthState copyWith({
    AuthStatus? status,
    Customer? customer,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      // Se o status for 'unauthenticated', limpa o customer
      customer: status == AuthStatus.unauthenticated ? null : customer ?? this.customer,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, customer, errorMessage];
}