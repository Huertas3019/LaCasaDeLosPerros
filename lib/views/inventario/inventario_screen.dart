import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/categoria.dart';
import '../../models/producto.dart';
import '../../models/receta.dart';
import '../../repositories/categorias_repository.dart';
import '../../repositories/productos_repository.dart';
import '../../repositories/recetas_repository.dart';

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

  List<Producto> _insumos = [];
  List<Producto> _combos = [];
  List<Producto> _todosLosProductos = [];
  List<Categoria> _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final todosProds = await _productosRepo.getProductos(soloActivos: false);
      final categorias = await _categoriasRepo.getCategorias();

      setState(() {
        _todosLosProductos = todosProds;
        _insumos = todosProds.where((p) => !p.esVendibleSolo || p.unidadMedida != 'Unidad').toList();
        _combos = todosProds.where((p) => p.esVendibleSolo).toList();
        _categorias = categorias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _abrirModalProducto([Producto? productoExistente, bool esInsumoInicial = true]) async {
    const unidadesValidas = ['Unidad', 'Gramos', 'Kilos', 'Litros'];

    final nombreCtrl = TextEditingController(text: productoExistente?.nombre ?? '');
    final costoDirectoCtrl = TextEditingController(text: productoExistente?.precioCosto.toString() ?? '0');
    final ventaCtrl = TextEditingController(text: productoExistente?.precioVentaUnitario?.toString() ?? '');
    final stockCtrl = TextEditingController(text: productoExistente?.stockActual.toString() ?? '0');
    final cantidadInsumoCtrl = TextEditingController(text: '1');
    final busquedaComponenteCtrl = TextEditingController();
    
    String unidadMedida = unidadesValidas.contains(productoExistente?.unidadMedida)
        ? productoExistente!.unidadMedida
        : 'Unidad';

    int? categoriaId = (_categorias.any((c) => c.id == productoExistente?.categoriaId))
        ? productoExistente!.categoriaId
        : (_categorias.isNotEmpty ? _categorias.first.id : null);
    
    // Filtros para el selector de componentes en combos
    String filtroOrigen = 'TODOS'; // 'TODOS', 'INSUMOS', 'BEBIDAS'
    int? filtroCategoriaComponente;
    
    // Si tiene ID y es combo o no es insumo inicial, verificamos tipo
    bool esTipoCombo = productoExistente != null 
        ? (productoExistente.esVendibleSolo && productoExistente.unidadMedida == 'Unidad')
        : !esInsumoInicial;
    
    bool esVendibleSolo = productoExistente?.esVendibleSolo ?? esTipoCombo;

    // Cargar ingredientes existentes si estamos editando
    List<Receta> ingredientesReceta = [];
    if (productoExistente != null && productoExistente.id != null) {
      ingredientesReceta = await _recetasRepo.getRecetasPorProductoPadre(productoExistente.id!);
    }

    int? insumoAgregarId;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calcular costo total derivado de la receta
            double costoTotalReceta = 0.0;
            for (final r in ingredientesReceta) {
              final insumoObj = _todosLosProductos.where((i) => i.id == r.insumoId).firstOrNull;
              final costoUnit = insumoObj?.precioCosto ?? (r.insumoPrecioCosto ?? 0.0);
              costoTotalReceta += r.cantidadRequerida * costoUnit;
            }

            final double costoEfectivo = esTipoCombo 
                ? (ingredientesReceta.isEmpty ? (double.tryParse(costoDirectoCtrl.text) ?? 0.0) : costoTotalReceta)
                : (double.tryParse(costoDirectoCtrl.text) ?? 0.0);

            final double precioVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
            final double ganancia = precioVenta - costoEfectivo;
            final double margenPorcentaje = precioVenta > 0 ? (ganancia / precioVenta) * 100 : 0.0;

            // Filtrar componentes disponibles para añadir a la receta
            final componentesFiltrados = _todosLosProductos.where((p) {
              // No incluirse a sí mismo
              if (productoExistente != null && p.id == productoExistente.id) return false;
              
              // Filtro por tipo/origen
              final bool esInsumoPuro = !p.esVendibleSolo || p.unidadMedida != 'Unidad';
              if (filtroOrigen == 'INSUMOS' && !esInsumoPuro) return false;
              if (filtroOrigen == 'BEBIDAS' && esInsumoPuro) return false;

              // Filtro por categoría
              if (filtroCategoriaComponente != null && p.categoriaId != filtroCategoriaComponente) return false;

              // Filtro por texto de búsqueda
              final busq = busquedaComponenteCtrl.text.trim().toLowerCase();
              if (busq.isNotEmpty && !p.nombre.toLowerCase().contains(busq)) return false;

              return true;
            }).toList();

            // Asegurar que el id seleccionado pertenezca a la lista filtrada
            if (componentesFiltrados.isNotEmpty && (insumoAgregarId == null || !componentesFiltrados.any((c) => c.id == insumoAgregarId))) {
              insumoAgregarId = componentesFiltrados.first.id;
            } else if (componentesFiltrados.isEmpty) {
              insumoAgregarId = null;
            }

            // Validar que categoriaId exista en _categorias
            final int? categoriaSeleccionada = (_categorias.any((c) => c.id == categoriaId))
                ? categoriaId
                : (_categorias.isNotEmpty ? _categorias.first.id : null);

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    esTipoCombo ? Icons.lunch_dining : Icons.inventory_2,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      productoExistente == null 
                          ? (esTipoCombo ? 'Nuevo Producto / Combo' : 'Nuevo Insumo')
                          : 'Editar: ${productoExistente.nombre}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (productoExistente != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.secondary),
                      tooltip: 'Eliminar ítem permanentemente',
                      onPressed: () async {
                        final bool confirmar = await _mostrarDialogoConfirmacion(
                          context: context,
                          titulo: 'Eliminar Ítem',
                          mensaje: '¿Estás seguro de que deseas eliminar permanentemente "${productoExistente.nombre}"? Si es un combo o insumo con recetas, sus asociaciones también se borrarán.',
                          textoConfirmar: 'Sí, Eliminar',
                        );

                        if (!confirmar) return;

                        await _productosRepo.deleteProducto(productoExistente.id!);

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _cargarDatos();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${productoExistente.nombre}" fue eliminado correctamente.'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Tipo si es nuevo producto
                      if (productoExistente == null) ...[
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
                                    esTipoCombo = true;
                                    esVendibleSolo = true;
                                    unidadMedida = 'Unidad';
                                  }),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: esTipoCombo ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '🍔 Combo / Elaborado',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: esTipoCombo ? Colors.black : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setModalState(() {
                                    esTipoCombo = false;
                                    esVendibleSolo = false;
                                  }),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !esTipoCombo ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '🥩 Insumo / Materia Prima',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: !esTipoCombo ? Colors.black : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Datos Generales
                      TextField(
                        controller: nombreCtrl,
                        decoration: InputDecoration(
                          labelText: esTipoCombo ? 'Nombre del Producto / Combo (ej. Súper Pancho + Coca)' : 'Nombre del Insumo (ej. Pan de Pancho)',
                          prefixIcon: const Icon(Icons.label_outline),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_categorias.isNotEmpty)
                        DropdownButtonFormField<int>(
                          initialValue: categoriaSeleccionada,
                          decoration: const InputDecoration(
                            labelText: 'Categoría del Ítem',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _categorias.map((c) {
                            return DropdownMenuItem<int>(value: c.id, child: Text(c.nombre));
                          }).toList(),
                          onChanged: (val) => setModalState(() => categoriaId = val),
                        ),
                      const SizedBox(height: 16),

                      // SECCIÓN DE RECETA / COMPONENTES PARA COMBOS
                      if (esTipoCombo) ...[
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
                                  const Icon(Icons.restaurant_menu, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Composición del Combo (Insumos & Bebidas)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${ingredientesReceta.length} elementos',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Agrega insumos de cocina (pan, salchichas) y bebidas/productos (Coca-Cola, aguas, etc.):',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 10),

                              // Lista de componentes ya añadidos
                              if (ingredientesReceta.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Sin elementos aún. Selecciona abajo para agregar insumos o bebidas.',
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
                                    final nombre = insumoObj?.nombre ?? r.insumoNombre ?? 'Ítem #${r.insumoId}';
                                    final unidad = insumoObj?.unidadMedida ?? r.insumoUnidadMedida ?? 'Unidad';
                                    final costoUnit = insumoObj?.precioCosto ?? (r.insumoPrecioCosto ?? 0.0);
                                    final subtotal = r.cantidadRequerida * costoUnit;
                                    final bool esBebidaProd = insumoObj?.esVendibleSolo ?? false;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: esBebidaProd 
                                                  ? Colors.blueAccent.withValues(alpha: 0.2)
                                                  : Colors.orangeAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              esBebidaProd ? '🥤 Prod' : '🥩 Insumo',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: esBebidaProd ? Colors.lightBlueAccent : Colors.orangeAccent,
                                              ),
                                            ),
                                          ),
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
                                            width: 80,
                                            child: Text(
                                              '= \$${subtotal.toStringAsFixed(0)}',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppColors.secondary, size: 18),
                                            tooltip: 'Quitar del combo',
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

                              const SizedBox(height: 12),

                              // BARRA DE FILTROS PARA AGREGAR ELEMENTOS
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Selector de Origen (Todos / Insumos Cocina / Bebidas y Productos)
                                    Row(
                                      children: [
                                        const Text('Filtrar:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Todos', style: TextStyle(fontSize: 11)),
                                          selected: filtroOrigen == 'TODOS',
                                          selectedColor: AppColors.primary,
                                          labelStyle: TextStyle(
                                            color: filtroOrigen == 'TODOS' ? Colors.black : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          onSelected: (val) => setModalState(() => filtroOrigen = 'TODOS'),
                                        ),
                                        const SizedBox(width: 4),
                                        ChoiceChip(
                                          label: const Text('🥩 Insumos Cocina', style: TextStyle(fontSize: 11)),
                                          selected: filtroOrigen == 'INSUMOS',
                                          selectedColor: AppColors.primary,
                                          labelStyle: TextStyle(
                                            color: filtroOrigen == 'INSUMOS' ? Colors.black : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          onSelected: (val) => setModalState(() => filtroOrigen = 'INSUMOS'),
                                        ),
                                        const SizedBox(width: 4),
                                        ChoiceChip(
                                          label: const Text('🥤 Bebidas / Prods', style: TextStyle(fontSize: 11)),
                                          selected: filtroOrigen == 'BEBIDAS',
                                          selectedColor: AppColors.primary,
                                          labelStyle: TextStyle(
                                            color: filtroOrigen == 'BEBIDAS' ? Colors.black : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          onSelected: (val) => setModalState(() => filtroOrigen = 'BEBIDAS'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // 2. Filtro por Categoría y Buscador rápido
                                    Row(
                                      children: [
                                        // Dropdown Categoría
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: filtroCategoriaComponente,
                                            isDense: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Categoría',
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            ),
                                            items: [
                                              const DropdownMenuItem<int?>(value: null, child: Text('Todas las categorías', style: TextStyle(fontSize: 11))),
                                              ..._categorias.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.nombre, style: const TextStyle(fontSize: 11)))),
                                            ],
                                            onChanged: (val) => setModalState(() => filtroCategoriaComponente = val),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Buscador de texto
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: busquedaComponenteCtrl,
                                            style: const TextStyle(fontSize: 12),
                                            onChanged: (_) => setModalState(() {}),
                                            decoration: const InputDecoration(
                                              labelText: 'Buscar (ej. coca, pan...)',
                                              isDense: true,
                                              prefixIcon: Icon(Icons.search, size: 16),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // 3. Dropdown de Ítems filtrados + Cantidad + Botón Añadir
                                    if (componentesFiltrados.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 6),
                                        child: Text(
                                          'No se encontraron elementos con los filtros actuales.',
                                          style: TextStyle(color: AppColors.warning, fontSize: 11),
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                isExpanded: true,
                                                value: (componentesFiltrados.any((i) => i.id == insumoAgregarId)) ? insumoAgregarId : null,
                                                items: componentesFiltrados.map((i) {
                                                  final bool esBeb = i.esVendibleSolo;
                                                  return DropdownMenuItem<int>(
                                                    value: i.id,
                                                    child: Text(
                                                      '${esBeb ? '🥤' : '🥩'} ${i.nombre} (\$${i.precioCosto.toStringAsFixed(0)}/${i.unidadMedida}) - Stk: ${i.stockActual.toStringAsFixed(0)}',
                                                      style: const TextStyle(fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) => setModalState(() => insumoAgregarId = val),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 65,
                                            child: TextField(
                                              controller: cantidadInsumoCtrl,
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 12),
                                              decoration: const InputDecoration(
                                                labelText: 'Cant.',
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Agregar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            onPressed: () {
                                              if (insumoAgregarId == null) return;
                                              final cant = double.tryParse(cantidadInsumoCtrl.text) ?? 1.0;
                                              if (cant <= 0) return;

                                              final insumoObj = _todosLosProductos.where((i) => i.id == insumoAgregarId).firstOrNull;

                                              setModalState(() {
                                                final existeIndex = ingredientesReceta.indexWhere((r) => r.insumoId == insumoAgregarId);
                                                if (existeIndex >= 0) {
                                                  final existente = ingredientesReceta[existeIndex];
                                                  ingredientesReceta[existeIndex] = Receta(
                                                    id: existente.id,
                                                    productoPadreId: productoExistente?.id ?? 0,
                                                    insumoId: insumoAgregarId!,
                                                    cantidadRequerida: existente.cantidadRequerida + cant,
                                                    insumoNombre: insumoObj?.nombre,
                                                    insumoUnidadMedida: insumoObj?.unidadMedida,
                                                    insumoPrecioCosto: insumoObj?.precioCosto,
                                                  );
                                                } else {
                                                  ingredientesReceta.add(Receta(
                                                    productoPadreId: productoExistente?.id ?? 0,
                                                    insumoId: insumoAgregarId!,
                                                    cantidadRequerida: cant,
                                                    insumoNombre: insumoObj?.nombre,
                                                    insumoUnidadMedida: insumoObj?.unidadMedida,
                                                    insumoPrecioCosto: insumoObj?.precioCosto,
                                                  ));
                                                }
                                                cantidadInsumoCtrl.text = '1';
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // TARJETA DE COSTO, PRECIO Y MARGEN DE GANANCIA
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Costo
                                Expanded(
                                  child: esTipoCombo && ingredientesReceta.isNotEmpty
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Costo Insumos (Auto)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '\$${costoEfectivo.toStringAsFixed(0)}',
                                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        )
                                      : TextField(
                                          controller: costoDirectoCtrl,
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => setModalState(() {}),
                                          decoration: InputDecoration(
                                            labelText: esTipoCombo ? 'Costo Base (\$)' : 'Precio Costo Compra (\$)',
                                            prefixText: '\$ ',
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Precio Venta
                                Expanded(
                                  child: TextField(
                                    controller: ventaCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setModalState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Precio de Venta (\$)',
                                      prefixText: '\$ ',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (precioVenta > 0) ...[
                              const Divider(height: 20, color: AppColors.surface),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Ganancia Bruta', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        '\$${ganancia.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: ganancia >= 0 ? AppColors.success : AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: margenPorcentaje >= 40
                                          ? AppColors.success.withValues(alpha: 0.2)
                                          : (margenPorcentaje > 0 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: margenPorcentaje >= 40
                                            ? AppColors.success
                                            : (margenPorcentaje > 0 ? AppColors.warning : AppColors.secondary),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          margenPorcentaje >= 40
                                              ? Icons.trending_up
                                              : (margenPorcentaje > 0 ? Icons.trending_flat : Icons.trending_down),
                                          size: 16,
                                          color: margenPorcentaje >= 40
                                              ? AppColors.success
                                              : (margenPorcentaje > 0 ? AppColors.warning : AppColors.secondary),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Margen: ${margenPorcentaje.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: margenPorcentaje >= 40
                                                ? AppColors.success
                                                : (margenPorcentaje > 0 ? AppColors.warning : AppColors.secondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // STOCK DIRECTO Y UNIDAD (Sólo para Insumos puros o productos sin receta)
                      if (!esTipoCombo) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Stock Físico Actual'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: unidadMedida,
                                decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                                items: const [
                                  DropdownMenuItem(value: 'Unidad', child: Text('Unidad')),
                                  DropdownMenuItem(value: 'Gramos', child: Text('Gramos (g)')),
                                  DropdownMenuItem(value: 'Kilos', child: Text('Kilos (kg)')),
                                  DropdownMenuItem(value: 'Litros', child: Text('Litros (L)')),
                                ],
                                onChanged: (val) => setModalState(() => unidadMedida = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      SwitchListTile(
                        title: const Text('¿Disponible para vender en POS?'),
                        subtitle: Text(
                          esVendibleSolo ? 'Aparece en la botonera de ventas del mostrador.' : 'Solo para control interno de stock/recetas.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: esVendibleSolo,
                        activeThumbColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => esVendibleSolo = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    if (nombreCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor ingrese el nombre.')),
                      );
                      return;
                    }

                    final p = Producto(
                      id: productoExistente?.id,
                      categoriaId: categoriaId,
                      nombre: nombreCtrl.text.trim(),
                      precioCosto: costoEfectivo,
                      precioVentaUnitario: double.tryParse(ventaCtrl.text),
                      stockActual: double.tryParse(stockCtrl.text) ?? 0.0,
                      unidadMedida: unidadMedida,
                      esVendibleSolo: esVendibleSolo,
                      activo: true,
                    );

                    int productoId;
                    if (productoExistente == null) {
                      productoId = await _productosRepo.insertProducto(p);
                    } else {
                      await _productosRepo.updateProducto(p);
                      productoId = productoExistente.id!;
                    }

                    // Guardar los ingredientes de la receta si es combo
                    if (esTipoCombo) {
                      await _recetasRepo.guardarRecetaCompleta(productoId, ingredientesReceta);
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _cargarDatos();
                  },
                  child: const Text('Guardar Ítem', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _mostrarDialogoConfirmacion({
    required BuildContext context,
    required String titulo,
    required String mensaje,
    String textoConfirmar = 'Eliminar',
    Color colorConfirmar = AppColors.secondary,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorConfirmar),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorConfirmar,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.fastfood), text: 'Productos & Combos'),
            Tab(icon: Icon(Icons.kitchen), text: 'Insumos / Ingredientes (Stock)'),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña Combos
                    _buildListaCombos(),
                    // Pestaña Insumos Stock
                    _buildListaInsumos(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildListaCombos() {
    return Column(
      children: [
        // Barra Superior de Herramientas (Top Toolbar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Listado de Combos y Productos (${_combos.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Actualizar'),
                onPressed: _cargarDatos,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Combo', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _abrirModalProducto(null, false),
              ),
            ],
          ),
        ),
        Expanded(
          child: _combos.isEmpty
              ? const Center(child: Text('No hay combos o productos finales agregados.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _combos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _combos[index];
                    final double venta = item.precioVentaUnitario ?? 0.0;
                    final double costo = item.precioCosto;
                    final double ganancia = venta - costo;
                    final double margen = venta > 0 ? (ganancia / venta) * 100 : 0.0;

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(Icons.lunch_dining, color: AppColors.primary),
                        ),
                        title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Venta: \$${venta.toStringAsFixed(0)} | Costo Insumos: \$${costo.toStringAsFixed(0)}',
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
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Editar / Eliminar combo',
                              onPressed: () => _abrirModalProducto(item, false),
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

  Widget _buildListaInsumos() {
    return Column(
      children: [
        // Barra Superior de Herramientas (Top Toolbar)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Listado de Insumos & Ingredientes (${_insumos.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Actualizar'),
                onPressed: _cargarDatos,
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Insumo', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _abrirModalProducto(null, true),
              ),
            ],
          ),
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

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: stockColor.withValues(alpha: 0.2),
                          child: Icon(Icons.inventory, color: stockColor),
                        ),
                        title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Costo: \$${item.precioCosto.toStringAsFixed(0)} c/u'),
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
                                'Stock: ${item.stockActual.toStringAsFixed(1)} ${item.unidadMedida}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              tooltip: 'Editar / Eliminar insumo',
                              onPressed: () => _abrirModalProducto(item, true),
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
