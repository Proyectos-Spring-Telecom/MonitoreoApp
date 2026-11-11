/// Abre un PDF descargado. En el teléfono usa el visor del sistema; en el
/// navegador lo guarda como descarga.
library;

export 'pdf_opener_io.dart' if (dart.library.js_interop) 'pdf_opener_web.dart';
