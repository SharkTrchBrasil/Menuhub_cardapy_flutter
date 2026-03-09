import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/typography.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final buttonChild = SizedBox(
      width: isMobile ? MediaQuery.of(context).size.width : 200,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 28 : 8.0),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  fixedSize: const Size.fromHeight(40),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: Typographyy.bodyLargeSemiBold.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return buttonChild;
    }

    return Focus(
      onKey: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          onPressed?.call(); // Aciona o botão ao pressionar Enter
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: buttonChild,
    );
  }
}
