import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../errors/failures.dart';
import 'file_type.dart';

class UploadImage {
  final Uint8List bytes;
  final FileType type;

  const UploadImage(this.bytes, this.type);

  String filename(String name) => '$name.${type.extension}';
}

/// Deja PNG y JPG como vienen y convierte cualquier otro formato que se pueda
/// leer (p. ej. WEBP) a JPG, porque el API de órdenes solo acepta esos dos.
Future<UploadImage> prepareUploadImage(
  Uint8List bytes, {
  required String label,
  int maxBytes = 10 * 1024 * 1024,
}) async {
  final type = FileType.detect(bytes);
  final UploadImage result;
  if (type == FileType.jpeg || type == FileType.png) {
    result = UploadImage(bytes, type!);
  } else {
    final converted = await compute(_toJpg, bytes);
    if (converted == null) {
      throw ValidationFailure(
        '$label: formato no permitido. Usa una imagen PNG o JPG.',
      );
    }
    result = UploadImage(converted, FileType.jpeg);
  }
  if (result.bytes.length > maxBytes) {
    throw ValidationFailure(
      '$label: la imagen supera el máximo de ${maxBytes ~/ (1024 * 1024)} MB.',
    );
  }
  return result;
}

Uint8List? _toJpg(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return img.encodeJpg(image, quality: 85);
}
