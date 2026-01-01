import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Card flutuante de login - estilo iFood
/// Reutilizável em qualquer página que precise mostrar prompt de login
class LoginPromoCard extends StatelessWidget {
  final String? customTitle;
  final String? customSubtitle;
  
  const LoginPromoCard({
    super.key,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customTitle ?? 'Explore mais com sua conta MenuHub',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      context.push('/onboarding');
                    },
                    child: Text(
                      customSubtitle ?? 'Entrar ou cadastrar-se',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
