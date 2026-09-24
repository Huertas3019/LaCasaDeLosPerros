import '../core/database/database_helper.dart';
import '../models/producto.dart';

class ProductosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Producto>> getProductos({bool soloActivos = true, bool? soloVendibles}) async {
    final db = await _dbHelper.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (soloActivos) {
      whereClauses.add('activo = 1');
    }

    if (soloVendibles != null) {
      whereClauses.add('es_vendible_solo = ?');
      whereArgs.add(soloVendibles ? 1 : 0);
    }

    String? whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'productos',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'nombre ASC',
    );

    return maps.map((m) => Producto.fromMap(m)).toList();
  }

  Future<List<Producto>> getProductosPorCategoria(int categoriaId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'productos',
      where: 'categoria_id = ? AND activo = 1 AND es_vendible_solo = 1',
      whereArgs: [categoriaId],
      orderBy: 'nombre ASC',
    );
    return maps.map((m) => Producto.fromMap(m)).toList();
  }

  Future<Producto?> getProductoPorId(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Producto.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertProducto(Producto producto) async {
    final db = await _dbHelper.database;
    return await db.insert('productos', producto.toMap());
  }

  Future<int> updateProducto(Producto producto) async {
    final db = await _dbHelper.database;
    return await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  Future<int> updateStock(int id, double deltaStock) async {
    final db = await _dbHelper.database;
    return await db.rawUpdate(
      'UPDATE productos SET stock_actual = stock_actual + ? WHERE id = ?',
      [deltaStock, id],
    );
  }

  Future<int> toggleActivoProducto(int id, bool activo) async {
    final db = await _dbHelper.database;
    return await db.update(
      'productos',
      {'activo': activo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
