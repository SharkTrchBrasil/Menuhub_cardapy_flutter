// lib/pages/profile/profile_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:totem/models/customer.dart';
import 'package:totem/models/order.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/order_repository.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    required this.customerRepository,
    required this.orderRepository,
  }) : super(const ProfileState());

  final CustomerRepository customerRepository;
  final OrderRepository orderRepository;

  Future<void> loadProfile(Customer? customer) async {
    if (customer == null) {
      emit(state.copyWith(status: ProfileStatus.unauthenticated));
      return;
    }

    emit(state.copyWith(
      status: ProfileStatus.loading,
      customer: customer,
    ));

    await loadOrderHistory(customer.id!);
  }

  Future<void> updateProfile({
    required int customerId,
    String? name,
    String? phone,
    String? email,
  }) async {
    emit(state.copyWith(isUpdating: true));

    try {
      final result = await customerRepository.updateCustomerInfo(
        customerId,
        name ?? state.customer!.name,
        phone ?? state.customer!.phone ?? '',
        email: email ?? state.customer?.email,
      );

      if (result.isRight) {
        emit(state.copyWith(
          customer: result.right,
          isUpdating: false,
          status: ProfileStatus.success,
        ));
      } else {
        emit(state.copyWith(
          isUpdating: false,
          errorMessage: result.left,
          status: ProfileStatus.error,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isUpdating: false,
        errorMessage: e.toString(),
        status: ProfileStatus.error,
      ));
    }
  }

  Future<void> updateProfilePhoto(int customerId, XFile imageFile) async {
    emit(state.copyWith(isUpdating: true));

    try {
      final result = await customerRepository.uploadCustomerPhoto(
        customerId,
        imageFile,
      );

      if (result.isRight) {
        emit(state.copyWith(
          customer: result.right,
          isUpdating: false,
          status: ProfileStatus.success,
        ));
      } else {
        emit(state.copyWith(
          isUpdating: false,
          errorMessage: result.left,
          status: ProfileStatus.error,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isUpdating: false,
        errorMessage: e.toString(),
        status: ProfileStatus.error,
      ));
    }
  }

  Future<void> loadOrderHistory(int customerId) async {
    try {
      final result = await orderRepository.getCustomerOrders(customerId);
      if (result.isRight) {
        emit(state.copyWith(
          orders: result.right,
          status: ProfileStatus.success,
        ));
      }
    } catch (e) {
      print('Erro ao carregar histórico: $e');
    }
  }

  void filterOrdersByStatus(String? status) {
    emit(state.copyWith(
      filteredOrderStatus: () => status != null && status.isNotEmpty ? status : null,
    ));
  }

  void searchOrders(String query) {
    emit(state.copyWith(searchQuery: () => query.isNotEmpty ? query : ''));
  }
}

