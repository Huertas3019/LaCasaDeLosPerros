import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';

class BackupRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Exportar copia de seguridad y abrir diálogo nativo para compartir por WhatsApp, Drive, etc.
  Future<void> exportarYCompartirBackup() async {
    // 1. Asegurar que la base de datos esté sincronizada y abierta
    final db = await _dbHelper.database;
    await db.execute('VACUUM'); // Optimizar y limpiar archivo SQLite

    // 2. Obtener ruta de la base de datos actual
    String originalPath;
    if (Platform.isAndroid || Platform.isIOS) {
      final dbFolder = await getDatabasesPath();
      originalPath = join(dbFolder, 'lacasa_perros_pos.db');
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      originalPath = join(docsDir.path, 'lacasa_perros_pos.db');
    }

    final fileOriginal = File(originalPath);
    if (!await fileOriginal.exists()) {
      throw Exception('El archivo de la base de datos no existe.');
    }

    // 3. Crear copia temporal con marca de tiempo
    final tempDir = await getTemporaryDirectory();
    final timeStamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final backupFileName = 'lacasa_perros_backup_$timeStamp.db';
    final backupPath = join(tempDir.path, backupFileName);

    await fileOriginal.copy(backupPath);

    // 4. Invocación nativa de Share Sheet para compartir por WhatsApp / Drive / Email
    await Share.shareXFiles(
      [XFile(backupPath)],
      text: 'Copia de Seguridad - La Casa de los Perros POS ($timeStamp)',
    );
  }

  // Seleccionar archivo .db e importar copia de seguridad
  Future<bool> restaurarBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'bak', 'sqlite'],
    );

    if (result == null || result.files.single.path == null) {
      return false; // El usuario canceló la selección
    }

    final selectedPath = result.files.single.path!;
    final fileImported = File(selectedPath);

    if (!await fileImported.exists()) {
      throw Exception('El archivo seleccionado no es accesible.');
    }

    // Validar que el archivo sea una base de datos SQLite válida con las tablas requeridas
    Database? testDb;
    try {
      testDb = await openReadOnlyDatabase(selectedPath);
      final tables = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toList();

      List<String> requiredTables = ['productos', 'ventas', 'turnos', 'gastos', 'recetas'];
      for (var reqTable in requiredTables) {
        if (!tableNames.contains(reqTable)) {
          throw Exception('El archivo seleccionado no corresponde a un respaldo válido de la aplicación (Falta la tabla $reqTable).');
        }
      }
    } finally {
      await testDb?.close();
    }

    // Cerrar la conexión actual
    await _dbHelper.close();

    // Sobrescribir archivo original
    String originalPath;
    if (Platform.isAndroid || Platform.isIOS) {
      final dbFolder = await getDatabasesPath();
      originalPath = join(dbFolder, 'lacasa_perros_pos.db');
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      originalPath = join(docsDir.path, 'lacasa_perros_pos.db');
    }

    await fileImported.copy(originalPath);

    // Reabrir conexión
    await _dbHelper.database;
    return true;
  }
}
