import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:totem/core/extensions.dart'; // Uso de extensions padronizado
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/models/coupon.dart';
import 'package:totem/repositories/coupon_repository.dart';
import 'package:totem/themes/ds_theme_switcher.dart';

/// Widget de cupom no carrinho - inspirado no design do Menuhub
class CouponSection extends StatelessWidget {
  final String? couponCode;
  final DiscountPreview? discountPreview;

  const CouponSection({
    required this.couponCode,
    this.discountPreview,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DsThemeSwitcher>().theme;

    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, storeState) {
        final availableCoupons = storeState.store?.coupons
                .where((c) => c.isActive)
                .toList() ??
            [];
        final availableCount = availableCoupons.length;

        if (couponCode == null) {
          return _buildNoCouponState(context, theme, availableCount);
        }

        return _buildAppliedCouponState(context, theme, couponCode!, discountPreview);
      },
    );
  }

  Widget _buildNoCouponState(BuildContext context, dynamic theme, int availableCount) {
    return InkWell(
      onTap: () => context.push('/add-coupon'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_offer, color: Colors.black87, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cupom',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (availableCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$availableCount pra usar nesta loja',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'Adicionar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedCouponState(BuildContext context, dynamic theme, String code, DiscountPreview? preview) {
    final storeState = context.read<StoreCubit>().state;
    final appliedCoupon = storeState.store?.coupons
        .where((c) => c.code.toUpperCase() == code.toUpperCase())
        .firstOrNull;

    String description = _getCouponDescription(appliedCoupon, preview);

    return InkWell(
      onTap: () => context.push('/add-coupon'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_offer, color: Colors.green.shade700, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cupom aplicado',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  String _getCouponDescription(Coupon? coupon, DiscountPreview? preview) {
    if (coupon == null) {
      return couponCode?.toUpperCase() ?? 'Cupom aplicado';
    }

    if (coupon.discountType == 'FREE_DELIVERY') {
      return 'Frete grátis.';
    } else if (coupon.discountType == 'PERCENTAGE') {
      return '${coupon.discountValue.toInt()}% de desconto.';
    } else if (coupon.discountType == 'FIXED_AMOUNT') {
      if (coupon.targetProductId != null) {
        return '${coupon.discountValue.toInt().toCurrency} em produto específico.';
      }
      return '${coupon.discountValue.toInt().toCurrency} pra restaurantes selecionados.';
    }

    return couponCode?.toUpperCase() ?? 'Cupom aplicado';
  }
}
