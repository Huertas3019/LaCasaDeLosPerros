import '../core/database/database_helper.dart';
import '../models/ajuste_inventario.dart';

class AjustesInventarioRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Registra un nuevo ajuste de inventario y actualiza el stock real del insumo
  Future<int> registrarAjuste(AjusteInventario ajuste) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Obtener costo actual del insumo para el historial si no viene provisto
      double costoHistorico = ajuste.costoUnitarioHistorico;
      if (costoHistorico <= 0.0) {
        final res = await txn.query(
          'productos',
          columns: ['precio_costo'],
          where: 'id = ?',
          whereArgs: [ajuste.insumoId],
          limit: 1,
        );
        if (res.isNotEmpty) {
          costoHistorico = (res.first['precio_costo'] as num).toDouble();
        }
      }

      final mapParaInsertar = ajuste.toMap();
      mapParaInsertar['costo_unitario_historico'] = costoHistorico;

      // 2. Insertar registro de auditoría
      final ajusteId = await txn.insert('ajustes_inventario', mapParaInsertar);

      // 3. Actualizar el stock actual del insumo (+ para ingreso, - para merma/robo/etc)
      await txn.rawUpdate(
        '''
        UPDATE productos 
        SET stock_actual = stock_actual + ? 
        WHERE id = ?
        ''',
        [ajuste.cantidad, ajuste.insumoId],
      );

      return ajusteId;
    });
  }

  /// Obtiene los ajustes realizados para un insumo en particular
  Future<List<AjusteInventario>> getAjustesPorInsumo(int insumoId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT a.*, p.nombre as insumo_nombre, p.unidad_medida as insumo_unidad_medida
      FROM ajustes_inventario a
      JOIN productos p ON a.insumo_id = p.id
      WHERE a.insumo_id = ?
      ORDER BY a.fecha DESC
      ''',
      [insumoId],
    );

    return res.map((map) => AjusteInventario.fromMap(map)).toList();
  }

  /// Obtiene todos los ajustes registrados históricamente
  Future<List<AjusteInventario>> getTodosLosAjustes() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT a.*, p.nombre as insumo_nombre, p.unidad_medida as insumo_unidad_medida
      FROM ajustes_inventario a
      JOIN productos p ON a.insumo_id = p.id
      ORDER BY a.fecha DESC
      ''',
    );

    return res.map((map) => AjusteInventario.fromMap(map)).toList();
  }

  /// Obtiene todos los ajustes en un rango de fechas
  Future<List<AjusteInventario>> getAjustesPorPeriodo(String fechaDesde, String fechaHasta) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT a.*, p.nombre as insumo_nombre, p.unidad_medida as insumo_unidad_medida
      FROM ajustes_inventario a
      JOIN productos p ON a.insumo_id = p.id
      WHERE a.fecha >= ? AND a.fecha <= ?
      ORDER BY a.fecha DESC
      ''',
      [fechaDesde, fechaHasta],
    );

    return res.map((map) => AjusteInventario.fromMap(map)).toList();
  }

  /// Resumen total por tipo de ajuste
  Future<Map<String, double>> getResumenAjustes(String fechaDesde, String fechaHasta) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      '''
      SELECT tipo_ajuste, SUM(cantidad * costo_unitario_historico) as total_valorized
      FROM ajustes_inventario
      WHERE fecha >= ? AND fecha <= ?
      GROUP BY tipo_ajuste
      ''',
      [fechaDesde, fechaHasta],
    );

    final Map<String, double> resultado = {};
    for (final row in res) {
      final tipo = row['tipo_ajuste'] as String;
      final total = (row['total_valorized'] as num?)?.toDouble() ?? 0.0;
      resultado[tipo] = total;
    }
    return resultado;
  }
}
