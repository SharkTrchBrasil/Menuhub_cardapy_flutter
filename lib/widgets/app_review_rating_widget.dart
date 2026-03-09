import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:rating_summary/rating_summary.dart';

import '../models/rating_summary.dart';
import '../themes/ds_theme_switcher.dart';

class AppReviewRatingWidget extends StatelessWidget {
  final RatingsSummary ratingsSummary;

  const AppReviewRatingWidget({super.key, required this.ratingsSummary});

  @override
  Widget build(BuildContext context) {
    final themeSwatch = context.watch<DsThemeSwitcher>().theme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Seção da Média (Esquerda)
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ratingsSummary.averageRating == 0
                      ? '0,0'
                      : ratingsSummary.averageRating
                          .toStringAsFixed(1)
                          .replaceAll('.', ','),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 42,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                RatingBarWidget(
                  size: 18,
                  onRatingChanged: (rating) {},
                  rating: ratingsSummary.averageRating,
                  activeColor: Colors.amber,
                  disable: true,
                ),
                const SizedBox(height: 8),
                Text(
                  '${ratingsSummary.totalRatings} ${ratingsSummary.totalRatings == 1 ? "avaliação" : "avaliações"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Divisor Vertical
            Container(
              height: 80,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: Colors.grey.shade100,
            ),

            // Seção das Barras (Direita)
            Expanded(
              child: RatingSummary(
                counter: ratingsSummary.totalRatings,
                average: ratingsSummary.averageRating,
                showAverage: false,
                counterFiveStars: ratingsSummary.distribution[5] ?? 0,
                counterFourStars: ratingsSummary.distribution[4] ?? 0,
                counterThreeStars: ratingsSummary.distribution[3] ?? 0,
                counterTwoStars: ratingsSummary.distribution[2] ?? 0,
                counterOneStars: ratingsSummary.distribution[1] ?? 0,
                color: themeSwatch.primaryColor, // Cor da barra ativa
                backgroundColor: Colors.grey.shade100, // Cor de fundo da barra
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
