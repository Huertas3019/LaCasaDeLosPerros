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
        p.precio_costo AS insumo_precio_costo
      FROM recetas r
      JOIN productos p ON p.id = r.insumo_id
      WHERE r.producto_padre_id = ?
      ORDER BY p.nombre ASC
    ''', [productoPadreId]);

    return maps.map((m) => Receta.fromMap(m)).toList();
  }

  Future<int> insertReceta(Receta receta) async {
    final db = await _dbHelper.database;
    return await db.insert('recetas', receta.toMap());
  }

  Future<int> updateReceta(Receta receta) async {
    final db = await _dbHelper.database;
    return await db.update(
      'recetas',
      receta.toMap(),
      where: 'id = ?',
      whereArgs: [receta.id],
    );
  }

  Future<int> deleteReceta(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'recetas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Guardar la receta completa atómicamente y actualizar costo del padre
  Future<void> guardarRecetaCompleta(int productoPadreId, List<Receta> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('recetas', where: 'producto_padre_id = ?', whereArgs: [productoPadreId]);
      for (final item in items) {
        await txn.insert('recetas', {
          'producto_padre_id': productoPadreId,
          'insumo_id': item.insumoId,
          'cantidad_requerida': item.cantidadRequerida,
        });
      }
      final res = await txn.rawQuery('''
        SELECT COALESCE(SUM(r.cantidad_requerida * p.precio_costo), 0.0) AS costo_total
        FROM recetas r
        JOIN productos p ON p.id = r.insumo_id
        WHERE r.producto_padre_id = ?
      ''', [productoPadreId]);
      final double costoCalculado = (res.first['costo_total'] as num?)?.toDouble() ?? 0.0;
      await txn.update(
        'productos',
        {'precio_costo': costoCalculado},
        where: 'id = ?',
        whereArgs: [productoPadreId],
      );
    });
  }

  // Recalcular y actualizar el precio de costo del producto padre en base a sus recetas
  Future<void> recalcularCostoProductoPadre(int productoPadreId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(r.cantidad_requerida * p.precio_costo), 0.0) AS costo_total
      FROM recetas r
      JOIN productos p ON p.id = r.insumo_id
      WHERE r.producto_padre_id = ?
    ''', [productoPadreId]);

    double nuevoCosto = (res.first['costo_total'] as num?)?.toDouble() ?? 0.0;

    await db.update(
      'productos',
      {'precio_costo': nuevoCosto},
      where: 'id = ?',
      whereArgs: [productoPadreId],
    );
  }
}
