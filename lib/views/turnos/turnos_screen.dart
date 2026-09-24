import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/gasto.dart';
import '../../models/turno.dart';
import '../../repositories/gastos_repository.dart';
import '../../repositories/turnos_repository.dart';

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  final TurnosRepository _turnosRepo = TurnosRepository();
  final GastosRepository _gastosRepo = GastosRepository();

  Turno? _turnoActivo;
  ResumenTurno? _resumenActivo;
  List<Turno> _historialTurnos = [];
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
      ResumenTurno? resumen;
      if (turno != null) {
        resumen = await _turnosRepo.obtenerResumenTurno(turno.id!);
      }
      final historial = await _turnosRepo.getHistorialTurnos();

      setState(() {
        _turnoActivo = turno;
        _resumenActivo = resumen;
        _historialTurnos = historial;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _abrirModalAbrirTurno() {
    final montoCtrl = TextEditingController(text: '5000');
    final obsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.vpn_key, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Apertura de Nuevo Turno'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingrese el monto inicial en efectivo (Fondo de Caja Chica):'),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Fondo Inicial en Efectivo (\$)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
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
                double monto = double.tryParse(montoCtrl.text) ?? 0.0;
                try {
                  await _turnosRepo.abrirTurno(monto, observaciones: obsCtrl.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Turno de caja abierto con éxito!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              },
              child: const Text('Abrir Turno'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalSangria() {
    if (_turnoActivo == null) return;
    final montoCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Retiro de seguridad a caja fuerte');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.local_atm, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Sangría / Retiro de Caja'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Retire efectivo sobrante del cajón hacia la caja fuerte por seguridad. Esto disminuye el efectivo en caja pero NO disminuye la ganancia neta del negocio.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Monto a Retirar (\$)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Concepto / Destino'),
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
                double monto = double.tryParse(montoCtrl.text) ?? 0.0;
                if (monto <= 0) return;

                await _gastosRepo.registrarGasto(Gasto(
                  turnoId: _turnoActivo!.id,
                  descripcion: descCtrl.text.trim(),
                  monto: monto,
                  tipoTransaccion: 'RETIRO_CAJA',
                  medioPago: 'EFECTIVO',
                  fecha: DateTime.now().toIso8601String(),
                ));

                if (!context.mounted) return;
                Navigator.pop(context);
                _cargarDatos();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Sangría / Retiro registrado correctamente!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Confirmar Retiro'),
            ),
          ],
        );
      },
    );
  }

  void _abrirModalCierreTurno() async {
    if (_turnoActivo == null || _resumenActivo == null) return;
    final r = _resumenActivo!;

    final efRealCtrl = TextEditingController(text: r.efectivoTeoricoEnCaja.toStringAsFixed(0));
    final trRealCtrl = TextEditingController(text: r.transferenciasNetasBanco.toStringAsFixed(0));
    final obsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double efReal = double.tryParse(efRealCtrl.text) ?? 0.0;
            double trReal = double.tryParse(trRealCtrl.text) ?? 0.0;
            double difEf = efReal - r.efectivoTeoricoEnCaja;
            double difTr = trReal - r.transferenciasNetasBanco;

            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.point_of_sale_rounded, color: AppColors.secondary),
                  SizedBox(width: 8),
                  Text('Arqueo y Cierre de Turno'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildFilaResumen('Fondo Inicial Efectivo:', _currencyFormat.format(r.montoInicialEfectivo)),
                            _buildFilaResumen('Ventas Efectivo:', '+ ${_currencyFormat.format(r.ventasEfectivo)}'),
                            _buildFilaResumen('Gastos Efectivo:', '- ${_currencyFormat.format(r.gastosEfectivoCaja)}'),
                            _buildFilaResumen('Sangrías Retiradas:', '- ${_currencyFormat.format(r.retirosEfectivoCaja)}'),
                            const Divider(color: AppColors.border),
                            _buildFilaResumen(
                              'EFECTIVO ESPERADO EN CAJA:',
                              _currencyFormat.format(r.efectivoTeoricoEnCaja),
                              isBold: true,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: efRealCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Efectivo Real Contado en Cajón (\$)'),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      if (difEf != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            difEf > 0 ? 'Sobrante de Efectivo: +${_currencyFormat.format(difEf)}' : 'FALTANTE DE EFECTIVO: ${_currencyFormat.format(difEf)}',
                            style: TextStyle(
                              color: difEf > 0 ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildFilaResumen('Ventas Transferencia:', _currencyFormat.format(r.ventasTransferencia)),
                            _buildFilaResumen('Gastos Transferencia:', '- ${_currencyFormat.format(r.gastosTransferenciaCaja)}'),
                            const Divider(color: AppColors.border),
                            _buildFilaResumen(
                              'TRANSFERENCIAS NETAS EN BANCO:',
                              _currencyFormat.format(r.transferenciasNetasBanco),
                              isBold: true,
                              color: AppColors.accentBlue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: trRealCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Transferencias Verificadas en Banco (\$)'),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      if (difTr != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            difTr > 0 ? 'Sobrante de Transferencias: +${_currencyFormat.format(difTr)}' : 'FALTANTE DE TRANSFERENCIAS: ${_currencyFormat.format(difTr)}',
                            style: TextStyle(
                              color: difTr > 0 ? AppColors.success : AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: obsCtrl,
                        decoration: const InputDecoration(labelText: 'Observaciones finales de cierre'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  onPressed: () async {
                    await _turnosRepo.cerrarTurno(
                      turnoId: _turnoActivo!.id!,
                      efectivoRealCierre: efReal,
                      transferenciaRealCierre: trReal,
                      observaciones: obsCtrl.text.trim(),
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _cargarDatos();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Turno de caja cerrado correctamente!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  child: const Text('CONFIRMAR Y CERRAR TURNO', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilaResumen(String label, String valor, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            valor,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de Turno Activo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _turnoActivo != null ? Icons.lock_open : Icons.lock,
                            color: _turnoActivo != null ? AppColors.success : AppColors.secondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _turnoActivo != null ? 'Turno #${_turnoActivo!.id} ACTIVO' : 'SIN TURNO ACTIVO',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (_turnoActivo != null)
                                Text(
                                  'Iniciado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(_turnoActivo!.fechaInicio))}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (_turnoActivo == null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('ABRIR NUEVO TURNO'),
                          onPressed: _abrirModalAbrirTurno,
                        )
                      else
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.local_atm),
                              label: const Text('Sangría / Retiro'),
                              onPressed: _abrirModalSangria,
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                              icon: const Icon(Icons.stop),
                              label: const Text('CERRAR TURNO', style: TextStyle(color: Colors.white)),
                              onPressed: _abrirModalCierreTurno,
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_resumenActivo != null) ...[
                    const Divider(height: 24, color: AppColors.border),
                    Row(
                      children: [
                        _buildMetricaResumen('Fondo Inicial', _currencyFormat.format(_resumenActivo!.montoInicialEfectivo)),
                        _buildMetricaResumen('Ventas Efectivo', '+ ${_currencyFormat.format(_resumenActivo!.ventasEfectivo)}'),
                        _buildMetricaResumen('Ventas Transferencia', '+ ${_currencyFormat.format(_resumenActivo!.ventasTransferencia)}'),
                        _buildMetricaResumen('Gastos/Sangrías', '- ${_currencyFormat.format(_resumenActivo!.gastosEfectivoCaja + _resumenActivo!.retirosEfectivoCaja)}'),
                        _buildMetricaResumen(
                          'Efectivo en Caja',
                          _currencyFormat.format(_resumenActivo!.efectivoTeoricoEnCaja),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Historial de Turnos Anteriores',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_historialTurnos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No hay historial de turnos registrados.')),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _historialTurnos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = _historialTurnos[index];
                final isAbierto = t.isAbierto;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAbierto ? AppColors.success.withValues(alpha: 0.2) : AppColors.surfaceLight,
                      child: Icon(
                        isAbierto ? Icons.lock_open : Icons.lock_clock,
                        color: isAbierto ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                    title: Text(
                      'Turno #${t.id} - ${t.estado}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Inicio: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t.fechaInicio))}'
                      '${t.fechaFin != null ? ' | Fin: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(t.fechaFin!))}' : ''}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Fondo: ${_currencyFormat.format(t.montoInicialEfectivo)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (t.efectivoRealCierre != null)
                          Text(
                            'Cierre: ${_currencyFormat.format(t.efectivoRealCierre!)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricaResumen(String titulo, String valor, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
