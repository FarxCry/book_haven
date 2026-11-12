// Picks the right database setup per platform without breaking other builds.
export 'db_factory_stub.dart' if (dart.library.js_interop) 'db_factory_web.dart';
