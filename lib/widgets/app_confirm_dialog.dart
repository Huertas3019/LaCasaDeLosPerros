import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Diálogo reutilizable estandarizado para confirmaciones (ej. Eliminar elementos)
class AppConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final String textoCancelar;
  final IconData icono;
  final Color colorIcono;
  final bool esPeligroso;

  const AppConfirmDialog({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.textoConfirmar = 'Eliminar',
    this.textoCancelar = 'Cancelar',
    this.icono = Icons.warning_amber_rounded,
    this.colorIcono = AppColors.secondary,
    this.esPeligroso = true,
  });

  /// Método estático de conveniencia para mostrar el diálogo fácilmente
  static Future<bool> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoConfirmar = 'Eliminar',
    String textoCancelar = 'Cancelar',
    IconData icono = Icons.warning_amber_rounded,
    Color colorIcono = AppColors.secondary,
    bool esPeligroso = true,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        titulo: titulo,
        mensaje: mensaje,
        textoConfirmar: textoConfirmar,
        textoCancelar: textoCancelar,
        icono: icono,
        colorIcono: colorIcono,
        esPeligroso: esPeligroso,
      ),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(icono, color: colorIcono, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        mensaje,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(textoCancelar, style: const TextStyle(color: Colors.white70)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: esPeligroso ? AppColors.secondary : AppColors.primary,
            foregroundColor: esPeligroso ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(esPeligroso ? Icons.delete_forever : Icons.check, size: 18),
          label: Text(textoConfirmar, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
