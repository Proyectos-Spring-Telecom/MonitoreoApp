import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// `null` si los bytes no son una imagen que se pueda leer.
Future<Uint8List?> convertToJpg(Uint8List bytes, {int quality = 85}) =>
    compute(_toJpg, (bytes, quality));

Uint8List? _toJpg((Uint8List, int) input) {
  final (bytes, quality) = input;
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return img.encodeJpg(image, quality: quality);
}
