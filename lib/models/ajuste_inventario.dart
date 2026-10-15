class AjusteInventario {
  final int? id;
  final int insumoId;
  final double cantidad; // Cantidad en unidad base (+ para ingreso, - para salida/merma)
  final double cantidadIngresada; // Lo que el usuario escribió originalmente
  final String unidadIngreso; // "Docena", "Kilo", "Unidad", etc.
  final double factorConversionUsado; // Factor al momento del ajuste
  final String tipoAjuste; // 'MERMA', 'ROBO', 'DONACION', 'CORRECCION', 'INGRESO_MANUAL'
  final double costoUnitarioHistorico; // Costo por unidad base al momento del ajuste
  final String? motivo;
  final int? usuarioId;
  final String? fecha;

  // Campos opcionales para UI (poblados mediante JOIN)
  final String? insumoNombre;
  final String? insumoUnidadMedida;

  AjusteInventario({
    this.id,
    required this.insumoId,
    required this.cantidad,
    required this.cantidadIngresada,
    required this.unidadIngreso,
    this.factorConversionUsado = 1.0,
    required this.tipoAjuste,
    this.costoUnitarioHistorico = 0.0,
    this.motivo,
    this.usuarioId,
    this.fecha,
    this.insumoNombre,
    this.insumoUnidadMedida,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'insumo_id': insumoId,
      'cantidad': cantidad,
      'cantidad_ingresada': cantidadIngresada,
      'unidad_ingreso': unidadIngreso,
      'factor_conversion_usado': factorConversionUsado,
      'tipo_ajuste': tipoAjuste,
      'costo_unitario_historico': costoUnitarioHistorico,
      'motivo': motivo,
      'usuario_id': usuarioId,
      if (fecha != null) 'fecha': fecha,
    };
  }

  factory AjusteInventario.fromMap(Map<String, dynamic> map) {
    return AjusteInventario(
      id: map['id'] as int?,
      insumoId: map['insumo_id'] as int,
      cantidad: (map['cantidad'] as num).toDouble(),
      cantidadIngresada: (map['cantidad_ingresada'] as num).toDouble(),
      unidadIngreso: map['unidad_ingreso'] as String,
      factorConversionUsado: (map['factor_conversion_usado'] as num?)?.toDouble() ?? 1.0,
      tipoAjuste: map['tipo_ajuste'] as String,
      costoUnitarioHistorico: (map['costo_unitario_historico'] as num?)?.toDouble() ?? 0.0,
      motivo: map['motivo'] as String?,
      usuarioId: map['usuario_id'] as int?,
      fecha: map['fecha'] as String?,
      insumoNombre: map['insumo_nombre'] as String?,
      insumoUnidadMedida: map['insumo_unidad_medida'] as String?,
    );
  }
}
