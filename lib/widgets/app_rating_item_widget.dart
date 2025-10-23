import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nb_utils/nb_utils.dart';

import '../models/rating.dart';
import '../themes/ds_theme_switcher.dart';

class AppRatingItemWidget extends StatelessWidget {
  final Rating rating;

  const AppRatingItemWidget({
    super.key,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final theme1 = context.watch<DsThemeSwitcher>().theme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme1.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: defaultBoxShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome do cliente
          Text(
            rating.customerName ?? 'Cliente',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          8.height,

          // Estrelas + dias
          Row(
            children: [
              RatingBarWidget(
                size: 16,
                rating: rating.stars.toDouble(),
                onRatingChanged: (_) {},
                activeColor: theme1.primaryColor,
                disable: true,
              ),
              8.width,
              Text(
                rating.createdSince ?? '',
               style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),

            ],
          ),

          12.height,

          // Comentário do cliente
          if (rating.comment?.isNotEmpty ?? false)
            Text(
              rating.comment!,
              style: theme.textTheme.bodyMedium,
            ),

          // Resposta do dono da loja
          if (rating.ownerReply?.isNotEmpty ?? false) ...[
            16.height,
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resposta da loja',

                  ),
                  4.height,
                  Text(
                    rating.ownerReply!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
