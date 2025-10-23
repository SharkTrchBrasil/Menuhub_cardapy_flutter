import 'package:flutter/material.dart';

class DsResponsiveGrid extends StatelessWidget {
  const DsResponsiveGrid({
    super.key,
    required this.children,
    required this.itemMaxWidth,
    required this.itemSpacing,
    required this.padding,
  });

  final List<Widget> children;
  final double itemMaxWidth;
  final double itemSpacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: LayoutBuilder(builder: (_, constraints) {
        final screenWidth = constraints.maxWidth;
        final itemCount = ((screenWidth + itemSpacing) / (itemMaxWidth + itemSpacing)).ceil();
        final itemWidth = (screenWidth + itemSpacing - itemSpacing * itemCount)/itemCount;

        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: itemSpacing,
            runSpacing: itemSpacing,
            children: [
              for (final child in children)
                SizedBox(
                  width: itemWidth,
                  child: child,
                ),
            ],
          ),
        );
      }),
    );
  }
}


























