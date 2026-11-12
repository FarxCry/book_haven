import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Chrome / web: sqlite runs in WebAssembly (needs web/sqlite3.wasm).
Future<void> initDbFactory() async {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  await databaseFactory.setDatabasesPath('/');
}
