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
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey ,
          width: 0.5 ,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [


                Text(
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                  ratingsSummary.averageRating == 0
                      ? '0'
                      : ratingsSummary.averageRating.toStringAsFixed(1),
                ),
                SizedBox(height: 8),
                RatingBarWidget(
                  size: 24,
                  onRatingChanged: (rating) {},
                  rating: ratingsSummary.averageRating,
                  activeColor: theme.primaryColor,
                  // Substitua por sua cor
                  disable: true,
                ),
                8.height,
                Text(
                  '(${ratingsSummary.totalRatings} avaliações)',
                  overflow: TextOverflow.ellipsis,
                  // style: theme.textTheme.bodyLarge?.copyWith(
                  //   color: Get.isDarkMode ? colorGrey300 : colorGrey800,
                  //   fontWeight: FontWeight.w500,
                  // ),
                ),
              ],
            ),
            20.width,
            Column(
              children: [Container(height: 100, width: 1, color: Colors.amber)],
            ),
            20.width,
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
                color: theme.primaryColor,
                backgroundColor: theme.backgroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
