import 'dart:io';

import 'package:conectamarket/repositories/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory? _tempDir;
String? _dbPath;
bool _ffiReady = false;

/// Prepara SQLite sobre FFI (escritorio, sin emulador) y apunta el
/// DatabaseHelper a una base temporal vacía para la prueba en curso.
Future<void> setUpTestDatabase() async {
  // La factory es global: se instala una sola vez para no repetir el aviso
  // de sqflite en cada prueba.
  if (!_ffiReady) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }

  _tempDir = await Directory.systemTemp.createTemp('conectamarket_test_');
  _dbPath = '${_tempDir!.path}${Platform.pathSeparator}test.db';
  await DatabaseHelper.resetForTesting(path: _dbPath);
}

/// Cierra la conexión y borra los archivos temporales de la prueba.
Future<void> tearDownTestDatabase() async {
  // Se conserva la ruta de prueba para que ningún acceso rezagado toque la
  // base real del dispositivo.
  await DatabaseHelper.resetForTesting(path: _dbPath);

  final dir = _tempDir;
  _tempDir = null;
  if (dir != null && await dir.exists()) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // En Windows el archivo puede quedar bloqueado un instante: no es
      // relevante para el resultado de la prueba.
    }
  }
}
