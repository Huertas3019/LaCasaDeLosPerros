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
        version: 3,
        onConfigure: _onConfigure,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: 3,
        onConfigure: _onConfigure,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE productos ADD COLUMN contenido_neto REAL');
      await db.execute('ALTER TABLE productos ADD COLUMN unidad_contenido TEXT');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE productos ADD COLUMN tipo TEXT NOT NULL DEFAULT 'INSUMO'");
      await db.execute("ALTER TABLE productos ADD COLUMN costo_calculado_cache REAL NOT NULL DEFAULT 0.0");
      await db.execute("ALTER TABLE productos ADD COLUMN unidad_compra TEXT");
      await db.execute("ALTER TABLE productos ADD COLUMN factor_conversion REAL NOT NULL DEFAULT 1.0");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ajustes_inventario (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          insumo_id INTEGER NOT NULL,
          cantidad REAL NOT NULL,
          cantidad_ingresada REAL NOT NULL,
          unidad_ingreso TEXT NOT NULL,
          factor_conversion_usado REAL NOT NULL DEFAULT 1.0,
          tipo_ajuste TEXT NOT NULL CHECK (tipo_ajuste IN ('MERMA','ROBO','DONACION','CORRECCION','INGRESO_MANUAL')),
          costo_unitario_historico REAL NOT NULL DEFAULT 0.0,
          motivo TEXT,
          usuario_id INTEGER,
          fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (insumo_id) REFERENCES productos(id) ON DELETE RESTRICT
        )
      ''');

      // Migrar tipificación basada en recetas existentes
      final padres = await db.rawQuery('SELECT DISTINCT producto_padre_id FROM recetas');
      final hashSetPadres = padres.map((e) => e['producto_padre_id'] as int).toSet();

      for (final padreId in hashSetPadres) {
        final hijos = await db.rawQuery(
          'SELECT insumo_id FROM recetas WHERE producto_padre_id = ?',
          [padreId],
        );
        final hijosIds = hijos.map((e) => e['insumo_id'] as int).toSet();

        final esCombo = hijosIds.any((hijoId) => hashSetPadres.contains(hijoId));
        final tipo = esCombo ? 'COMBO' : 'PRODUCTO';

        await db.update(
          'productos',
          {'tipo': tipo},
          where: 'id = ?',
          whereArgs: [padreId],
        );
      }

      // Rellenar costo_calculado_cache inicial para insumos
      await db.execute("UPDATE productos SET costo_calculado_cache = precio_costo WHERE tipo = 'INSUMO'");
    }
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
        costo_calculado_cache REAL NOT NULL DEFAULT 0.0,
        precio_venta_unitario REAL,
        stock_actual REAL NOT NULL DEFAULT 0.0,
        unidad_medida TEXT NOT NULL DEFAULT 'Unidad',
        unidad_compra TEXT,
        factor_conversion REAL NOT NULL DEFAULT 1.0,
        contenido_neto REAL,
        unidad_contenido TEXT,
        es_vendible_solo INTEGER NOT NULL DEFAULT 1,
        tipo TEXT NOT NULL DEFAULT 'INSUMO',
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

    // 4. Ajustes de Inventario
    await db.execute('''
      CREATE TABLE ajustes_inventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        insumo_id INTEGER NOT NULL,
        cantidad REAL NOT NULL,
        cantidad_ingresada REAL NOT NULL,
        unidad_ingreso TEXT NOT NULL,
        factor_conversion_usado REAL NOT NULL DEFAULT 1.0,
        tipo_ajuste TEXT NOT NULL CHECK (tipo_ajuste IN ('MERMA','ROBO','DONACION','CORRECCION','INGRESO_MANUAL')),
        costo_unitario_historico REAL NOT NULL DEFAULT 0.0,
        motivo TEXT,
        usuario_id INTEGER,
        fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (insumo_id) REFERENCES productos(id) ON DELETE RESTRICT
      )
    ''');

    // 5. Turnos
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

    // 6. Gastos
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

    // 7. Ventas
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

    // 8. Venta Detalles
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

    // Cargar datos iniciales de semillas (o dejar limpio si está configurado)
    await _seedInitialData(db);
  }

  /// Vacía por completo todas las tablas de la base de datos
  Future<void> vaciarBaseDeDatos() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('venta_detalles');
      await txn.delete('ventas');
      await txn.delete('gastos');
      await txn.delete('turnos');
      await txn.delete('ajustes_inventario');
      await txn.delete('recetas');
      await txn.delete('productos');
      await txn.delete('categorias');
    });
  }

  Future<void> _seedInitialData(Database db) async {
    // Las tablas quedan completamente vacías para un inicio limpio en producción.
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
