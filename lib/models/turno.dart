class Turno {
  final int? id;
  final String fechaInicio;
  final String? fechaFin;
  final double montoInicialEfectivo;
  final double? efectivoRealCierre;
  final double? transferenciaRealCierre;
  final double? efectivoEsperadoCierre;
  final double? transferenciaEsperadaCierre;
  final double? diferenciaEfectivo;
  final double? diferenciaTransferencia;
  final String estado; // 'ABIERTO', 'CERRADO'
  final String? observaciones;

  Turno({
    this.id,
    required this.fechaInicio,
    this.fechaFin,
    this.montoInicialEfectivo = 0.0,
    this.efectivoRealCierre,
    this.transferenciaRealCierre,
    this.efectivoEsperadoCierre,
    this.transferenciaEsperadaCierre,
    this.diferenciaEfectivo,
    this.diferenciaTransferencia,
    this.estado = 'ABIERTO',
    this.observaciones,
  });

  bool get isAbierto => estado == 'ABIERTO';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'monto_inicial_efectivo': montoInicialEfectivo,
      'efectivo_real_cierre': efectivoRealCierre,
      'transferencia_real_cierre': transferenciaRealCierre,
      'efectivo_esperado_cierre': efectivoEsperadoCierre,
      'transferencia_esperada_cierre': transferenciaEsperadaCierre,
      'diferencia_efectivo': diferenciaEfectivo,
      'diferencia_transferencia': diferenciaTransferencia,
      'estado': estado,
      'observaciones': observaciones,
    };
  }

  factory Turno.fromMap(Map<String, dynamic> map) {
    return Turno(
      id: map['id'] as int?,
      fechaInicio: map['fecha_inicio'] as String,
      fechaFin: map['fecha_fin'] as String?,
      montoInicialEfectivo: (map['monto_inicial_efectivo'] as num).toDouble(),
      efectivoRealCierre: map['efectivo_real_cierre'] != null
          ? (map['efectivo_real_cierre'] as num).toDouble()
          : null,
      transferenciaRealCierre: map['transferencia_real_cierre'] != null
          ? (map['transferencia_real_cierre'] as num).toDouble()
          : null,
      efectivoEsperadoCierre: map['efectivo_esperado_cierre'] != null
          ? (map['efectivo_esperado_cierre'] as num).toDouble()
          : null,
      transferenciaEsperadaCierre: map['transferencia_esperada_cierre'] != null
          ? (map['transferencia_esperada_cierre'] as num).toDouble()
          : null,
      diferenciaEfectivo: map['diferencia_efectivo'] != null
          ? (map['diferencia_efectivo'] as num).toDouble()
          : null,
      diferenciaTransferencia: map['diferencia_transferencia'] != null
          ? (map['diferencia_transferencia'] as num).toDouble()
          : null,
      estado: (map['estado'] as String?) ?? 'ABIERTO',
      observaciones: map['observaciones'] as String?,
    );
  }
}
