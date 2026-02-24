import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/core/extensions.dart'; // Importa a extensão centralizada
import 'package:coupon_uikit/coupon_uikit.dart';

import '../../../models/coupon.dart';

class CouponListWidget extends StatelessWidget {
  const CouponListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoreCubit, StoreState>(
      builder: (context, state) {
        final coupons = state.store?.coupons ?? [];

        // Se não tiver cupons, não mostra nada
        if (coupons.isEmpty) {
          return const SizedBox.shrink();
        }

        // Filtra cupons ativos e listados (para não mostrar cupons de influencer ocultos por exemplo)
        final activeCoupons = coupons.where((c) => c.isActive && (c.isListed ?? true)).toList();

        if (activeCoupons.isEmpty) {
          return const SizedBox.shrink();
        }

        // Altura ajustada
        return SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: activeCoupons.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final coupon = activeCoupons[index];
              return _buildCouponCard(coupon, context);
            },
          ),
        );
      },
    );
  }

  Widget _buildCouponCard(Coupon coupon, BuildContext context) {
    final discountValue = _getDiscountDisplayValue(coupon);
    final minOrderText = _getMinOrderText(coupon);

    return SizedBox(
      width: 160,
      child: CouponCard(
        height: 70,
        backgroundColor: Colors.white,
        curveAxis: Axis.horizontal,
        curvePosition: 80,
        curveRadius: 8,
        borderRadius: 12,
        border: BorderSide(
          color: Colors.grey.shade200,
          width: 0.8,
        ),
        firstChild: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone Circular (Ticket)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_activity,
                  color: Colors.green.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              // Textos: "Cupom de" e Valor
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cupom de',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Valor com escala para não cortar se for grande
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        discountValue,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        secondChild: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            minOrderText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _getMinOrderText(Coupon coupon) {
     if (coupon.minOrderValue != null && coupon.minOrderValue! > 0) {
      // Usa .toCurrency do extensions.dart (divide por 100 automaticamente)
      return 'Mínimo ${coupon.minOrderValue!.toCurrency}';
    }
    return 'Sem mínimo';
  }

  String _getDiscountDisplayValue(Coupon coupon) {
    if (coupon.discountType == 'PERCENTAGE') {
      return '${coupon.discountValue.toInt()}%';
    } else if (coupon.discountType == 'FIXED_AMOUNT') {
      // Usa .toCurrency do extensions.dart (divide por 100 automaticamente)
      return coupon.discountValue.toInt().toCurrency;
    } else if (coupon.discountType == 'FREE_DELIVERY') {
      return 'FRETE GRÁTIS';
    }
    return '';
  }
}