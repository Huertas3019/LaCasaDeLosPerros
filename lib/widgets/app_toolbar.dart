import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Barra de herramientas superior genérica para listados (Inventario, Gastos, Caja, etc.)
class AppToolbar extends StatelessWidget {
  final String? tituloContador;
  final int? cantidadRegistros;
  final VoidCallback onActualizar;
  final String? textoBotonNuevo;
  final VoidCallback? onNuevo;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget>? accionesAdicionales;

  const AppToolbar({
    super.key,
    this.tituloContador,
    this.cantidadRegistros,
    required this.onActualizar,
    this.textoBotonNuevo,
    this.onNuevo,
    this.searchController,
    this.onSearchChanged,
    this.accionesAdicionales,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Contador de Registros
          if (tituloContador != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text(
                    tituloContador!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (cantidadRegistros != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$cantidadRegistros',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Buscador rápido integrado (si se especifica)
          if (onSearchChanged != null || searchController != null) ...[
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else
            const Spacer(),

          // Acciones adicionales pasadas como widgets
          if (accionesAdicionales != null) ...[
            ...accionesAdicionales!,
            const SizedBox(width: 8),
          ],

          // Botón de Actualizar
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            tooltip: 'Actualizar Lista',
            onPressed: onActualizar,
          ),

          // Botón de Agregar Nuevo
          if (textoBotonNuevo != null && onNuevo != null) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                textoBotonNuevo!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: onNuevo,
            ),
          ],
        ],
      ),
    );
  }
}
