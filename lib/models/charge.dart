class Charge {

  Charge({required this.copyKey, required this.expiresAt});

  final String copyKey;
  final DateTime expiresAt;

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      copyKey: json['copy_key'],
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }

}