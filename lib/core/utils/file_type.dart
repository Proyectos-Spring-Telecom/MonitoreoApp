import 'dart:typed_data';

class FileType {
  final String extension;
  final String mimeType;

  const FileType(this.extension, this.mimeType);

  static const jpeg = FileType('jpg', 'image/jpeg');
  static const png = FileType('png', 'image/png');
  static const webp = FileType('webp', 'image/webp');
  static const pdf = FileType('pdf', 'application/pdf');

  /// Identifica el formato por sus primeros bytes; `null` si no es PNG, JPG,
  /// WEBP ni PDF.
  static FileType? detect(Uint8List bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return jpeg;
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return png;
    if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
      return webp;
    }
    if (startsWith('%PDF'.codeUnits)) return pdf;
    return null;
  }
}
