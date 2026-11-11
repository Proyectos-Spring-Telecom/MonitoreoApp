import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Guarda el PDF en la carpeta temporal y lo abre con el visor del teléfono.
/// `false` si no hay una aplicación que lo abra.
Future<bool> openPdf(Uint8List bytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path, type: 'application/pdf');
  return result.type == ResultType.done;
}
