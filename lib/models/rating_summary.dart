import 'package:totem/models/rating.dart';

class RatingsSummary {
  final double averageRating;
  final int totalRatings;
  final Map<int, int> distribution;
  final List<Rating> ratings;

  RatingsSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.distribution,
    required this.ratings,
  });

  factory RatingsSummary.fromMap(Map<String, dynamic> map) {
    return RatingsSummary(
      averageRating: (map['average_rating'] ?? 0).toDouble(),
      totalRatings: map['total_ratings'] ?? 0,
      distribution: Map<int, int>.from(
        (map['distribution'] as Map).map(
              (key, value) => MapEntry(int.parse(key), value as int),
        ),
      ),
      ratings: List<Rating>.from(
        (map['ratings'] as List).map((r) => Rating.fromMap(r as Map<String, dynamic>)),
      ),
    );
  }

  // --- Método toMap() ---
  Map<String, dynamic> toMap() {
    return {
      'average_rating': averageRating,
      'total_ratings': totalRatings,
      'distribution': distribution.map(
        // Converta a chave int de volta para String para o JSON
            (key, value) => MapEntry(key.toString(), value),
      ),
      'ratings': ratings.map((r) => r.toMap()).toList(), // Chama toMap() em cada Rating
    };
  }
}