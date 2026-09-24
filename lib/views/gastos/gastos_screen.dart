import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/gasto.dart';
import '../../models/turno.dart';
import '../../repositories/gastos_repository.dart';
import '../../repositories/turnos_repository.dart';

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

  void _abrirModalNuevoGasto({required bool esGastoTurno}) {
    final descCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String medioPago = 'EFECTIVO'; // 'EFECTIVO', 'TRANSFERENCIA'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(esGastoTurno ? Icons.shopping_bag : Icons.account_balance_wallet, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(esGastoTurno ? 'Gasto de Caja de Turno' : 'Gasto Fijo Operacional'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción / Concepto (ej. Compra Hielo, Luz)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Monto del Gasto (\$)'),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Gasto registrado con éxito!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('Guardar Gasto'),
                ),
              ],
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
                // Gastos del Turno Activo
                _buildListaGastos(
                  gastos: _gastosTurno,
                  esGastoTurno: true,
                  puedeAgregar: _turnoActivo != null,
                ),
                // Gastos Fijos
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

  Future<bool> _mostrarDialogoConfirmacion({
    required BuildContext context,
    required String titulo,
    required String mensaje,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.secondary),
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
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _buildListaGastos({
    required List<Gasto> gastos,
    required bool esGastoTurno,
    required bool puedeAgregar,
  }) {
    final double totalGastos = gastos.where((g) => !g.esRetiroCaja).fold(0.0, (acc, g) => acc + g.monto);

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
              Icon(esGastoTurno ? Icons.receipt_long : Icons.business_center, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esGastoTurno ? 'Gastos del Turno (${gastos.length})' : 'Gastos Fijos (${gastos.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Total acumulado: ${_currencyFormat.format(totalGastos)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
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
              if (puedeAgregar) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    esGastoTurno ? 'Nuevo Gasto de Turno' : 'Nuevo Gasto Fijo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _abrirModalNuevoGasto(esGastoTurno: esGastoTurno),
                ),
              ],
            ],
          ),
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
                                final bool confirmar = await _mostrarDialogoConfirmacion(
                                  context: context,
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
