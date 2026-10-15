import '../core/database/database_helper.dart';
import '../models/producto.dart';
import 'recetas_repository.dart';

class ProductosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Producto>> getProductos({
    bool soloActivos = true,
    bool? soloVendibles,
    String? tipo,
  }) async {
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

    if (tipo != null && tipo.isNotEmpty) {
      whereClauses.add('tipo = ?');
      whereArgs.add(tipo);
    }

    String? whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final maps = await db.query(
      'productos',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'nombre ASC',
    );

    final List<Producto> productos = maps.map((m) => Producto.fromMap(m)).toList();
    return await _calculateVirtualStock(productos);
  }

  Future<List<Producto>> getProductosPorCategoria(int categoriaId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'productos',
      where: 'categoria_id = ? AND activo = 1 AND es_vendible_solo = 1',
      whereArgs: [categoriaId],
      orderBy: 'nombre ASC',
    );
    final productos = maps.map((m) => Producto.fromMap(m)).toList();
    return await _calculateVirtualStock(productos);
  }

  Future<Producto?> getProductoPorId(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final p = Producto.fromMap(maps.first);
      final res = await _calculateVirtualStock([p]);
      return res.first;
    }
    return null;
  }

  Future<int> insertProducto(Producto producto) async {
    final db = await _dbHelper.database;
    final id = await db.insert('productos', producto.toMap());

    if (producto.esInsumo) {
      // Si es un insumo recién creado con precio costo, asegurarse de fijar el cache
      await db.update(
        'productos',
        {'costo_calculado_cache': producto.precioCosto},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    return id;
  }

  Future<int> updateProducto(Producto producto) async {
    final db = await _dbHelper.database;
    final result = await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );

    if (producto.id != null) {
      if (producto.esInsumo) {
        await db.update(
          'productos',
          {'costo_calculado_cache': producto.precioCosto},
          where: 'id = ?',
          whereArgs: [producto.id],
        );
      }
      // Al actualizar precio/costo del producto o insumo, recalcular cascada de dependientes
      await RecetasRepository().recalcularCostosCascada(producto.id!);
    }

    return result;
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

  Future<int> deleteProducto(int id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Eliminar recetas donde sea producto padre o insumo hijo
      await txn.delete('recetas', where: 'producto_padre_id = ? OR insumo_id = ?', whereArgs: [id, id]);

      // 2. Verificar si tiene ventas históricas asociadas
      final ventasRelacionadas = await txn.rawQuery(
        'SELECT COUNT(*) as cant FROM venta_detalles WHERE producto_id = ?',
        [id],
      );
      final int cantVentas = (ventasRelacionadas.first['cant'] as int?) ?? 0;

      if (cantVentas > 0) {
        // Para preservar la integridad histórica y contable de las ventas, hacemos soft-delete (activo = 0)
        return await txn.update('productos', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
      } else {
        // Si no tiene ventas históricas, eliminar sus registros de auditoría de ajustes
        await txn.delete('ajustes_inventario', where: 'insumo_id = ?', whereArgs: [id]);
        // Y eliminar definitivamente el producto de la base de datos
        return await txn.delete('productos', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  // --- Método privado para calcular stock virtual recursivo ---
  Future<List<Producto>> _calculateVirtualStock(List<Producto> productos) async {
    List<Producto> result = [];

    for (var p in productos) {
      if (p.esInsumo) {
        result.add(p.copyWith(stockVirtual: p.stockActual));
      } else {
        final stockCalculado = await _obtenerStockDisponibleRecursivo(p.id!);
        result.add(p.copyWith(stockVirtual: stockCalculado));
      }
    }
    return result;
  }

  Future<double> _obtenerStockDisponibleRecursivo(int itemId, {int depth = 0}) async {
    if (depth > 10) return 0.0;
    final db = await _dbHelper.database;

    final prodMap = await db.query(
      'productos',
      columns: ['tipo', 'stock_actual'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (prodMap.isEmpty) return 0.0;

    final tipo = (prodMap.first['tipo'] as String?) ?? 'INSUMO';
    final stockActual = (prodMap.first['stock_actual'] as num).toDouble();

    if (tipo == 'INSUMO') {
      return stockActual;
    }

    final recetas = await db.query(
      'recetas',
      columns: ['insumo_id', 'cantidad_requerida'],
      where: 'producto_padre_id = ?',
      whereArgs: [itemId],
    );

    if (recetas.isEmpty) {
      return stockActual;
    }

    double? minStock;
    for (final r in recetas) {
      final childId = r['insumo_id'] as int;
      final cantReq = (r['cantidad_requerida'] as num).toDouble();
      if (cantReq <= 0) continue;

      final childStock = await _obtenerStockDisponibleRecursivo(childId, depth: depth + 1);
      final posibles = (childStock / cantReq).floorToDouble();

      if (minStock == null || posibles < minStock) {
        minStock = posibles;
      }
    }

    return minStock ?? 0.0;
  }
}

