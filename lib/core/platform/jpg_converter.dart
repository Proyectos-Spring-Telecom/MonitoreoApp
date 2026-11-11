/// Convierte a JPG las imágenes que el API no acepta (p. ej. WEBP). En el
/// teléfono usa un isolate; en el navegador, el canvas (nativo y sin
/// congelar la pantalla, porque en web no hay isolates).
library;

export 'jpg_converter_io.dart'
    if (dart.library.js_interop) 'jpg_converter_web.dart';
