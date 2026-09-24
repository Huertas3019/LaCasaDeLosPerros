import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Contenedor de Diálogo Modal Genérico para Operaciones CRUD (Agregar / Editar / Eliminar)
class AppCrudDialog extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget contenido;
  final VoidCallback onGuardar;
  final String textoGuardar;
  final VoidCallback? onEliminar;
  final String textoEliminar;
  final double maxWidth;
  final List<Widget>? accionesExtra;

  const AppCrudDialog({
    super.key,
    required this.titulo,
    required this.icono,
    required this.contenido,
    required this.onGuardar,
    this.textoGuardar = 'Guardar',
    this.onEliminar,
    this.textoEliminar = 'Eliminar Ítem',
    this.maxWidth = 700,
    this.accionesExtra,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Icon(icono, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          if (onEliminar != null) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(textoEliminar, style: const TextStyle(fontSize: 12)),
              onPressed: onEliminar,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: maxWidth,
        child: SingleChildScrollView(
          child: contenido,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        if (accionesExtra != null) ...accionesExtra!,
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.save, size: 18),
          label: Text(textoGuardar, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: onGuardar,
        ),
      ],
    );
  }
}
