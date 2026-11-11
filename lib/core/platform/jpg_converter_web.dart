import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// `null` si el navegador no puede leer la imagen.
Future<Uint8List?> convertToJpg(Uint8List bytes, {int quality = 85}) async {
  try {
    final bitmap =
        await web.window.createImageBitmap(web.Blob([bytes.toJS].toJS)).toDart;
    final canvas = web.HTMLCanvasElement()
      ..width = bitmap.width
      ..height = bitmap.height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return null;
    // Fondo blanco: el JPG no tiene transparencia.
    context
      ..fillStyle = '#FFFFFF'.toJS
      ..fillRect(0, 0, bitmap.width, bitmap.height)
      ..drawImage(bitmap, 0, 0);
    bitmap.close();

    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? blob) => completer.complete(blob)).toJS,
      'image/jpeg',
      (quality / 100).toJS,
    );
    final blob = await completer.future;
    if (blob == null) return null;
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
