import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:totem/core/extensions.dart';
import 'package:totem/models/option_item.dart';

class SizeItemGrid extends StatelessWidget {
  final OptionItem size;
  final int minPrice;
  final VoidCallback onTap;

  const SizeItemGrid({
    super.key,
    required this.size,
    required this.minPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = size.image?.url;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          size.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (size.slices != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${size.slices} Pedaços',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'A partir de ${minPrice.toCurrency}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Always show image block (placeholder if null)
              const SizedBox(width: 16),
              _buildImage(imageUrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: SizedBox(
        width: 96,
        height: 96,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.local_pizza,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

class SizeGridList extends StatelessWidget {
  final List<OptionItem> sizes;
  final Map<int, int> minPrices; // Map sizeId -> minPrice
  final Function(OptionItem) onSizeTap;

  const SizeGridList({
    super.key,
    required this.sizes,
    required this.minPrices,
    required this.onSizeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: 130,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final size = sizes[index];
          final price = minPrices[size.id] ?? 0;
          return SizeItemGrid(
            size: size,
            minPrice: price,
            onTap: () => onSizeTap(size),
          );
        },
        childCount: sizes.length,
      ),
    );
  }
}
