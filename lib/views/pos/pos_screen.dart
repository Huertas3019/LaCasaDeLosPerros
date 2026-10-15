import 'package:flutter/material.dart';
import '../../core/events/app_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../models/categoria.dart';
import '../../models/producto.dart';
import '../../models/turno.dart';
import '../../models/venta_detalle.dart';
import '../../repositories/categorias_repository.dart';
import '../../repositories/productos_repository.dart';
import '../../repositories/turnos_repository.dart';
import '../../repositories/ventas_repository.dart';
import '../../widgets/app_dialog_header.dart';

class CartItem {
  final Producto producto;
  int cantidad;

  CartItem({required this.producto, this.cantidad = 1});

  double get subtotal => (producto.precioVentaUnitario ?? 0.0) * cantidad;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductosRepository _productosRepo = ProductosRepository();
  final CategoriasRepository _categoriasRepo = CategoriasRepository();
  final TurnosRepository _turnosRepo = TurnosRepository();
  final VentasRepository _ventasRepo = VentasRepository();

  List<Categoria> _categorias = [];
  List<Producto> _productos = [];
  int? _selectedCategoriaId;
  Turno? _turnoActivo;
  bool _isLoading = true;

  final List<CartItem> _carrito = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    AppNotifier.instance.addListener(_onAppEvent);
  }

  @override
  void dispose() {
    AppNotifier.instance.removeListener(_onAppEvent);
    super.dispose();
  }

  void _onAppEvent() {
    final e = AppNotifier.instance.lastEventType;
    if (e == AppEventType.turnoCambiado) {
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final turno = await _turnosRepo.getTurnoActivo();
      final categorias = await _categoriasRepo.getCategorias();
      List<Producto> productos;
      
      if (_selectedCategoriaId != null) {
        productos = await _productosRepo.getProductosPorCategoria(_selectedCategoriaId!);
      } else {
        productos = await _productosRepo.getProductos(soloVendibles: true);
      }

      if (mounted) {
        setState(() {
          _turnoActivo = turno;
          _categorias = categorias;
          _productos = productos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _agregarAlCarrito(Producto producto) async {
    if (producto.precioVentaUnitario == null) return;
    
    int cantidadEnCarrito = 0;
    final index = _carrito.indexWhere((item) => item.producto.id == producto.id);
    if (index >= 0) {
      cantidadEnCarrito = _carrito[index].cantidad;
    }

    if (cantidadEnCarrito + 1 > producto.displayStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Stock insuficiente para ${producto.nombreConPresentacion}!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_turnoActivo == null) {
      final turnoActual = await _turnosRepo.getTurnoActivo();
      if (mounted && turnoActual != null) {
        setState(() {
          _turnoActivo = turnoActual;
        });
      }
    }
    if (!mounted) return;
    setState(() {
      if (index >= 0) {
        _carrito[index].cantidad++;
      } else {
        _carrito.add(CartItem(producto: producto));
      }
    });
  }

  void _removerDelCarrito(int index) {
    setState(() {
      if (_carrito[index].cantidad > 1) {
        _carrito[index].cantidad--;
      } else {
        _carrito.removeAt(index);
      }
    });
  }

  double get _totalCarrito => _carrito.fold(0.0, (sum, item) => sum + item.subtotal);
  int get totalItems => _carrito.fold(0, (sum, item) => sum + item.cantidad);

  Future<void> _abrirModalCobro() async {
    if (_carrito.isEmpty) return;

    final turnoActual = await _turnosRepo.getTurnoActivo();
    if (mounted) {
      setState(() {
        _turnoActivo = turnoActual;
      });
    }

    if (!mounted) return;
    if (_turnoActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe abrir un turno de caja antes de realizar una venta.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String medioPago = 'EFECTIVO';
    final total = _totalCarrito;
    final efectivoController = TextEditingController(text: total.toStringAsFixed(0));
    final transferenciaController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppDialogHeader(
                        title: 'Procesar Pago de Venta',
                        icon: Icons.payments,
                        iconColor: AppColors.primary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderGold),
                    ),
                    child: Column(
                      children: [
                        const Text('TOTAL A COBRAR', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyUtils.format(total),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Seleccione Medio de Pago:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Efectivo'),
                          selected: medioPago == 'EFECTIVO',
                          selectedColor: AppColors.primary,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                medioPago = 'EFECTIVO';
                                efectivoController.text = total.toStringAsFixed(0);
                                transferenciaController.text = '0';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Transferencia'),
                          selected: medioPago == 'TRANSFERENCIA',
                          selectedColor: AppColors.accentBlue,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                medioPago = 'TRANSFERENCIA';
                                efectivoController.text = '0';
                                transferenciaController.text = total.toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Mixto'),
                          selected: medioPago == 'MIXTO',
                          selectedColor: AppColors.secondary,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                medioPago = 'MIXTO';
                                double mitad = total / 2;
                                efectivoController.text = mitad.toStringAsFixed(0);
                                transferenciaController.text = (total - mitad).toStringAsFixed(0);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (medioPago == 'MIXTO') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: efectivoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Monto Efectivo (\$)'),
                            onChanged: (val) {
                              double ef = double.tryParse(val) ?? 0;
                              if (ef <= total) {
                                transferenciaController.text = (total - ef).toStringAsFixed(0);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: transferenciaController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Monto Transferencia (\$)'),
                            onChanged: (val) {
                              double tr = double.tryParse(val) ?? 0;
                              if (tr <= total) {
                                efectivoController.text = (total - tr).toStringAsFixed(0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text('CONFIRMAR VENTA Y EMITIR TICKET ($totalItems)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      double ef = double.tryParse(efectivoController.text) ?? 0.0;
                      double tr = double.tryParse(transferenciaController.text) ?? 0.0;

                      if ((ef + tr) < total - 1.0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Los montos sumados no cubren el total de la venta.')),
                        );
                        return;
                      }

                      try {
                        List<VentaDetalle> detalles = _carrito.map((item) {
                          return VentaDetalle(
                            productoId: item.producto.id!,
                            cantidad: item.cantidad,
                            precioUnitario: item.producto.precioVentaUnitario!,
                            subtotal: item.subtotal,
                          );
                        }).toList();

                        await _ventasRepo.registrarVenta(
                          turnoId: _turnoActivo!.id!,
                          montoEfectivo: ef,
                          montoTransferencia: tr,
                          items: detalles,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        setState(() {
                          _carrito.clear();
                        });
                        _cargarDatos();
                        AppNotifier.instance.notifyVentaRealizada();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Venta registrada con éxito y stock descontado!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al registrar venta: $e')),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        if (_turnoActivo == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: AppColors.secondary,
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ATENCIÓN: No hay turno de caja abierto. Vaya a "Caja & Turnos" para abrir el turno.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.surfaceLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Turno #${_turnoActivo!.id} ABIERTO',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                    ),
                  ],
                ),
                Text(
                  'Fondo Inicial: ${CurrencyUtils.format(_turnoActivo!.montoInicialEfectivo)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Todos los Productos'),
                selected: _selectedCategoriaId == null,
                selectedColor: AppColors.primary,
                onSelected: (val) {
                  setState(() => _selectedCategoriaId = null);
                  _cargarDatos();
                },
              ),
              const SizedBox(width: 8),
              for (final cat in _categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.nombre),
                    selected: _selectedCategoriaId == cat.id,
                    selectedColor: AppColors.primary,
                    onSelected: (val) {
                      setState(() => _selectedCategoriaId = val ? cat.id : null);
                      _cargarDatos();
                    },
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _productos.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay productos vendibles configurados.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _productos.length,
                        itemBuilder: (context, index) {
                          final prod = _productos[index];
                          return InkWell(
                            onTap: () => _agregarAlCarrito(prod),
                            borderRadius: BorderRadius.circular(16),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withAlpha(40),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
                                        ),
                                        Text(
                                          CurrencyUtils.format(prod.precioVentaUnitario ?? 0),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      prod.nombre,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Row(
                                      children: const [
                                        Icon(Icons.add_shopping_cart, size: 14, color: AppColors.textMuted),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tocar para añadir',
                                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.surfaceLight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shopping_cart, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Carrito de Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          if (_carrito.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() => _carrito.clear()),
                              child: const Text('Vaciar', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _carrito.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_shopping_cart_outlined, size: 48, color: AppColors.textMuted),
                                  SizedBox(height: 12),
                                  Text(
                                    'El carrito está vacío',
                                    style: TextStyle(color: AppColors.textMuted),
                                  ),
                                  Text(
                                    'Seleccione productos para vender',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _carrito.length,
                              separatorBuilder: (context, index) => const Divider(color: AppColors.border),
                              itemBuilder: (context, index) {
                                final item = _carrito[index];
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.producto.nombre,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '${CurrencyUtils.format(item.producto.precioVentaUnitario ?? 0)} c/u',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.secondary),
                                          onPressed: () => _removerDelCarrito(index),
                                        ),
                                        Text(
                                          '${item.cantidad}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                                          onPressed: () => _agregarAlCarrito(item.producto),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLight,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                CurrencyUtils.format(_totalCarrito),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments),
                              label: Text('COBRAR ($totalItems)'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _carrito.isEmpty ? AppColors.surfaceLight : AppColors.primary,
                              ),
                              onPressed: _carrito.isEmpty ? null : _abrirModalCobro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
