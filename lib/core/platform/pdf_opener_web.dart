import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga el PDF desde el navegador. Una descarga no la bloquea el
/// navegador aunque ocurra después de esperar al servidor (una ventana nueva
/// sí).
Future<bool> openPdf(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Se libera después: Safari necesita la URL mientras arranca la descarga.
  Future<void>.delayed(const Duration(minutes: 1), () {
    web.URL.revokeObjectURL(url);
  });
  return true;
}
