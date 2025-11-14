// lib/pages/profile/profile_state.dart
part of 'profile_cubit.dart';

enum ProfileStatus { initial, loading, success, error, unauthenticated }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.customer,
    this.orders = const [],
    this.isUpdating = false,
    this.errorMessage,
    this.filteredOrderStatus,
    this.searchQuery = '',
  });

  final ProfileStatus status;
  final Customer? customer;
  final List<Order> orders;
  final bool isUpdating;
  final String? errorMessage;
  final String? filteredOrderStatus;
  final String searchQuery;

  List<Order> get filteredOrders {
    var filtered = orders;

    // Filtro por status
    if (filteredOrderStatus != null && filteredOrderStatus!.isNotEmpty) {
      filtered = filtered.where((o) => o.orderStatus == filteredOrderStatus).toList();
    }

    // Filtro por busca
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        return o.publicId.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  ProfileState copyWith({
    ProfileStatus? status,
    Customer? customer,
    List<Order>? orders,
    bool? isUpdating,
    String? errorMessage,
    String? Function()? filteredOrderStatus,
    String? Function()? searchQuery,
  }) {
    return ProfileState(
      status: status ?? this.status,
      customer: customer ?? this.customer,
      orders: orders ?? this.orders,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: errorMessage ?? this.errorMessage,
      filteredOrderStatus: filteredOrderStatus != null
          ? filteredOrderStatus()
          : this.filteredOrderStatus,
      searchQuery: searchQuery != null ? (searchQuery() ?? '') : this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
    status,
    customer,
    orders,
    isUpdating,
    errorMessage,
    filteredOrderStatus,
    searchQuery,
  ];
}