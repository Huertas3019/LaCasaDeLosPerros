import '../core/database/database_helper.dart';
import '../models/venta.dart';
import '../models/venta_detalle.dart';

class BalancePeriodico {
  final double ingresosTotales;
  final double costoTotalInsumos;
  final double gananciaBruta;
  final double gastosDeTurno;
  final double totalGastosFijos;
  final double gananciaNetaFinal;

  BalancePeriodico({
    required this.ingresosTotales,
    required this.costoTotalInsumos,
    required this.gananciaBruta,
    required this.gastosDeTurno,
    required this.totalGastosFijos,
    required this.gananciaNetaFinal,
  });
}

class VentasRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Registrar venta con transacción atómica y descuento automático de stock por receta (BOM)
  Future<int> registrarVenta({
    required int turnoId,
    required double montoEfectivo,
    required double montoTransferencia,
    required List<VentaDetalle> items,
  }) async {
    final db = await _dbHelper.database;
    final totalVenta = montoEfectivo + montoTransferencia;
    final now = DateTime.now().toIso8601String();

    int ventaId = 0;

    await db.transaction((txn) async {
      double costoTotalEstimadoVenta = 0.0;
      List<Map<String, dynamic>> renglonesAInsertar = [];

      // 1. Calcular costo histórico congelado por cada producto/renglón
      for (var item in items) {
        // Obtener costo unitario del producto
        final prodMaps = await txn.query(
          'productos',
          columns: ['precio_costo', 'es_vendible_solo'],
          where: 'id = ?',
          whereArgs: [item.productoId],
        );

        double costoUnitarioProd = 0.0;
        if (prodMaps.isNotEmpty) {
          costoUnitarioProd = (prodMaps.first['precio_costo'] as num).toDouble();
        }

        double subtotalCostoItem = costoUnitarioProd * item.cantidad;
        costoTotalEstimadoVenta += subtotalCostoItem;

        renglonesAInsertar.add({
          'producto_id': item.productoId,
          'cantidad': item.cantidad,
          'precio_unitario': item.precioUnitario,
          'costo_unitario_historico': costoUnitarioProd,
          'subtotal': item.subtotal,
        });
      }

      // 2. Insertar cabecera de la venta
      ventaId = await txn.insert('ventas', {
        'turno_id': turnoId,
        'fecha_hora': now,
        'monto_efectivo': montoEfectivo,
        'monto_transferencia': montoTransferencia,
        'total_venta': totalVenta,
        'costo_total_estimado': costoTotalEstimadoVenta,
        'estado': 'COMPLETADA',
      });

      // 3. Insertar detalles y aplicar descuento de stock por receta
      for (var renglon in renglonesAInsertar) {
        renglon['venta_id'] = ventaId;
        await txn.insert('venta_detalles', renglon);

        int productoId = renglon['producto_id'] as int;
        int cantidadVendida = renglon['cantidad'] as int;

        // Buscar si el producto tiene receta (BOM)
        final recetas = await txn.query(
          'recetas',
          where: 'producto_padre_id = ?',
          whereArgs: [productoId],
        );

        if (recetas.isNotEmpty) {
          // Si tiene receta, descontar del stock de los insumos
          for (var r in recetas) {
            int insumoId = r['insumo_id'] as int;
            double cantidadRequerida = (r['cantidad_requerida'] as num).toDouble();
            double cantidadTotalADescontar = cantidadRequerida * cantidadVendida;

            await txn.rawUpdate(
              'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
              [cantidadTotalADescontar, insumoId],
            );
          }
        } else {
          // Si no tiene receta (es un producto individual directo sin receta), descontar directamente su stock
          await txn.rawUpdate(
            'UPDATE productos SET stock_actual = stock_actual - ? WHERE id = ?',
            [cantidadVendida.toDouble(), productoId],
          );
        }
      }
    });

    return ventaId;
  }

  // Anular venta con reversión automática de stock
  Future<void> anularVenta(int ventaId) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Obtener la venta
      final ventasMaps = await txn.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
      if (ventasMaps.isEmpty) return;

      final ventaMap = ventasMaps.first;
      if (ventaMap['estado'] == 'ANULADA') return; // Ya estaba anulada

      // 2. Marcar como ANULADA
      await txn.update(
        'ventas',
        {'estado': 'ANULADA'},
        where: 'id = ?',
        whereArgs: [ventaId],
      );

      // 3. Obtener renglones de detalle
      final detallesMaps = await txn.query('venta_detalles', where: 'venta_id = ?', whereArgs: [ventaId]);

      for (var d in detallesMaps) {
        int productoId = d['producto_id'] as int;
        int cantidadVendida = d['cantidad'] as int;

        // Revertir stock según recetas o directo
        final recetas = await txn.query('recetas', where: 'producto_padre_id = ?', whereArgs: [productoId]);

        if (recetas.isNotEmpty) {
          for (var r in recetas) {
            int insumoId = r['insumo_id'] as int;
            double cantidadRequerida = (r['cantidad_requerida'] as num).toDouble();
            double cantidadTotalARevertir = cantidadRequerida * cantidadVendida;

            await txn.rawUpdate(
              'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
              [cantidadTotalARevertir, insumoId],
            );
          }
        } else {
          await txn.rawUpdate(
            'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
            [cantidadVendida.toDouble(), productoId],
          );
        }
      }
    });
  }

  // Obtener ventas de un turno con sus detalles
  Future<List<Venta>> getVentasPorTurno(int turnoId) async {
    final db = await _dbHelper.database;
    final ventasMaps = await db.query(
      'ventas',
      where: 'turno_id = ?',
      whereArgs: [turnoId],
      orderBy: 'id DESC',
    );

    List<Venta> listaVentas = [];
    for (var vMap in ventasMaps) {
      int vId = vMap['id'] as int;
      final detMaps = await db.rawQuery('''
        SELECT vd.*, p.nombre AS producto_nombre
        FROM venta_detalles vd
        JOIN productos p ON p.id = vd.producto_id
        WHERE vd.venta_id = ?
      ''', [vId]);

      final detalles = detMaps.map((d) => VentaDetalle.fromMap(d)).toList();
      listaVentas.add(Venta.fromMap(vMap, detalles: detalles));
    }

    return listaVentas;
  }

  // Cálculo de Ganancia Neta Periódica (Consulta 4.B)
  Future<BalancePeriodico> obtenerBalancePeriodico({
    required String fechaDesde,
    required String fechaHasta,
  }) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      WITH ResumenTurnosPeriodo AS (
          SELECT 
              t.id AS turno_id,
              COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.total_venta ELSE 0 END), 0) AS total_ventas_turno,
              COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.costo_total_estimado ELSE 0 END), 0) AS costo_insumos_turno,
              COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO'), 0) AS gastos_caja_turno
          FROM turnos t
          LEFT JOIN ventas v ON v.turno_id = t.id
          WHERE t.fecha_inicio >= ? 
            AND t.fecha_inicio <  ?
          GROUP BY t.id
      ),
      GastosFijosPeriodo AS (
          SELECT 
              COALESCE(SUM(monto), 0) AS total_gastos_fijos
          FROM gastos
          WHERE turno_id IS NULL 
            AND tipo_transaccion = 'OPERATIVO_FIJO'
            AND fecha >= ? 
            AND fecha <  ?
      )
      SELECT 
          COALESCE(SUM(rt.total_ventas_turno), 0) AS ingresos_totales,
          COALESCE(SUM(rt.costo_insumos_turno), 0) AS costo_total_insumos,
          (COALESCE(SUM(rt.total_ventas_turno), 0) - COALESCE(SUM(rt.costo_insumos_turno), 0)) AS ganancia_bruta,
          COALESCE(SUM(rt.gastos_caja_turno), 0) AS gastos_de_turno,
          COALESCE(MAX(gf.total_gastos_fijos), 0) AS total_gastos_fijos,
          (
              (COALESCE(SUM(rt.total_ventas_turno), 0) - COALESCE(SUM(rt.costo_insumos_turno), 0)) - 
              (COALESCE(SUM(rt.gastos_caja_turno), 0) + COALESCE(MAX(gf.total_gastos_fijos), 0))
          ) AS ganancia_neta_final
      FROM ResumenTurnosPeriodo rt
      CROSS JOIN GastosFijosPeriodo gf;
    ''', [fechaDesde, fechaHasta, fechaDesde, fechaHasta]);

    if (maps.isEmpty) {
      return BalancePeriodico(
        ingresosTotales: 0,
        costoTotalInsumos: 0,
        gananciaBruta: 0,
        gastosDeTurno: 0,
        totalGastosFijos: 0,
        gananciaNetaFinal: 0,
      );
    }

    final m = maps.first;
    return BalancePeriodico(
      ingresosTotales: (m['ingresos_totales'] as num).toDouble(),
      costoTotalInsumos: (m['costo_total_insumos'] as num).toDouble(),
      gananciaBruta: (m['ganancia_bruta'] as num).toDouble(),
      gastosDeTurno: (m['gastos_de_turno'] as num).toDouble(),
      totalGastosFijos: (m['total_gastos_fijos'] as num).toDouble(),
      gananciaNetaFinal: (m['ganancia_neta_final'] as num).toDouble(),
    );
  }
}
