import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/store_cubit.dart';
import 'package:totem/cubit/store_state.dart';
import 'package:totem/core/extensions.dart';
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

        // Filtra apenas cupons ativos
        final activeCoupons = coupons.where((c) => c.isActive).toList();

        if (activeCoupons.isEmpty) {
          return const SizedBox.shrink();
        }

        // Altura ajustada para o card com corte horizontal
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
      width: 150, // Largura suficiente para o conteúdo lateral
      child: CouponCard(
        height: 70,
        backgroundColor: Colors.white,
        curveAxis: Axis.horizontal, // Corte horizontal
        curvePosition: 80, // Corte próximo ao fundo (separando o footer)
        curveRadius: 8,
        borderRadius: 12,
        border: BorderSide(
          color: Colors.grey.shade200,
          width: 0.8,
        ),
        firstChild: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícone Circular
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_activity, // Ícone de ticket
                  color: Colors.green.shade700,
                  size: 20,
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
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      discountValue,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              fontSize: 11,
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

  // Texto completo de pedido mínimo para o rodapé
  String _getMinOrderText(Coupon coupon) {
     if (coupon.minOrderValue != null && coupon.minOrderValue! > 0) {
      final valueInReais = coupon.minOrderValue! / 100;
      return 'Mínimo R\$ ${valueInReais.toStringAsFixed(0)}';
    }
    return '';
  }

  String _getDiscountDisplayValue(Coupon coupon) {
    if (coupon.discountType == 'PERCENTAGE') {
      return '${coupon.discountValue.toInt()}%';
    } else if (coupon.discountType == 'FIXED_AMOUNT') {
      // discountValue vem em centavos, converte para reais
      final valueInReais = coupon.discountValue / 100;
      return 'R\$ ${valueInReais.toStringAsFixed(0)}';
    } else if (coupon.discountType == 'FREE_DELIVERY') {
      return 'FRETE GRÁTIS';
    }
    return 'R\$ 0';
  }
}