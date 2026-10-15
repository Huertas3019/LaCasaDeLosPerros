import 'package:flutter/material.dart';
import '../../core/events/app_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ajuste_inventario.dart';
import '../../models/categoria.dart';
import '../../models/producto.dart';
import '../../models/receta.dart';
import '../../repositories/ajustes_inventario_repository.dart';
import '../../repositories/categorias_repository.dart';
import '../../repositories/productos_repository.dart';
import '../../repositories/recetas_repository.dart';
import '../../widgets/app_widgets.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductosRepository _productosRepo = ProductosRepository();
  final CategoriasRepository _categoriasRepo = CategoriasRepository();
  final RecetasRepository _recetasRepo = RecetasRepository();
  final AjustesInventarioRepository _ajustesRepo = AjustesInventarioRepository();

  List<Producto> _insumos = [];
  List<Producto> _productos = [];
  List<Producto> _combos = [];
  List<AjusteInventario> _historialAjustes = [];
  List<Producto> _todosLosProductos = [];
  List<Categoria> _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarDatos();
    AppNotifier.instance.addListener(_onAppEvent);
  }

  @override
  void dispose() {
    AppNotifier.instance.removeListener(_onAppEvent);
    _tabController.dispose();
    super.dispose();
  }

  void _onAppEvent() {
    final e = AppNotifier.instance.lastEventType;
    if (e == AppEventType.ventaRealizada || e == AppEventType.stockActualizado) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final todosProds = await _productosRepo.getProductos(soloActivos: true);
      final categorias = await _categoriasRepo.getCategorias();
      final ajustes = await _ajustesRepo.getTodosLosAjustes();

      setState(() {
        _todosLosProductos = todosProds;
        _insumos = todosProds.where((p) => p.esInsumo).toList();
        _productos = todosProds.where((p) => p.esProducto).toList();
        _combos = todosProds.where((p) => p.esCombo).toList();
        _historialAjustes = ajustes;
        _categorias = categorias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarYEliminarProducto(Producto item) async {
    final tipoNombre = item.esInsumo ? 'el insumo' : (item.esCombo ? 'el combo' : 'el producto');
    final bool confirmar = await AppConfirmDialog.mostrar(
      context,
      titulo: 'Eliminar ${item.nombreConPresentacion}',
      mensaje:
          '¿Estás seguro de eliminar $tipoNombre "${item.nombreConPresentacion}"? Si forma parte de recetas o combos, también se actualizará.',
      textoConfirmar: 'Eliminar',
    );

    if (!confirmar) return;

    try {
      await _productosRepo.deleteProducto(item.id!);
      AppNotifier.instance.notifyStockActualizado();
      await _cargarDatos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.nombreConPresentacion}" eliminado correctamente.'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  void _abrirModalAjusteInventario(Producto insumo) {
    final cantidadCtrl = TextEditingController(text: '1');
    final motivoCtrl = TextEditingController();

    String tipoAjuste = 'INGRESO_MANUAL';
    String unidadSeleccionada = (insumo.unidadCompra != null && insumo.unidadCompra!.isNotEmpty)
        ? insumo.unidadCompra!
        : insumo.unidadMedida;

    final unidadesDisponibles = <String>[
      insumo.unidadMedida,
      if (insumo.unidadCompra != null &&
          insumo.unidadCompra!.isNotEmpty &&
          insumo.unidadCompra != insumo.unidadMedida)
        insumo.unidadCompra!,
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cantIngresada = double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final bool esIngreso = tipoAjuste == 'INGRESO_MANUAL' || tipoAjuste == 'CORRECCION';

            final double factorUsado = (unidadSeleccionada == insumo.unidadCompra)
                ? insumo.factorConversion
                : 1.0;

            final double cantidadBase = cantIngresada * factorUsado;
            final double cantidadEfectivaStock = (tipoAjuste == 'INGRESO_MANUAL')
                ? cantidadBase
                : (tipoAjuste == 'CORRECCION' ? cantIngresada - insumo.stockActual : -cantidadBase);

            final double costoUnitario = insumo.precioCosto;
            final double valorTotal = (cantidadBase * costoUnitario).abs();

            return AppCrudDialog(
              titulo: 'Ajuste de Stock: ${insumo.nombreConPresentacion}',
              icono: Icons.swap_vert,
              maxWidth: 520,
              textoGuardar: 'Confirmar Ajuste',
              onGuardar: () async {
                if (cantIngresada <= 0 && tipoAjuste != 'CORRECCION') return;

                final ajuste = AjusteInventario(
                  insumoId: insumo.id!,
                  cantidad: cantidadEfectivaStock,
                  cantidadIngresada: cantIngresada,
                  unidadIngreso: unidadSeleccionada,
                  factorConversionUsado: factorUsado,
                  tipoAjuste: tipoAjuste,
                  costoUnitarioHistorico: costoUnitario,
                  motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
                );

                await _ajustesRepo.registrarAjuste(ajuste);
                if (!context.mounted) return;
                Navigator.pop(context);
                AppNotifier.instance.notifyStockActualizado();
                _cargarDatos();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ajuste de stock registrado correctamente para ${insumo.nombre}.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              contenido: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipoAjuste,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Ajuste',
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'INGRESO_MANUAL', child: Text('📦 Ingreso de Mercadería (Compra)')),
                      DropdownMenuItem(value: 'MERMA', child: Text('🗑️ Merma / Basura / Desperdicio')),
                      DropdownMenuItem(value: 'ROBO', child: Text('⚠️ Pérdida / Faltante / Robo')),
                      DropdownMenuItem(value: 'DONACION', child: Text('🎁 Donación / Degustación')),
                      DropdownMenuItem(value: 'CORRECCION', child: Text('✏️ Corrección Directa de Stock')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => tipoAjuste = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: cantidadCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: tipoAjuste == 'CORRECCION' ? 'Nuevo Stock Real' : 'Cantidad a Ajustar',
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: unidadSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: unidadesDisponibles
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => unidadSeleccionada = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo / Observación (Opcional)',
                      hintText: 'ej. Compra por docenas / Panes vencidos',
                      prefixIcon: Icon(Icons.comment),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stock Actual en Sistema:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('${insumo.stockActual} ${insumo.unidadMedida}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(esIngreso ? '📦 Impacto en Stock:' : '🗑️ Salida de Stock:', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(
                              '${cantidadEfectivaStock >= 0 ? "+" : ""}${cantidadEfectivaStock.toStringAsFixed(1)} ${insumo.unidadMedida}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: cantidadEfectivaStock >= 0 ? AppColors.success : AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Costo Unitario Base:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('\$${costoUnitario.toStringAsFixed(0)} / ${insumo.unidadMedida}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Valor Total del Ajuste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('\$${valorTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirModalProducto([Producto? productoExistenteInput, String tipoInicial = 'INSUMO']) async {
    Producto? productoExistente = productoExistenteInput;
    if (productoExistente != null && productoExistente.id != null) {
      final productoFresco = await _productosRepo.getProductoPorId(productoExistente.id!);
      if (productoFresco != null) {
        productoExistente = productoFresco;
      }
    }
    final prodExistente = productoExistente;

    const unidadesValidas = ['Unidad', 'Docena', 'Gramos', 'Kilos', 'Litros'];
    const unidadesContenidoValidas = ['ml', 'L', 'gr', 'kg', 'Unidad', 'Docena'];

    final nombreCtrl = TextEditingController(text: productoExistente?.nombre ?? '');
    final contenidoCtrl = TextEditingController(
      text: productoExistente?.contenidoNeto != null
          ? ((productoExistente!.contenidoNeto! % 1 == 0)
              ? productoExistente.contenidoNeto!.toInt().toString()
              : productoExistente.contenidoNeto!.toString())
          : '',
    );
    final costoDirectoCtrl = TextEditingController(text: productoExistente?.precioCosto.toString() ?? '0');
    final ventaCtrl = TextEditingController(text: productoExistente?.precioVentaUnitario?.toString() ?? '');
    final stockCtrl = TextEditingController(text: productoExistente?.stockActual.toString() ?? '0');
    final unidadCompraCtrl = TextEditingController(text: productoExistente?.unidadCompra ?? '');
    final factorConversionCtrl = TextEditingController(
      text: (productoExistente?.factorConversion != null && productoExistente!.factorConversion > 1.0)
          ? ((productoExistente.factorConversion % 1 == 0)
              ? productoExistente.factorConversion.toInt().toString()
              : productoExistente.factorConversion.toString())
          : '1',
    );

    final cantidadInsumoCtrl = TextEditingController(text: '1');

    String tipoSeleccionado = productoExistente?.tipo ?? tipoInicial;

    String unidadMedida = unidadesValidas.contains(productoExistente?.unidadMedida)
        ? productoExistente!.unidadMedida
        : 'Unidad';

    String unidadContenido = unidadesContenidoValidas.contains(productoExistente?.unidadContenido)
        ? productoExistente!.unidadContenido!
        : 'ml';

    int? categoriaId = (_categorias.any((c) => c.id == productoExistente?.categoriaId))
        ? productoExistente!.categoriaId
        : (_categorias.isNotEmpty ? _categorias.first.id : null);

    List<Receta> ingredientesReceta = [];
    if (productoExistente != null && productoExistente.id != null) {
      ingredientesReceta = await _recetasRepo.getRecetasPorProductoPadre(productoExistente.id!);
    }

    bool esVendibleSolo = productoExistente?.esVendibleSolo ?? (tipoSeleccionado != 'INSUMO');

    int? insumoAgregarId;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double costoTotalReceta = 0.0;
            for (final r in ingredientesReceta) {
              final insumoObj = _todosLosProductos.where((i) => i.id == r.insumoId).firstOrNull;
              final costoUnit = insumoObj?.costoEfectivo ?? (r.insumoPrecioCosto ?? 0.0);
              costoTotalReceta += r.cantidadRequerida * costoUnit;
            }

            final bool esCompuesto = tipoSeleccionado == 'PRODUCTO' || tipoSeleccionado == 'COMBO';

            final double costoEfectivo = esCompuesto
                ? (ingredientesReceta.isEmpty ? (double.tryParse(costoDirectoCtrl.text) ?? 0.0) : costoTotalReceta)
                : (double.tryParse(costoDirectoCtrl.text) ?? 0.0);

            final double precioVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
            final double ganancia = precioVenta - costoEfectivo;
            final double margenPorcentaje = precioVenta > 0 ? (ganancia / precioVenta) * 100 : 0.0;

            final componentesFiltrados = _todosLosProductos.where((p) {
              if (prodExistente != null && p.id == prodExistente.id) return false;

              if (tipoSeleccionado == 'PRODUCTO') {
                return p.esInsumo; // Un Producto se compone de Insumos
              } else if (tipoSeleccionado == 'COMBO') {
                return p.esProducto || p.esInsumo; // Un Combo puede incluir Productos e Insumos
              }
              return true;
            }).toList();

            if (componentesFiltrados.isNotEmpty &&
                (insumoAgregarId == null || !componentesFiltrados.any((c) => c.id == insumoAgregarId))) {
              insumoAgregarId = componentesFiltrados.first.id;
            } else if (componentesFiltrados.isEmpty) {
              insumoAgregarId = null;
            }

            final int? categoriaSeleccionada = (_categorias.any((c) => c.id == categoriaId))
                ? categoriaId
                : (_categorias.isNotEmpty ? _categorias.first.id : null);

            return AppCrudDialog(
              titulo: prodExistente == null
                  ? 'Nuevo Ítem ($tipoSeleccionado)'
                  : 'Editar: ${prodExistente.nombreConPresentacion}',
              icono: tipoSeleccionado == 'COMBO'
                  ? Icons.stars
                  : (tipoSeleccionado == 'PRODUCTO' ? Icons.lunch_dining : Icons.inventory_2),
              textoGuardar: prodExistente == null ? 'Guardar Ítem' : 'Guardar Cambios',
              maxWidth: 640,
              onEliminar: prodExistente != null
                  ? () async {
                      final bool confirmar = await AppConfirmDialog.mostrar(
                        context,
                        titulo: 'Eliminar Ítem',
                        mensaje:
                            '¿Estás seguro de eliminar "${prodExistente.nombreConPresentacion}"? Si este ítem forma parte de recetas o combos, sus asociaciones también se eliminarán.',
                      );

                      if (!confirmar) return;

                      try {
                        await _productosRepo.deleteProducto(prodExistente.id!);

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        AppNotifier.instance.notifyStockActualizado();
                        _cargarDatos();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${prodExistente.nombreConPresentacion}" fue eliminado correctamente.'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No se pudo eliminar el ítem: $e'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      }
                    }
                  : null,
              onGuardar: () async {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;

                final costoIngresado = double.tryParse(costoDirectoCtrl.text) ?? 0.0;
                final costoFinal = (esCompuesto && ingredientesReceta.isNotEmpty) ? costoTotalReceta : costoIngresado;
                final precioVentaVal = esVendibleSolo ? (double.tryParse(ventaCtrl.text) ?? 0.0) : null;
                final stock = double.tryParse(stockCtrl.text) ?? 0.0;
                final contenidoVal = double.tryParse(contenidoCtrl.text.replaceAll(',', '.'));
                final unidadCompraVal = unidadCompraCtrl.text.trim().isEmpty ? null : unidadCompraCtrl.text.trim();
                final factorConversionVal = double.tryParse(factorConversionCtrl.text) ?? 1.0;

                final p = Producto(
                  id: productoExistente?.id,
                  categoriaId: categoriaSeleccionada,
                  nombre: nombre,
                  unidadMedida: esCompuesto ? 'Unidad' : unidadMedida,
                  unidadCompra: unidadCompraVal,
                  factorConversion: factorConversionVal,
                  contenidoNeto: contenidoVal,
                  unidadContenido: contenidoVal != null ? unidadContenido : null,
                  precioCosto: costoFinal,
                  costoCalculadoCache: costoFinal,
                  precioVentaUnitario: precioVentaVal,
                  stockActual: stock,
                  esVendibleSolo: esVendibleSolo,
                  tipo: tipoSeleccionado,
                  activo: true,
                );

                try {
                  if (productoExistente == null) {
                    final newId = await _productosRepo.insertProducto(p);
                    if (esCompuesto && ingredientesReceta.isNotEmpty) {
                      final recetasConIdPadre = ingredientesReceta
                          .map((r) => Receta(
                                productoPadreId: newId,
                                insumoId: r.insumoId,
                                cantidadRequerida: r.cantidadRequerida,
                              ))
                          .toList();
                      await _recetasRepo.guardarRecetaCompleta(newId, recetasConIdPadre);
                    }
                  } else {
                    await _productosRepo.updateProducto(p);
                    if (esCompuesto) {
                      await _recetasRepo.guardarRecetaCompleta(p.id!, ingredientesReceta);
                    }
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  AppNotifier.instance.notifyStockActualizado();
                  _cargarDatos();
                } catch (err) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err.toString().replaceAll('Exception: ', '')),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                }
              },
              contenido: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de 3 tipos explícitos
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              tipoSeleccionado = 'INSUMO';
                              esVendibleSolo = false;
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: tipoSeleccionado == 'INSUMO' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '🥩 Insumo Base',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: tipoSeleccionado == 'INSUMO' ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              tipoSeleccionado = 'PRODUCTO';
                              esVendibleSolo = true;
                              unidadMedida = 'Unidad';
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: tipoSeleccionado == 'PRODUCTO' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '🍔 Producto',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: tipoSeleccionado == 'PRODUCTO' ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              tipoSeleccionado = 'COMBO';
                              esVendibleSolo = true;
                              unidadMedida = 'Unidad';
                            }),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: tipoSeleccionado == 'COMBO' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '⭐ Combo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: tipoSeleccionado == 'COMBO' ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---------- 📦 INFORMACIÓN DEL ÍTEM ----------
                  const Text('📦 Información del Ítem', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nombreCtrl,
                    decoration: InputDecoration(
                      labelText: tipoSeleccionado == 'INSUMO'
                          ? 'Nombre del Insumo (ej. Tequeños / Pan de Pancho)'
                          : (tipoSeleccionado == 'PRODUCTO'
                              ? 'Nombre del Producto (ej. Empanada de Carne)'
                              : 'Nombre del Combo (ej. Combo Tequeños + Coca)'),
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: contenidoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Presentación (ej. 473 ml / 500 gr)',
                            prefixIcon: Icon(Icons.local_drink_outlined),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: unidadContenido,
                          decoration: const InputDecoration(
                            labelText: 'Unidad Pres.',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: unidadesContenidoValidas
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) => setModalState(() => unidadContenido = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_categorias.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: categoriaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Categoría del Ítem',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categorias
                          .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.nombre)))
                          .toList(),
                      onChanged: (val) => setModalState(() => categoriaId = val),
                    ),
                  const SizedBox(height: 16),

                  // ---------- 🔧 CONTROL DE INVENTARIO Y UNIDADES ----------
                  if (tipoSeleccionado == 'INSUMO') ...[
                    const Text('🔧 Control de Unidades e Inventario',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: unidadMedida,
                            decoration: const InputDecoration(
                              labelText: 'Unidad Base (Stock)',
                              helperText: 'En qué se descuenta (ej. Unidad, Gramos)',
                              prefixIcon: Icon(Icons.tune),
                            ),
                            items: unidadesValidas.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => unidadMedida = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: unidadCompraCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Unidad Compra (Opcional)',
                              hintText: 'ej. Docena, Pack x6, Kilo',
                              helperText: 'Cómo te lo entrega el proveedor',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (unidadCompraCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: factorConversionCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Factor de Conversión (Equivalencia)',
                          helperText:
                              '1 ${unidadCompraCtrl.text.trim()} = X $unidadMedida (ej. 12 para Docena)',
                          prefixIcon: const Icon(Icons.multiple_stop),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costoDirectoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Costo por $unidadMedida (\$)',
                              prefixIcon: const Icon(Icons.attach_money),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Stock Inicial ($unidadMedida)',
                              prefixIcon: const Icon(Icons.inventory),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('¿Se vende directamente al cliente?', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('ej. Coca-Cola o Empanadas vendidas por unidad'),
                      value: esVendibleSolo,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => esVendibleSolo = val),
                    ),
                  ],

                  // ---------- 🥗 COMPOSICIÓN / RECETAS (PRODUCTO / COMBO) ----------
                  if (esCompuesto) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                tipoSeleccionado == 'COMBO' ? Icons.stars : Icons.restaurant_menu,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tipoSeleccionado == 'COMBO'
                                    ? 'Componentes del Combo'
                                    : 'Receta e Ingredientes del Producto',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                              const Spacer(),
                              Text(
                                '${ingredientesReceta.length} elementos',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (ingredientesReceta.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: const Text(
                                'Sin componentes aún. Selecciona abajo para agregar.',
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ingredientesReceta.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.surface),
                              itemBuilder: (context, index) {
                                final r = ingredientesReceta[index];
                                final insumoObj = _todosLosProductos.where((i) => i.id == r.insumoId).firstOrNull;
                                final nombre = insumoObj?.nombreConPresentacion ?? r.insumoNombre ?? 'Ítem #${r.insumoId}';
                                final unidad = insumoObj?.unidadMedida ?? r.insumoUnidadMedida ?? 'Unidad';
                                final costoUnit = insumoObj?.costoEfectivo ?? (r.insumoPrecioCosto ?? 0.0);
                                final subtotal = r.cantidadRequerida * costoUnit;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      insumoObj?.esCombo == true
                                          ? AppBadge.combo(fontSize: 10)
                                          : (insumoObj?.esProducto == true
                                              ? AppBadge.producto(fontSize: 10)
                                              : AppBadge.insumo(fontSize: 10)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(
                                              '\$${costoUnit.toStringAsFixed(0)} c/$unidad',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.background,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${r.cantidadRequerida} $unidad',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 75,
                                        child: Text(
                                          '= \$${subtotal.toStringAsFixed(0)}',
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.secondary, size: 18),
                                        tooltip: 'Quitar componente',
                                        onPressed: () {
                                          setModalState(() {
                                            ingredientesReceta.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 10),

                          // Formulario para agregar componente
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      isExpanded: true,
                                      value: (componentesFiltrados.any((i) => i.id == insumoAgregarId))
                                          ? insumoAgregarId
                                          : null,
                                      items: componentesFiltrados.map((i) {
                                        return DropdownMenuItem<int>(
                                          value: i.id,
                                          child: Text(
                                            '${i.esProducto ? '🍔' : (i.esCombo ? '⭐' : '🥩')} ${i.nombre} (\$${i.costoEfectivo.toStringAsFixed(0)}/${i.unidadMedida})',
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setModalState(() => insumoAgregarId = val),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    controller: cantidadInsumoCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      labelText: 'Cant.',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: () {
                                    if (insumoAgregarId == null) return;
                                    final cant = double.tryParse(cantidadInsumoCtrl.text) ?? 1.0;
                                    if (cant <= 0) return;

                                    final insumoObj = _todosLosProductos.where((i) => i.id == insumoAgregarId).firstOrNull;

                                    setModalState(() {
                                      final existeIndex =
                                          ingredientesReceta.indexWhere((r) => r.insumoId == insumoAgregarId);
                                      if (existeIndex >= 0) {
                                        final existente = ingredientesReceta[existeIndex];
                                        ingredientesReceta[existeIndex] = Receta(
                                          id: existente.id,
                                          productoPadreId: productoExistente?.id ?? 0,
                                          insumoId: insumoAgregarId!,
                                          cantidadRequerida: existente.cantidadRequerida + cant,
                                          insumoNombre: insumoObj?.nombre,
                                          insumoUnidadMedida: insumoObj?.unidadMedida,
                                          insumoPrecioCosto: insumoObj?.costoEfectivo,
                                        );
                                      } else {
                                        ingredientesReceta.add(Receta(
                                          productoPadreId: productoExistente?.id ?? 0,
                                          insumoId: insumoAgregarId!,
                                          cantidadRequerida: cant,
                                          insumoNombre: insumoObj?.nombre,
                                          insumoUnidadMedida: insumoObj?.unidadMedida,
                                          insumoPrecioCosto: insumoObj?.costoEfectivo,
                                        ));
                                      }
                                    });
                                  },
                                  child: const Icon(Icons.add, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ---------- 💰 PRECIO DE VENTA Y MARGEN DE GANANCIA ----------
                  if (esVendibleSolo) ...[
                    TextField(
                      controller: ventaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio de Venta al Público (\$)',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Costo Calculado (BOM):', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text('\$${costoEfectivo.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ganancia Bruta por Unidad:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              Text(
                                '\$${ganancia.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: ganancia >= 0 ? AppColors.success : AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12, color: Colors.white10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Margen de Ganancia:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: margenPorcentaje >= 40
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : (margenPorcentaje > 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${margenPorcentaje.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: margenPorcentaje >= 40
                                        ? AppColors.success
                                        : (margenPorcentaje > 0 ? AppColors.warning : AppColors.secondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2), text: 'Insumos & Materias Primas'),
              Tab(icon: Icon(Icons.lunch_dining), text: 'Productos'),
              Tab(icon: Icon(Icons.stars), text: 'Combos'),
              Tab(icon: Icon(Icons.assignment_turned_in_outlined), text: 'Ajustes de Inventario'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListaInsumos(),
              _buildListaProductos(),
              _buildListaCombos(),
              _buildListaAjustes(),
            ],
          ),
        ),
      ],
    );
  }

  void _abrirModalGestionCategorias() {
    final nuevaCatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppCrudDialog(
              titulo: 'Gestión de Categorías',
              icono: Icons.category,
              maxWidth: 500,
              textoGuardar: 'Listo',
              onGuardar: () => Navigator.of(context).pop(),
              contenido: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agrega nuevas categorías para organizar tus insumos y productos (ej. Empanadas, Bebidas):',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nuevaCatCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nueva Categoría (ej. Empanadas)',
                            isDense: true,
                            prefixIcon: Icon(Icons.label_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () async {
                          final nombre = nuevaCatCtrl.text.trim();
                          if (nombre.isEmpty) return;

                          await _categoriasRepo.insertCategoria(Categoria(nombre: nombre));
                          nuevaCatCtrl.clear();
                          await _cargarDatos();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Categorías Existentes:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  if (_categorias.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('No hay categorías registradas.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _categorias.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.surfaceLight,
                            child: Icon(Icons.label, size: 14, color: AppColors.primary),
                          ),
                          title: Text(cat.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                tooltip: 'Renombrar categoría',
                                onPressed: () {
                                  _abrirModalEditarCategoria(cat, () {
                                    _cargarDatos();
                                    setModalState(() {});
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.secondary),
                                tooltip: 'Eliminar categoría',
                                onPressed: () async {
                                  final bool confirmar = await AppConfirmDialog.mostrar(
                                    context,
                                    titulo: 'Eliminar Categoría',
                                    mensaje: '¿Estás seguro de eliminar la categoría "${cat.nombre}"?',
                                  );

                                  if (!confirmar) return;

                                  await _categoriasRepo.deleteCategoria(cat.id!);
                                  await _cargarDatos();
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirModalEditarCategoria(Categoria cat, VoidCallback onGuardado) {
    final editCtrl = TextEditingController(text: cat.nombre);
    showDialog(
      context: context,
      builder: (ctx) => AppCrudDialog(
        titulo: 'Renombrar Categoría',
        icono: Icons.edit,
        maxWidth: 400,
        textoGuardar: 'Guardar Nombre',
        onGuardar: () async {
          final nuevoNombre = editCtrl.text.trim();
          if (nuevoNombre.isEmpty) return;
          await _categoriasRepo.updateCategoria(Categoria(id: cat.id, nombre: nuevoNombre));
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          onGuardado();
        },
        contenido: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(labelText: 'Nombre de la Categoría'),
        ),
      ),
    );
  }

  Widget _buildListaInsumos() {
    return Column(
      children: [
        AppToolbar(
          tituloContador: 'Insumos & Materias Primas',
          cantidadRegistros: _insumos.length,
          onActualizar: _cargarDatos,
          textoBotonNuevo: 'Nuevo Insumo',
          onNuevo: () => _abrirModalProducto(null, 'INSUMO'),
          accionesAdicionales: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.category, size: 16),
              label: const Text('Categorías', style: TextStyle(fontSize: 12)),
              onPressed: _abrirModalGestionCategorias,
            ),
          ],
        ),
        Expanded(
          child: _insumos.isEmpty
              ? const Center(child: Text('No hay insumos físicos agregados.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _insumos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _insumos[index];
                    Color stockColor = AppColors.success;
                    if (item.stockActual <= 0) {
                      stockColor = AppColors.secondary;
                    } else if (item.stockActual < 20) {
                      stockColor = AppColors.warning;
                    }

                    final bool tieneConversion = item.tieneConversionCompra;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stockColor.withValues(alpha: 0.2),
                          child: Icon(Icons.inventory, color: stockColor),
                        ),
                        title: Row(
                          children: [
                            Text(item.nombreConPresentacion, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            AppBadge.insumo(),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Costo Base: \$${item.precioCosto.toStringAsFixed(0)} / ${item.unidadMedida}'),
                            if (tieneConversion)
                              Text(
                                '📦 Se compra por: ${item.unidadCompra} (Factor: 1 ${item.unidadCompra} = ${item.factorConversion % 1 == 0 ? item.factorConversion.toInt() : item.factorConversion} ${item.unidadMedida}s)',
                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              avatar: Icon(
                                item.stockActual <= 0 ? Icons.warning : Icons.check_circle,
                                size: 14,
                                color: Colors.white,
                              ),
                              backgroundColor: stockColor,
                              label: Text(
                                'Stock: ${(item.stockActual % 1 == 0) ? item.stockActual.toInt() : item.stockActual.toStringAsFixed(1)} ${item.unidadMedida}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.swap_vert, size: 16),
                              label: const Text('Ajustar Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _abrirModalAjusteInventario(item),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Editar insumo',
                              onPressed: () => _abrirModalProducto(item, 'INSUMO'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.secondary),
                              tooltip: 'Eliminar insumo',
                              onPressed: () => _confirmarYEliminarProducto(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListaProductos() {
    return Column(
      children: [
        AppToolbar(
          tituloContador: 'Productos Finales',
          cantidadRegistros: _productos.length,
          onActualizar: _cargarDatos,
          textoBotonNuevo: 'Nuevo Producto',
          onNuevo: () => _abrirModalProducto(null, 'PRODUCTO'),
          accionesAdicionales: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.category, size: 16),
              label: const Text('Categorías', style: TextStyle(fontSize: 12)),
              onPressed: _abrirModalGestionCategorias,
            ),
          ],
        ),
        Expanded(
          child: _productos.isEmpty
              ? const Center(child: Text('No hay productos finales registrados.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _productos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _productos[index];
                    final double venta = item.precioVentaUnitario ?? 0.0;
                    final double costo = item.costoEfectivo;
                    final double ganancia = venta - costo;
                    final double margen = venta > 0 ? (ganancia / venta) * 100 : 0.0;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(
                            Icons.lunch_dining,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(item.nombreConPresentacion, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            AppBadge.producto(),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Venta: \$${venta.toStringAsFixed(0)} | Costo Calculado (BOM): \$${costo.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  'Ganancia: \$${ganancia.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ganancia >= 0 ? AppColors.success : AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: margen >= 40
                                        ? AppColors.success.withValues(alpha: 0.2)
                                        : (margen > 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Margen: ${margen.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: margen >= 40
                                          ? AppColors.success
                                          : (margen > 0 ? AppColors.warning : AppColors.secondary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.displayStock <= 0
                                        ? AppColors.secondary.withValues(alpha: 0.2)
                                        : (item.displayStock < 10 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Stock Dispon.: ${(item.displayStock % 1 == 0) ? item.displayStock.toInt() : item.displayStock.toStringAsFixed(1)} ${item.unidadMedida}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.displayStock <= 0
                                          ? AppColors.secondary
                                          : (item.displayStock < 10 ? AppColors.warning : AppColors.success),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Editar producto',
                              onPressed: () => _abrirModalProducto(item, 'PRODUCTO'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.secondary),
                              tooltip: 'Eliminar producto',
                              onPressed: () => _confirmarYEliminarProducto(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListaCombos() {
    return Column(
      children: [
        AppToolbar(
          tituloContador: 'Combos & Promociones',
          cantidadRegistros: _combos.length,
          onActualizar: _cargarDatos,
          textoBotonNuevo: 'Nuevo Combo',
          onNuevo: () => _abrirModalProducto(null, 'COMBO'),
          accionesAdicionales: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              icon: const Icon(Icons.category, size: 16),
              label: const Text('Categorías', style: TextStyle(fontSize: 12)),
              onPressed: _abrirModalGestionCategorias,
            ),
          ],
        ),
        Expanded(
          child: _combos.isEmpty
              ? const Center(child: Text('No hay combos o promociones registrados.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _combos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _combos[index];
                    final double venta = item.precioVentaUnitario ?? 0.0;
                    final double costo = item.costoEfectivo;
                    final double ganancia = venta - costo;
                    final double margen = venta > 0 ? (ganancia / venta) * 100 : 0.0;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(
                            Icons.stars,
                            color: AppColors.accentBlue,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(item.nombreConPresentacion, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            AppBadge.combo(),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Venta: \$${venta.toStringAsFixed(0)} | Costo Calculado (BOM): \$${costo.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  'Ganancia: \$${ganancia.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ganancia >= 0 ? AppColors.success : AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: margen >= 40
                                        ? AppColors.success.withValues(alpha: 0.2)
                                        : (margen > 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Margen: ${margen.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: margen >= 40
                                          ? AppColors.success
                                          : (margen > 0 ? AppColors.warning : AppColors.secondary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.displayStock <= 0
                                        ? AppColors.secondary.withValues(alpha: 0.2)
                                        : (item.displayStock < 10 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.success.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Stock Virtual: ${(item.displayStock % 1 == 0) ? item.displayStock.toInt() : item.displayStock.toStringAsFixed(1)} ${item.unidadMedida}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item.displayStock <= 0
                                          ? AppColors.secondary
                                          : (item.displayStock < 10 ? AppColors.warning : AppColors.success),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Editar combo',
                              onPressed: () => _abrirModalProducto(item, 'COMBO'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.secondary),
                              tooltip: 'Eliminar combo',
                              onPressed: () => _confirmarYEliminarProducto(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListaAjustes() {
    return Column(
      children: [
        AppToolbar(
          tituloContador: 'Historial y Auditoría de Ajustes de Stock',
          cantidadRegistros: _historialAjustes.length,
          onActualizar: _cargarDatos,
          textoBotonNuevo: null,
          onNuevo: null,
        ),
        Expanded(
          child: _historialAjustes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'No hay ajustes de stock registrados todavía.',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Los ingresos por compras, mermas, pérdidas o correcciones aparecerán auditados aquí.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historialAjustes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _historialAjustes[index];
                    final double valorTotal = (item.cantidad.abs() * item.costoUnitarioHistorico);

                    AppBadge badgeTipo;
                    Color borderClr;
                    IconData iconItem;
                    switch (item.tipoAjuste) {
                      case 'INGRESO_MANUAL':
                        badgeTipo = const AppBadge(
                          texto: '📦 Ingreso / Compra',
                          colorBase: AppColors.success,
                          icono: Icons.add_shopping_cart,
                        );
                        borderClr = AppColors.success;
                        iconItem = Icons.add_circle_outline;
                        break;
                      case 'MERMA':
                        badgeTipo = const AppBadge(
                          texto: '🗑️ Merma / Desecho',
                          colorBase: Colors.orange,
                          icono: Icons.delete_outline,
                        );
                        borderClr = Colors.orange;
                        iconItem = Icons.remove_circle_outline;
                        break;
                      case 'ROBO':
                        badgeTipo = const AppBadge(
                          texto: '⚠️ Pérdida / Faltante',
                          colorBase: AppColors.secondary,
                          icono: Icons.warning_amber_rounded,
                        );
                        borderClr = AppColors.secondary;
                        iconItem = Icons.error_outline;
                        break;
                      case 'DONACION':
                        badgeTipo = const AppBadge(
                          texto: '🎁 Donación / Degustación',
                          colorBase: Colors.purpleAccent,
                          icono: Icons.card_giftcard,
                        );
                        borderClr = Colors.purpleAccent;
                        iconItem = Icons.card_giftcard;
                        break;
                      case 'CORRECCION':
                      default:
                        badgeTipo = const AppBadge(
                          texto: '✏️ Corrección Directa',
                          colorBase: Colors.cyan,
                          icono: Icons.edit_note,
                        );
                        borderClr = Colors.cyan;
                        iconItem = Icons.swap_vert;
                        break;
                    }

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: borderClr.withValues(alpha: 0.15),
                          child: Icon(iconItem, color: borderClr),
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.insumoNombre ?? 'Insumo #${item.insumoId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            badgeTipo,
                            const Spacer(),
                            if (item.fecha != null)
                              Text(
                                item.fecha!,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Ajuste: ${item.cantidadIngresada} ${item.unidadIngreso}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (item.factorConversionUsado > 1.0)
                                  Text(
                                    ' (Factor: ${item.factorConversionUsado.toInt()})',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (item.cantidad >= 0 ? AppColors.success : AppColors.secondary).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Impacto: ${item.cantidad >= 0 ? "+" : ""}${item.cantidad.toStringAsFixed(1)} ${item.insumoUnidadMedida ?? ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.cantidad >= 0 ? AppColors.success : AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.motivo != null && item.motivo!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Motivo / Detalle: "${item.motivo}"',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Costo Base: \$${item.costoUnitarioHistorico.toStringAsFixed(0)} | Valuación del Movimiento: \$${valorTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
