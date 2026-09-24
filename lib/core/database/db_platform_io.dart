import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDesktopFFI() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<String> getDatabasePath(String fileName) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dbPath = await getDatabasesPath();
    return join(dbPath, fileName);
  } else {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return join(docsDir.path, fileName);
    } catch (_) {
      return join(Directory.systemTemp.path, fileName);
    }
  }
}
