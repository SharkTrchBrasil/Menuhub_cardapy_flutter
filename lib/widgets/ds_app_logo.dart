import 'package:flutter/material.dart';

class DsAppLogo extends StatelessWidget {
  const DsAppLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w300,
          color: Colors.black,
        ),
        children: const [
          TextSpan(
            text: 'Totem',
          ),
          TextSpan(
            text: 'PRO',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}