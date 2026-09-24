import '../core/database/database_helper.dart';
import '../models/categoria.dart';

class CategoriasRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Categoria>> getCategorias() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categorias', orderBy: 'nombre ASC');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }

  Future<int> insertCategoria(Categoria categoria) async {
    final db = await _dbHelper.database;
    return await db.insert('categorias', categoria.toMap());
  }

  Future<int> updateCategoria(Categoria categoria) async {
    final db = await _dbHelper.database;
    return await db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  Future<int> deleteCategoria(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
