import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/pages/profile/profile_cubit.dart';
import 'package:totem/cubit/auth_cubit.dart';
import 'package:totem/core/di.dart';
import 'package:totem/repositories/customer_repository.dart';
import 'package:totem/repositories/order_repository.dart';
import 'package:totem/pages/orders/widgets/orders_content.dart';

/// Mobile Orders Page
/// Implementação específica para dispositivos móveis
class MobileOrders extends StatelessWidget {
  const MobileOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ProfileCubit(
          customerRepository: getIt<CustomerRepository>(),
          orderRepository: getIt<OrderRepository>(),
        );
        final customer = context.read<AuthCubit>().state.customer;
        if (customer?.id != null) {
          cubit.loadOrderHistory(customer!.id!);
        }
        return cubit;
      },
      child: const OrdersContent(isDesktop: false),
    );
  }
}
