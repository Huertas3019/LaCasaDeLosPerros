class Producto {
  final int? id;
  final int? categoriaId;
  final String nombre;
  final double precioCosto;
  final double? precioVentaUnitario;
  final double stockActual;
  final String unidadMedida; // 'Unidad', 'Gramos', 'Litros', etc.
  final bool esVendibleSolo;
  final bool activo;
  final String? creadoEn;

  Producto({
    this.id,
    this.categoriaId,
    required this.nombre,
    this.precioCosto = 0.0,
    this.precioVentaUnitario,
    this.stockActual = 0.0,
    this.unidadMedida = 'Unidad',
    this.esVendibleSolo = true,
    this.activo = true,
    this.creadoEn,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'precio_costo': precioCosto,
      'precio_venta_unitario': precioVentaUnitario,
      'stock_actual': stockActual,
      'unidad_medida': unidadMedida,
      'es_vendible_solo': esVendibleSolo ? 1 : 0,
      'activo': activo ? 1 : 0,
      if (creadoEn != null) 'creado_en': creadoEn,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      categoriaId: map['categoria_id'] as int?,
      nombre: map['nombre'] as String,
      precioCosto: (map['precio_costo'] as num).toDouble(),
      precioVentaUnitario: map['precio_venta_unitario'] != null
          ? (map['precio_venta_unitario'] as num).toDouble()
          : null,
      stockActual: (map['stock_actual'] as num).toDouble(),
      unidadMedida: (map['unidad_medida'] as String?) ?? 'Unidad',
      esVendibleSolo: (map['es_vendible_solo'] as int) == 1,
      activo: (map['activo'] as int) == 1,
      creadoEn: map['creado_en'] as String?,
    );
  }

  Producto copyWith({
    int? id,
    int? categoriaId,
    String? nombre,
    double? precioCosto,
    double? precioVentaUnitario,
    double? stockActual,
    String? unidadMedida,
    bool? esVendibleSolo,
    bool? activo,
    String? creadoEn,
  }) {
    return Producto(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      precioCosto: precioCosto ?? this.precioCosto,
      precioVentaUnitario: precioVentaUnitario ?? this.precioVentaUnitario,
      stockActual: stockActual ?? this.stockActual,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      esVendibleSolo: esVendibleSolo ?? this.esVendibleSolo,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
