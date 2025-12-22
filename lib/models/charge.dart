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
  final int subtotal;     // Subtotal dos itens em centavos
  final int deliveryFee;  // Taxa de entrega em centavos
  final int serviceFee;   // Taxa de serviço em centavos
  final int discount;     // Desconto em centavos
  final int grandTotal;   // Total final em centavos

  factory Charge.fromJson(Map<String, dynamic> json) {
    // Calcula valores
    final subtotal = json['subtotal'] != null 
        ? (json['subtotal'] as num).toInt() 
        : json['amount'] != null 
            ? (json['amount'] as num).toInt() 
            : 0;
    
    final deliveryFee = json['delivery_fee'] != null 
        ? (json['delivery_fee'] as num).toInt() 
        : 0;
    
    final serviceFee = json['service_fee'] != null 
        ? (json['service_fee'] as num).toInt() 
        : 0;
    
    final discount = json['discount'] != null 
        ? (json['discount'] as num).toInt() 
        : 0;
    
    final grandTotal = json['grand_total'] != null 
        ? (json['grand_total'] as num).toInt() 
        : json['total'] != null
            ? (json['total'] as num).toInt()
            : subtotal + deliveryFee + serviceFee - discount;
    
    return Charge(
      copyKey: json['copy_key'] as String?,
      expiresAt: json['expires_at'] != null 
          ? DateTime.tryParse(json['expires_at']) 
          : null,
      amount: json['amount'] != null ? (json['amount'] as num).toInt() : null,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      serviceFee: serviceFee,
      discount: discount,
      grandTotal: grandTotal,
    );
  }

}