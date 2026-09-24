class Receta {
  final int? id;
  final int productoPadreId; // El Combo o Producto final
  final int insumoId;        // El Ingrediente / Insumo a descontar
  final double cantidadRequerida;
  // Propiedades opcionales para JOIN en consultas
  final String? insumoNombre;
  final String? insumoUnidadMedida;
  final double? insumoPrecioCosto;

  Receta({
    this.id,
    required this.productoPadreId,
    required this.insumoId,
    required this.cantidadRequerida,
    this.insumoNombre,
    this.insumoUnidadMedida,
    this.insumoPrecioCosto,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'producto_padre_id': productoPadreId,
      'insumo_id': insumoId,
      'cantidad_requerida': cantidadRequerida,
    };
  }

  factory Receta.fromMap(Map<String, dynamic> map) {
    return Receta(
      id: map['id'] as int?,
      productoPadreId: map['producto_padre_id'] as int,
      insumoId: map['insumo_id'] as int,
      cantidadRequerida: (map['cantidad_requerida'] as num).toDouble(),
      insumoNombre: map['insumo_nombre'] as String?,
      insumoUnidadMedida: map['insumo_unidad_medida'] as String?,
      insumoPrecioCosto: map['insumo_precio_costo'] != null
          ? (map['insumo_precio_costo'] as num).toDouble()
          : null,
    );
  }
}
