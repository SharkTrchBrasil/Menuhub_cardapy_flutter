class Rating {
  final int id;
  final int stars;
  final String? comment;
  final String? customerName;
  final DateTime? createdAt;
  final String? ownerReply;
   final String? createdSince;

  Rating(  {
    required this.id,
    required this.stars,
    this.comment,
    this.customerName,
    this.createdAt,
    this.ownerReply,
    this.createdSince,
  });

  factory Rating.fromMap(Map<String, dynamic> map) {
    return Rating(
      id: map['id'],
      stars: map['stars'],
      ownerReply: map['owner_reply'],
      comment: map['comment'],
      customerName: map['customer_name'],
      createdSince: map['created_since'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stars': stars,
      'comment': comment,
      'owner_reply': ownerReply,
      'customer_name': customerName,
       'created_since': createdSince,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
