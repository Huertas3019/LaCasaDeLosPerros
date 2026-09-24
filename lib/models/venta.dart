import 'venta_detalle.dart';

class Venta {
  final int? id;
  final int turnoId;
  final String fechaHora;
  final double montoEfectivo;
  final double montoTransferencia;
  final double totalVenta;
  final double costoTotalEstimado; // COGS congelado
  final String estado; // 'COMPLETADA', 'ANULADA'
  final List<VentaDetalle>? detalles;

  Venta({
    this.id,
    required this.turnoId,
    required this.fechaHora,
    this.montoEfectivo = 0.0,
    this.montoTransferencia = 0.0,
    required this.totalVenta,
    this.costoTotalEstimado = 0.0,
    this.estado = 'COMPLETADA',
    this.detalles,
  });

  bool get esCompletada => estado == 'COMPLETADA';
  bool get esAnulada => estado == 'ANULADA';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'turno_id': turnoId,
      'fecha_hora': fechaHora,
      'monto_efectivo': montoEfectivo,
      'monto_transferencia': montoTransferencia,
      'total_venta': totalVenta,
      'costo_total_estimado': costoTotalEstimado,
      'estado': estado,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map, {List<VentaDetalle>? detalles}) {
    return Venta(
      id: map['id'] as int?,
      turnoId: map['turno_id'] as int,
      fechaHora: map['fecha_hora'] as String,
      montoEfectivo: (map['monto_efectivo'] as num).toDouble(),
      montoTransferencia: (map['monto_transferencia'] as num).toDouble(),
      totalVenta: (map['total_venta'] as num).toDouble(),
      costoTotalEstimado: (map['costo_total_estimado'] as num).toDouble(),
      estado: (map['estado'] as String?) ?? 'COMPLETADA',
      detalles: detalles,
    );
  }
}
