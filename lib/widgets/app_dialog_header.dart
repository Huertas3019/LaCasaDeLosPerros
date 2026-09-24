import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppDialogHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const AppDialogHeader({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
