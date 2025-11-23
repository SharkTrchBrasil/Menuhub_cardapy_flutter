import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../models/coupon.dart';
import '../../../repositories/coupon_repository.dart';
import '../../../themes/ds_theme_switcher.dart';
import '../cart_cubit.dart';

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
              const Expanded(
                child: Text(
                  'Cupom',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Adicionar',
                style: TextStyle(color: theme.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ CUPOM APLICADO COM PREVIEW
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com código e botão remover
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: theme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  couponCode!.toUpperCase(),
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: theme.primaryColor),
                onPressed: () => context.read<CartCubit>().removeCoupon(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // ✅ PREVIEW DO DESCONTO
          if (discountPreview != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Frete grátis (se aplicável)
            if (discountPreview!.hasFreeDelivery) ...[
              Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '🎉 FRETE GRÁTIS',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '- R\$ ${discountPreview!.deliveryDiscountReais.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Desconto no produto
            if (discountPreview!.discountAmount > 0) ...[
              Row(
                children: [
                  Icon(
                    Icons.discount,
                    color: theme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Desconto',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '- R\$ ${discountPreview!.discountAmountReais.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Total economizado
            if (discountPreview!.totalDiscount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Você economizou R\$ ${discountPreview!.totalDiscountReais.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
