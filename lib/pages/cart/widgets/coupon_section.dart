import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../models/coupon.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../cart_cubit.dart';

class CouponSection extends StatelessWidget {
  final String? couponCode;

  const CouponSection({required this.couponCode, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    if (couponCode == null) {
      return InkWell(
        onTap: () => context.go('/add-coupon'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: theme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(child: Text('Cupom', style: TextStyle(fontWeight: FontWeight.w600))),
              Text('Adicionar', style: TextStyle(color: theme.primaryColor)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cupom aplicado: ${couponCode}',
              style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.primaryColor),
            onPressed: () => context.read<CartCubit>().removeCoupon(),
          ),
        ],
      ),
    );
  }
}
