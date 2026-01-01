import 'package:flutter/material.dart';

/// Profile Menu Item Widget
/// Widget reutilizável para itens de menu do perfil
class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;
  final bool showChevron; // ✅ Novo parâmetro

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
    this.showChevron = true, // ✅ Default true
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? Colors.grey.shade700,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor ?? Colors.grey.shade800,
                ),
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 24,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }
}
