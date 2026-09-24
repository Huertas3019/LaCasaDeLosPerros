import '../core/database/database_helper.dart';
import '../models/gasto.dart';

class GastosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> registrarGasto(Gasto gasto) async {
    final db = await _dbHelper.database;
    return await db.insert('gastos', gasto.toMap());
  }

  Future<List<Gasto>> getGastosPorTurno(int turnoId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'gastos',
      where: 'turno_id = ?',
      whereArgs: [turnoId],
      orderBy: 'fecha DESC',
    );
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  Future<List<Gasto>> getGastosFijos({String? fechaDesde, String? fechaHasta}) async {
    final db = await _dbHelper.database;
    List<String> whereClauses = ["tipo_transaccion = 'OPERATIVO_FIJO'"];
    List<dynamic> whereArgs = [];

    if (fechaDesde != null) {
      whereClauses.add('fecha >= ?');
      whereArgs.add(fechaDesde);
    }
    if (fechaHasta != null) {
      whereClauses.add('fecha < ?');
      whereArgs.add(fechaHasta);
    }

    final maps = await db.query(
      'gastos',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'fecha DESC',
    );
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  Future<int> deleteGasto(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'gastos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
