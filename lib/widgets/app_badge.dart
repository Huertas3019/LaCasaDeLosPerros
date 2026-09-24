import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Insignia / Badge reutilizable para categorías, tipos de producto o alertas de stock
class AppBadge extends StatelessWidget {
  final String texto;
  final Color colorBase;
  final IconData? icono;
  final double fontSize;

  const AppBadge({
    super.key,
    required this.texto,
    this.colorBase = AppColors.primary,
    this.icono,
    this.fontSize = 11,
  });

  /// Factory helper para badge de Insumo Cocina
  factory AppBadge.insumo({double fontSize = 11}) {
    return AppBadge(
      texto: '🥩 Insumo',
      colorBase: Colors.orangeAccent,
      fontSize: fontSize,
    );
  }

  /// Factory helper para badge de Producto Vendible / Bebida
  factory AppBadge.producto({double fontSize = 11}) {
    return AppBadge(
      texto: '🥤 Prod',
      colorBase: Colors.lightBlueAccent,
      fontSize: fontSize,
    );
  }

  /// Factory helper para badge de Combo
  factory AppBadge.combo({double fontSize = 11}) {
    return AppBadge(
      texto: '🍔 Combo',
      colorBase: AppColors.primary,
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorBase.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorBase.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: fontSize + 1, color: colorBase),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: colorBase,
            ),
          ),
        ],
      ),
    );
  }
}
