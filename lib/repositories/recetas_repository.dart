import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/receta.dart';

class RecetasRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Receta>> getRecetasPorProductoPadre(int productoPadreId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT 
        r.id,
        r.producto_padre_id,
        r.insumo_id,
        r.cantidad_requerida,
        p.nombre AS insumo_nombre,
        p.unidad_medida AS insumo_unidad_medida,
        COALESCE(NULLIF(p.costo_calculado_cache, 0.0), p.precio_costo) AS insumo_precio_costo
      FROM recetas r
      JOIN productos p ON p.id = r.insumo_id
      WHERE r.producto_padre_id = ?
      ORDER BY p.nombre ASC
    ''', [productoPadreId]);

    return maps.map((m) => Receta.fromMap(m)).toList();
  }

  /// Valida si agregar la relación (padreId -> hijoId) provocaría un ciclo recursivo infinitas veces.
  Future<bool> detectaCiclo(int padreId, int hijoId, {Transaction? txn}) async {
    if (padreId == hijoId) return true;
    return await _esDescendiente(padreId: hijoId, objetivoId: padreId, depth: 0, txn: txn);
  }

  Future<bool> _esDescendiente({
    required int padreId,
    required int objetivoId,
    required int depth,
    Transaction? txn,
  }) async {
    if (depth > 10) return true; // Límite de seguridad
    if (padreId == objetivoId) return true;

    final db = txn ?? await _dbHelper.database;
    final res = await db.query(
      'recetas',
      columns: ['insumo_id'],
      where: 'producto_padre_id = ?',
      whereArgs: [padreId],
    );

    for (final row in res) {
      final childId = row['insumo_id'] as int;
      if (childId == objetivoId) return true;
      final subCiclo = await _esDescendiente(
        padreId: childId,
        objetivoId: objetivoId,
        depth: depth + 1,
        txn: txn,
      );
      if (subCiclo) return true;
    }
    return false;
  }

  /// Calcula el costo dinámico y recursivo de un ítem basado en sus ingredientes/componentes
  Future<double> calcularCostoRecursivo(int productoId, {Transaction? txn, int depth = 0}) async {
    if (depth > 10) return 0.0;

    final db = txn ?? await _dbHelper.database;
    final prodRows = await db.query(
      'productos',
      columns: ['tipo', 'precio_costo'],
      where: 'id = ?',
      whereArgs: [productoId],
      limit: 1,
    );

    if (prodRows.isEmpty) return 0.0;
    final tipo = (prodRows.first['tipo'] as String?) ?? 'INSUMO';
    final precioCostoPropio = (prodRows.first['precio_costo'] as num).toDouble();

    if (tipo == 'INSUMO') {
      return precioCostoPropio;
    }

    final recetas = await db.query(
      'recetas',
      columns: ['insumo_id', 'cantidad_requerida'],
      where: 'producto_padre_id = ?',
      whereArgs: [productoId],
    );

    if (recetas.isEmpty) {
      return precioCostoPropio;
    }

    double totalCosto = 0.0;
    for (final row in recetas) {
      final insumoId = row['insumo_id'] as int;
      final cantidad = (row['cantidad_requerida'] as num).toDouble();

      final costoComponente = await calcularCostoRecursivo(
        insumoId,
        txn: txn,
        depth: depth + 1,
      );
      totalCosto += (costoComponente * cantidad);
    }

    return totalCosto;
  }

  /// Guarda la receta completa para un producto y actualiza los costos en caché en cascada
  Future<void> guardarRecetaCompleta(int productoPadreId, List<Receta> items) async {
    final db = await _dbHelper.database;

    // 1. Validar ciclos antes de abrir la transacción
    for (final item in items) {
      final hayCiclo = await detectaCiclo(productoPadreId, item.insumoId);
      if (hayCiclo) {
        throw Exception(
            'No se puede agregar el componente. Se detectó una dependencia circular en las recetas.');
      }
    }

    await db.transaction((txn) async {
      await txn.delete('recetas', where: 'producto_padre_id = ?', whereArgs: [productoPadreId]);

      for (final item in items) {
        await txn.insert('recetas', {
          'producto_padre_id': productoPadreId,
          'insumo_id': item.insumoId,
          'cantidad_requerida': item.cantidadRequerida,
        });
      }

      await recalcularCostoProductoPadre(productoPadreId, txn: txn);
      await recalcularCostosCascada(productoPadreId, txn: txn);
    });
  }

  /// Recalcula y actualiza costo_calculado_cache del producto padre
  Future<double> recalcularCostoProductoPadre(int productoPadreId, {Transaction? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final nuevoCosto = await calcularCostoRecursivo(productoPadreId, txn: txn);

    await db.update(
      'productos',
      {
        'costo_calculado_cache': nuevoCosto,
        'precio_costo': nuevoCosto,
      },
      where: 'id = ?',
      whereArgs: [productoPadreId],
    );

    return nuevoCosto;
  }

  /// Recalcula en cascada todos los productos o combos que utilicen este insumo/producto como ingrediente
  Future<void> recalcularCostosCascada(int itemId, {Transaction? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final padresRows = await db.query(
      'recetas',
      columns: ['producto_padre_id'],
      where: 'insumo_id = ?',
      whereArgs: [itemId],
    );

    for (final row in padresRows) {
      final padreId = row['producto_padre_id'] as int;
      await recalcularCostoProductoPadre(padreId, txn: txn);
      await recalcularCostosCascada(padreId, txn: txn);
    }
  }
}

