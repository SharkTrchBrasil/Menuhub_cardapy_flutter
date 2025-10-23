
class TotemAuth {
  TotemAuth({
    required this.id,
    required this.token,
    required this.name,
    required this.publicKey,
    required this.storeId,
    required this.granted,
    this.grantedById,
    this.sid,
    required this.storeUrl,

  });

  final int id;
  final String token; // Corresponde a 'totem_token'
  final String name; // Corresponde a 'totem_name'
  final String publicKey;
  final int storeId;
  final bool granted;
  final int? grantedById;
  final String? sid;
  final String storeUrl;


  factory TotemAuth.fromJson(Map<String, dynamic> json) {
    return TotemAuth(
      id: json['id'] as int,
      token: json['totem_token'] as String,
      name: json['totem_name'] as String,
      publicKey: json['public_key'] as String,
      storeId: json['store_id'] as int,
      granted: json['granted'] as bool,
      grantedById: json['granted_by_id'] as int?,
      sid: json['sid'] as String?,
      storeUrl: json['store_url'] as String,

    );
  }
}