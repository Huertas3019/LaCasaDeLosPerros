import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/events/app_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../models/gasto.dart';
import '../../models/turno.dart';
import '../../repositories/gastos_repository.dart';
import '../../repositories/turnos_repository.dart';
import '../../widgets/app_widgets.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final GastosRepository _gastosRepo = GastosRepository();
  final TurnosRepository _turnosRepo = TurnosRepository();

  Turno? _turnoActivo;
  List<Gasto> _gastosTurno = [];
  List<Gasto> _gastosFijos = [];
  bool _isLoading = true;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

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
      List<Gasto> gastosT = [];
      if (turno != null) {
        gastosT = await _gastosRepo.getGastosPorTurno(turno.id!);
      }
      final gastosF = await _gastosRepo.getGastosFijos();

      setState(() {
        _turnoActivo = turno;
        _gastosTurno = gastosT;
        _gastosFijos = gastosF;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _abrirModalNuevoGasto({required bool esGastoTurno}) async {
    if (esGastoTurno && _turnoActivo == null) {
      final turnoActual = await _turnosRepo.getTurnoActivo();
      if (mounted && turnoActual != null) {
        setState(() {
          _turnoActivo = turnoActual;
        });
      }
    }

    if (!mounted) return;

    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String medioPago = 'EFECTIVO';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppCrudDialog(
              titulo: esGastoTurno ? 'Gasto de Caja de Turno' : 'Gasto Fijo Operacional',
              icono: esGastoTurno ? Icons.shopping_bag : Icons.account_balance_wallet,
              textoGuardar: 'Guardar Gasto',
              maxWidth: 500,
              onGuardar: () async {
                if (descCtrl.text.trim().isEmpty) return;
                double monto = double.tryParse(montoCtrl.text) ?? 0.0;
                if (monto <= 0) return;

                await _gastosRepo.registrarGasto(Gasto(
                  turnoId: esGastoTurno ? _turnoActivo?.id : null,
                  descripcion: descCtrl.text.trim(),
                  monto: monto,
                  tipoTransaccion: esGastoTurno ? 'CAJA_TURNO' : 'OPERATIVO_FIJO',
                  medioPago: medioPago,
                  fecha: DateTime.now().toIso8601String(),
                ));

                if (!context.mounted) return;
                Navigator.pop(context);
                _cargarDatos();
                AppNotifier.instance.notifyGastoRegistrado();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Gasto registrado con éxito!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              contenido: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Concepto (ej. Compra Hielo, Luz)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto del Gasto (\$)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: medioPago,
                    decoration: const InputDecoration(labelText: 'Medio de Pago Saliente'),
                    items: const [
                      DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia')),
                    ],
                    onChanged: (val) => setModalState(() => medioPago = val!),
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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(icon: Icon(Icons.receipt), text: 'Gastos del Turno Activo'),
              Tab(icon: Icon(Icons.business_center), text: 'Gastos Fijos Operacionales'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildListaGastos(
                  gastos: _gastosTurno,
                  esGastoTurno: true,
                  puedeAgregar: _turnoActivo != null,
                ),
                _buildListaGastos(
                  gastos: _gastosFijos,
                  esGastoTurno: false,
                  puedeAgregar: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaGastos({
    required List<Gasto> gastos,
    required bool esGastoTurno,
    required bool puedeAgregar,
  }) {
    final double totalGastos = gastos.where((g) => !g.esRetiroCaja).fold(0.0, (acc, g) => acc + g.monto);

    return Column(
      children: [
        AppToolbar(
          tituloContador: esGastoTurno ? 'Gastos del Turno' : 'Gastos Fijos',
          cantidadRegistros: gastos.length,
          onActualizar: _cargarDatos,
          textoBotonNuevo: puedeAgregar ? (esGastoTurno ? 'Nuevo Gasto de Turno' : 'Nuevo Gasto Fijo') : null,
          onNuevo: puedeAgregar ? () => _abrirModalNuevoGasto(esGastoTurno: esGastoTurno) : null,
          accionesAdicionales: [
            Text(
              'Total: ${_currencyFormat.format(totalGastos)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        Expanded(
          child: gastos.isEmpty
              ? Center(
                  child: Text(
                    esGastoTurno
                        ? (_turnoActivo == null ? 'No hay turno activo actualmente.' : 'No hay gastos cargados en este turno.')
                        : 'No hay gastos fijos operacionales registrados.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: gastos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final g = gastos[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: g.esRetiroCaja ? AppColors.accentBlue.withValues(alpha: 0.2) : AppColors.secondary.withValues(alpha: 0.2),
                          child: Icon(
                            g.esRetiroCaja ? Icons.local_atm : Icons.money_off,
                            color: g.esRetiroCaja ? AppColors.accentBlue : AppColors.secondary,
                          ),
                        ),
                        title: Text(g.descripcion, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(g.fecha))}'
                          ' | Medio: ${g.medioPago}'
                          '${g.esRetiroCaja ? ' (Sangría)' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currencyFormat.format(g.monto),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: g.esRetiroCaja ? AppColors.accentBlue : AppColors.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.secondary, size: 20),
                              tooltip: 'Eliminar gasto',
                              onPressed: () async {
                                final bool confirmar = await AppConfirmDialog.mostrar(
                                  context,
                                  titulo: 'Eliminar Gasto',
                                  mensaje: '¿Estás seguro de eliminar el registro de gasto "${g.descripcion}" de ${_currencyFormat.format(g.monto)}?',
                                );

                                if (!confirmar) return;

                                await _gastosRepo.deleteGasto(g.id!);
                                _cargarDatos();

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Gasto eliminado correctamente.'),
                                    backgroundColor: AppColors.secondary,
                                  ),
                                );
                              },
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
