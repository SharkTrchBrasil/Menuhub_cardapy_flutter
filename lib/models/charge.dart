import 'package:totem/core/helpers/money_amount_helper.dart';

class Charge {
  Charge({
    this.copyKey,
    this.expiresAt,
    this.amount,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.serviceFee = 0,
    this.discount = 0,
    this.grandTotal = 0,
  });

  final String? copyKey;
  final DateTime? expiresAt;
  final int? amount; // Valor em centavos (deprecated - usar grandTotal)

  // ✅ NOVOS CAMPOS para resumo de valores
  final int subtotal; // Subtotal dos itens em centavos
  final int deliveryFee; // Taxa de entrega em centavos
  final int serviceFee; // Taxa de serviço em centavos
  final int discount; // Desconto em centavos
  final int grandTotal; // Total final em centavos

  factory Charge.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Usa parseMoneyAmount para lidar com MoneyAmount maps e nums
    final subtotal =
        parseMoneyAmount(json['subtotal']) ??
        parseMoneyAmount(json['amount']) ??
        0;

    final deliveryFee = parseMoneyAmount(json['delivery_fee']) ?? 0;
    final serviceFee = parseMoneyAmount(json['service_fee']) ?? 0;
    final discount = parseMoneyAmount(json['discount']) ?? 0;

    final grandTotal =
        parseMoneyAmount(json['grand_total']) ??
        parseMoneyAmount(json['total']) ??
        (subtotal + deliveryFee + serviceFee - discount);

    return Charge(
      copyKey: json['copy_key'] as String?,
      expiresAt:
          json['expires_at'] != null
              ? DateTime.tryParse(json['expires_at'].toString())
              : null,
      amount: parseMoneyAmount(json['amount']),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      serviceFee: serviceFee,
      discount: discount,
      grandTotal: grandTotal,
    );
  }
}
