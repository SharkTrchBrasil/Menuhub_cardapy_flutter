import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../themes/ds_theme_switcher.dart';

class CartQuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final TextStyle? textStyle;

  const CartQuantityControl({
    super.key,
    required this.quantity,
    this.onRemove,
    this.onAdd,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = textStyle ??
        const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        );
    final theme = context.watch<DsThemeSwitcher>().theme;

    return Container(
    height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.remove, color: theme.primaryColor, size: 16),
            onPressed: quantity > 0 ? onRemove : null,
          ),
          const SizedBox(width: 4),
          Text(
            quantity.toString(),
            style: effectiveTextStyle.copyWith(color: theme.cartTextColor),
          ),
          const SizedBox(width: 4),
          IconButton(
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            icon: Icon(Icons.add, color: theme.primaryColor, size: 16),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
