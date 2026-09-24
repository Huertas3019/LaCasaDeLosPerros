class Gasto {
  final int? id;
  final int? turnoId; // NULL = Gasto Fijo General, INT = Gasto/Sangría del Turno
  final String descripcion;
  final double monto;
  final String tipoTransaccion; // 'OPERATIVO_FIJO', 'CAJA_TURNO', 'RETIRO_CAJA'
  final String medioPago;       // 'EFECTIVO', 'TRANSFERENCIA'
  final String fecha;

  Gasto({
    this.id,
    this.turnoId,
    required this.descripcion,
    required this.monto,
    required this.tipoTransaccion,
    required this.medioPago,
    required this.fecha,
  });

  bool get esRetiroCaja => tipoTransaccion == 'RETIRO_CAJA';
  bool get esGastoTurno => tipoTransaccion == 'CAJA_TURNO';
  bool get esGastoFijo => tipoTransaccion == 'OPERATIVO_FIJO';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'turno_id': turnoId,
      'descripcion': descripcion,
      'monto': monto,
      'tipo_transaccion': tipoTransaccion,
      'medio_pago': medioPago,
      'fecha': fecha,
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'] as int?,
      turnoId: map['turno_id'] as int?,
      descripcion: map['descripcion'] as String,
      monto: (map['monto'] as num).toDouble(),
      tipoTransaccion: map['tipo_transaccion'] as String,
      medioPago: map['medio_pago'] as String,
      fecha: map['fecha'] as String,
    );
  }
}
