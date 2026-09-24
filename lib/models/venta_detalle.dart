class VentaDetalle {
  final int? id;
  final int? ventaId;
  final int productoId;
  final int cantidad;
  final double precioUnitario;
  final double costoUnitarioHistorico; // Costo congelado del producto/insumo al vender
  final double subtotal;
  final String? productoNombre; // Campo auxiliar para UI

  VentaDetalle({
    this.id,
    this.ventaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    this.costoUnitarioHistorico = 0.0,
    required this.subtotal,
    this.productoNombre,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (ventaId != null) 'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'costo_unitario_historico': costoUnitarioHistorico,
      'subtotal': subtotal,
    };
  }

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      id: map['id'] as int?,
      ventaId: map['venta_id'] as int?,
      productoId: map['producto_id'] as int,
      cantidad: map['cantidad'] as int,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      costoUnitarioHistorico: (map['costo_unitario_historico'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      productoNombre: map['producto_nombre'] as String?,
    );
  }
}
