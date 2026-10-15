import 'package:flutter/material.dart';
import '../../core/events/app_notifier.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_utils.dart';
import '../../repositories/backup_repository.dart';
import '../../repositories/ventas_repository.dart';
import '../../widgets/app_metric_card.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final VentasRepository _ventasRepo = VentasRepository();
  final BackupRepository _backupRepo = BackupRepository();

  BalancePeriodico? _balance;
  bool _isLoading = true;
  String _filtroPeriodo = 'ESTE_MES'; // 'HOY', 'ESTA_SEMANA', 'ESTE_MES'

  @override
  void initState() {
    super.initState();
    _cargarBalance();
    AppNotifier.instance.addListener(_onAppEvent);
  }

  @override
  void dispose() {
    AppNotifier.instance.removeListener(_onAppEvent);
    super.dispose();
  }

  void _onAppEvent() {
    final e = AppNotifier.instance.lastEventType;
    if (e == AppEventType.ventaRealizada ||
        e == AppEventType.gastoRegistrado ||
        e == AppEventType.turnoCambiado) {
      _cargarBalance();
    }
  }

  Future<void> _cargarBalance() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime desde;
      DateTime hasta = now.add(const Duration(days: 1));

      if (_filtroPeriodo == 'HOY') {
        desde = DateTime(now.year, now.month, now.day);
      } else if (_filtroPeriodo == 'ESTA_SEMANA') {
        desde = now.subtract(Duration(days: now.weekday - 1));
        desde = DateTime(desde.year, desde.month, desde.day);
      } else {
        desde = DateTime(now.year, now.month, 1);
      }

      final balance = await _ventasRepo.obtenerBalancePeriodico(
        fechaDesde: desde.toIso8601String(),
        fechaHasta: hasta.toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _balance = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _compartirBackup() async {
    try {
      await _backupRepo.exportarYCompartirBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir backup: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _restaurarBackup() async {
    try {
      bool exito = await _backupRepo.restaurarBackup();
      if (exito && mounted) {
        _cargarBalance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Base de datos restaurada correctamente!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                ' Balance Financiero Real',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'HOY', label: Text('Hoy')),
                  ButtonSegment(value: 'ESTA_SEMANA', label: Text('Esta Semana')),
                  ButtonSegment(value: 'ESTE_MES', label: Text('Este Mes')),
                ],
                selected: {_filtroPeriodo},
                onSelectionChanged: (set) {
                  setState(() {
                    _filtroPeriodo = set.first;
                  });
                  _cargarBalance();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_balance != null) ...[
            Card(
              color: AppColors.surfaceLight,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('GANANCIA NETA FINAL DEL PERÍODO', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyUtils.format(_balance!.gananciaNetaFinal),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _balance!.gananciaNetaFinal >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fórmula: Ganancia Bruta \$${CurrencyUtils.format(_balance!.gananciaBruta)} - (Gastos Turno \$${CurrencyUtils.format(_balance!.gastosDeTurno)} + Gastos Fijos \$${CurrencyUtils.format(_balance!.totalGastosFijos)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                AppMetricCard(title: 'Ingresos Totales', value: CurrencyUtils.format(_balance!.ingresosTotales), color: AppColors.primary, icon: Icons.attach_money),
                const SizedBox(width: 12),
                AppMetricCard(title: 'Costo Insumos (COGS)', value: '- ${CurrencyUtils.format(_balance!.costoTotalInsumos)}', color: AppColors.secondary, icon: Icons.shopping_basket),
                const SizedBox(width: 12),
                AppMetricCard(title: 'Ganancia Bruta', value: CurrencyUtils.format(_balance!.gananciaBruta), color: AppColors.success, icon: Icons.trending_up),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AppMetricCard(title: 'Gastos de Turnos', value: '- ${CurrencyUtils.format(_balance!.gastosDeTurno)}', color: AppColors.warning, icon: Icons.receipt_long),
                const SizedBox(width: 12),
                AppMetricCard(title: 'Gastos Fijos Operativos', value: '- ${CurrencyUtils.format(_balance!.totalGastosFijos)}', color: AppColors.warning, icon: Icons.business_center),
              ],
            ),
          ],

          const SizedBox(height: 32),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          const Text(
            'Copias de Seguridad (Backup)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Exporta o restaura la base de datos de tu local. Puedes enviarla directamente por WhatsApp o guardarla en Google Drive.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('EXPORTAR Y COMPARTIR BACKUP\n(WhatsApp / Drive / Email)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: _compartirBackup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('RESTAURAR BASE DE DATOS\n(Desde Archivo .db)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _restaurarBackup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
