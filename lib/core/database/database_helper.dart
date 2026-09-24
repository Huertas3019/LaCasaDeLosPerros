import 'package:sqflite/sqflite.dart';
import 'db_platform.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lacasa_perros_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    try {
      initDesktopFFI();
      final path = await getDatabasePath(fileName);

      return await openDatabase(
        path,
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _createDB,
      );
    } catch (e) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: _onConfigure,
        onCreate: _createDB,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Categorías
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        creado_en TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Productos e Insumos
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER,
        nombre TEXT NOT NULL,
        precio_costo REAL NOT NULL DEFAULT 0.0,
        precio_venta_unitario REAL,
        stock_actual REAL NOT NULL DEFAULT 0.0,
        unidad_medida TEXT NOT NULL DEFAULT 'Unidad',
        es_vendible_solo INTEGER NOT NULL DEFAULT 1,
        activo INTEGER NOT NULL DEFAULT 1,
        creado_en TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON DELETE SET NULL
      )
    ''');

    // 3. Recetas (BOM)
    await db.execute('''
      CREATE TABLE recetas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_padre_id INTEGER NOT NULL,
        insumo_id INTEGER NOT NULL,
        cantidad_requerida REAL NOT NULL,
        UNIQUE(producto_padre_id, insumo_id),
        FOREIGN KEY (producto_padre_id) REFERENCES productos(id) ON DELETE CASCADE,
        FOREIGN KEY (insumo_id) REFERENCES productos(id) ON DELETE RESTRICT
      )
    ''');

    // 4. Turnos
    await db.execute('''
      CREATE TABLE turnos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha_inicio TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        fecha_fin TEXT,
        monto_inicial_efectivo REAL NOT NULL DEFAULT 0.0,
        efectivo_real_cierre REAL,
        transferencia_real_cierre REAL,
        efectivo_esperado_cierre REAL,
        transferencia_esperada_cierre REAL,
        diferencia_efectivo REAL,
        diferencia_transferencia REAL,
        estado TEXT NOT NULL DEFAULT 'ABIERTO' CHECK (estado IN ('ABIERTO', 'CERRADO')),
        observaciones TEXT
      )
    ''');

    // 5. Gastos
    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        turno_id INTEGER,
        descripcion TEXT NOT NULL,
        monto REAL NOT NULL,
        tipo_transaccion TEXT NOT NULL CHECK (tipo_transaccion IN ('OPERATIVO_FIJO', 'CAJA_TURNO', 'RETIRO_CAJA')),
        medio_pago TEXT NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TRANSFERENCIA')),
        fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (turno_id) REFERENCES turnos(id) ON DELETE SET NULL
      )
    ''');

    // 6. Ventas
    await db.execute('''
      CREATE TABLE ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        turno_id INTEGER NOT NULL,
        fecha_hora TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        monto_efectivo REAL NOT NULL DEFAULT 0.0,
        monto_transferencia REAL NOT NULL DEFAULT 0.0,
        total_venta REAL NOT NULL,
        costo_total_estimado REAL NOT NULL DEFAULT 0.0,
        estado TEXT NOT NULL DEFAULT 'COMPLETADA' CHECK (estado IN ('COMPLETADA', 'ANULADA')),
        FOREIGN KEY (turno_id) REFERENCES turnos(id) ON DELETE RESTRICT
      )
    ''');

    // 7. Venta Detalles
    await db.execute('''
      CREATE TABLE venta_detalles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL CHECK (cantidad > 0),
        precio_unitario REAL NOT NULL,
        costo_unitario_historico REAL NOT NULL DEFAULT 0.0,
        subtotal REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
      )
    ''');

    // Cargar datos iniciales de semillas (Categorías por defecto)
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final catCombosId = await db.insert('categorias', {'nombre': 'Combos'});
    final catPanchosId = await db.insert('categorias', {'nombre': 'Panchos'});
    final catBebidasId = await db.insert('categorias', {'nombre': 'Bebidas'});
    final catInsumosId = await db.insert('categorias', {'nombre': 'Insumos / Ingredientes'});

    // Insumos base
    final panId = await db.insert('productos', {
      'categoria_id': catInsumosId,
      'nombre': 'Pan de Pancho (Unidad)',
      'precio_costo': 150.0,
      'precio_venta_unitario': null,
      'stock_actual': 100.0,
      'unidad_medida': 'Unidad',
      'es_vendible_solo': 0,
      'activo': 1,
    });

    final salchichaId = await db.insert('productos', {
      'categoria_id': catInsumosId,
      'nombre': 'Salchicha Parrillera (Unidad)',
      'precio_costo': 300.0,
      'precio_venta_unitario': null,
      'stock_actual': 100.0,
      'unidad_medida': 'Unidad',
      'es_vendible_solo': 0,
      'activo': 1,
    });

    final cocaId = await db.insert('productos', {
      'categoria_id': catBebidasId,
      'nombre': 'Coca-Cola 500ml',
      'precio_costo': 800.0,
      'precio_venta_unitario': 1800.0,
      'stock_actual': 50.0,
      'unidad_medida': 'Unidad',
      'es_vendible_solo': 1,
      'activo': 1,
    });

    // Producto Final / Combo: Super Pancho
    final superPanchoId = await db.insert('productos', {
      'categoria_id': catPanchosId,
      'nombre': 'Super Pancho Especial',
      'precio_costo': 450.0, // 150 + 300
      'precio_venta_unitario': 2500.0,
      'stock_actual': 0.0,
      'unidad_medida': 'Unidad',
      'es_vendible_solo': 1,
      'activo': 1,
    });

    // Receta para Super Pancho Especial (1 Pan + 1 Salchicha)
    await db.insert('recetas', {
      'producto_padre_id': superPanchoId,
      'insumo_id': panId,
      'cantidad_requerida': 1.0,
    });
    await db.insert('recetas', {
      'producto_padre_id': superPanchoId,
      'insumo_id': salchichaId,
      'cantidad_requerida': 1.0,
    });

    // Combo 1 (Super Pancho + Coca-Cola)
    final combo1Id = await db.insert('productos', {
      'categoria_id': catCombosId,
      'nombre': 'Combo 1 (Super Pancho + Coca-Cola)',
      'precio_costo': 1250.0, // 450 + 800
      'precio_venta_unitario': 3900.0,
      'stock_actual': 0.0,
      'unidad_medida': 'Unidad',
      'es_vendible_solo': 1,
      'activo': 1,
    });

    // Receta Combo 1 (1 Pan + 1 Salchicha + 1 Coca-Cola)
    await db.insert('recetas', {
      'producto_padre_id': combo1Id,
      'insumo_id': panId,
      'cantidad_requerida': 1.0,
    });
    await db.insert('recetas', {
      'producto_padre_id': combo1Id,
      'insumo_id': salchichaId,
      'cantidad_requerida': 1.0,
    });
    await db.insert('recetas', {
      'producto_padre_id': combo1Id,
      'insumo_id': cocaId,
      'cantidad_requerida': 1.0,
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
