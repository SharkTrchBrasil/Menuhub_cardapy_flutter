class Charge {

  Charge({
    required this.copyKey, 
    required this.expiresAt,
    this.amount,
  });

  final String copyKey;
  final DateTime expiresAt;
  final int? amount; // Valor em centavos

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      copyKey: json['copy_key'],
      expiresAt: DateTime.parse(json['expires_at']),
      amount: json['amount'] != null ? (json['amount'] as num).toInt() : null,
    );
  }

}