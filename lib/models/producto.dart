class Producto {
  final int? id;
  final int? categoriaId;
  final String nombre;
  final double precioCosto;
  final double costoCalculadoCache;
  final double? precioVentaUnitario;
  final double stockActual;
  final String unidadMedida; // 'Unidad', 'Gramos', 'Litros', etc. (Unidad Base)
  final String? unidadCompra; // 'Docena', 'Pack x6', 'Kilo', etc.
  final double factorConversion; // Cuántas unidades base equivalen a 1 unidad_compra
  final double? contenidoNeto; // ej: 473, 750, 0.5
  final String? unidadContenido; // ej: 'ml', 'L', 'cc', 'gr', 'kg'
  final bool esVendibleSolo;
  final String tipo; // 'INSUMO', 'PRODUCTO', 'COMBO'
  final bool activo;
  final String? creadoEn;
  final double? stockVirtual; // Stock calculado dinámicamente según receta (BOM)

  Producto({
    this.id,
    this.categoriaId,
    required this.nombre,
    this.precioCosto = 0.0,
    this.costoCalculadoCache = 0.0,
    this.precioVentaUnitario,
    this.stockActual = 0.0,
    this.unidadMedida = 'Unidad',
    this.unidadCompra,
    this.factorConversion = 1.0,
    this.contenidoNeto,
    this.unidadContenido,
    this.esVendibleSolo = true,
    this.tipo = 'INSUMO',
    this.activo = true,
    this.creadoEn,
    this.stockVirtual,
  });

  /// Getters de clasificación por tipo
  bool get esInsumo => tipo == 'INSUMO';
  bool get esProducto => tipo == 'PRODUCTO';
  bool get esCombo => tipo == 'COMBO';

  /// Indicar si tiene una conversión de unidad de compra distinta a la base
  bool get tieneConversionCompra =>
      unidadCompra != null && unidadCompra!.isNotEmpty && factorConversion > 1.0;

  /// Retorna el costo efectivo (usa el costo calculado en caché si es compuesto, o el precio de costo si es insumo)
  double get costoEfectivo =>
      esInsumo ? precioCosto : (costoCalculadoCache > 0 ? costoCalculadoCache : precioCosto);

  /// Nombre formateado con su presentación si aplica (ej. "Cerveza Quilmes (473 ml)")
  String get nombreConPresentacion {
    if (contenidoNeto != null && contenidoNeto! > 0 && unidadContenido != null && unidadContenido!.isNotEmpty) {
      final cantStr = (contenidoNeto! % 1 == 0)
          ? contenidoNeto!.toInt().toString()
          : contenidoNeto!.toString();
      return '$nombre ($cantStr $unidadContenido)';
    }
    return nombre;
  }

  /// Stock a mostrar (usa el virtual calculado por receta si existe, o el real en su defecto)
  double get displayStock => stockVirtual ?? stockActual;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'precio_costo': precioCosto,
      'costo_calculado_cache': costoCalculadoCache,
      'precio_venta_unitario': precioVentaUnitario,
      'stock_actual': stockActual,
      'unidad_medida': unidadMedida,
      'unidad_compra': unidadCompra,
      'factor_conversion': factorConversion,
      'contenido_neto': contenidoNeto,
      'unidad_contenido': unidadContenido,
      'es_vendible_solo': esVendibleSolo ? 1 : 0,
      'tipo': tipo,
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
      costoCalculadoCache: (map['costo_calculado_cache'] as num?)?.toDouble() ?? 0.0,
      precioVentaUnitario: map['precio_venta_unitario'] != null
          ? (map['precio_venta_unitario'] as num).toDouble()
          : null,
      stockActual: (map['stock_actual'] as num).toDouble(),
      unidadMedida: (map['unidad_medida'] as String?) ?? 'Unidad',
      unidadCompra: map['unidad_compra'] as String?,
      factorConversion: (map['factor_conversion'] as num?)?.toDouble() ?? 1.0,
      contenidoNeto: map['contenido_neto'] != null ? (map['contenido_neto'] as num).toDouble() : null,
      unidadContenido: map['unidad_contenido'] as String?,
      esVendibleSolo: (map['es_vendible_solo'] as int? ?? 1) == 1,
      tipo: (map['tipo'] as String?) ?? 'INSUMO',
      activo: (map['activo'] as int? ?? 1) == 1,
      creadoEn: map['creado_en'] as String?,
      stockVirtual: map['stock_virtual'] != null ? (map['stock_virtual'] as num).toDouble() : null,
    );
  }

  Producto copyWith({
    int? id,
    int? categoriaId,
    String? nombre,
    double? precioCosto,
    double? costoCalculadoCache,
    double? precioVentaUnitario,
    double? stockActual,
    String? unidadMedida,
    String? unidadCompra,
    double? factorConversion,
    double? contenidoNeto,
    String? unidadContenido,
    bool? esVendibleSolo,
    String? tipo,
    bool? activo,
    String? creadoEn,
    double? stockVirtual,
  }) {
    return Producto(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      precioCosto: precioCosto ?? this.precioCosto,
      costoCalculadoCache: costoCalculadoCache ?? this.costoCalculadoCache,
      precioVentaUnitario: precioVentaUnitario ?? this.precioVentaUnitario,
      stockActual: stockActual ?? this.stockActual,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      unidadCompra: unidadCompra ?? this.unidadCompra,
      factorConversion: factorConversion ?? this.factorConversion,
      contenidoNeto: contenidoNeto ?? this.contenidoNeto,
      unidadContenido: unidadContenido ?? this.unidadContenido,
      esVendibleSolo: esVendibleSolo ?? this.esVendibleSolo,
      tipo: tipo ?? this.tipo,
      activo: activo ?? this.activo,
      creadoEn: creadoEn ?? this.creadoEn,
      stockVirtual: stockVirtual ?? this.stockVirtual,
    );
  }
}
