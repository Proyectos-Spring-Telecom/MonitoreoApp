import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/file_type.dart';

/// Datos del formulario "Datos del vehículo" para `POST /productos/vehiculos`.
class VehicleRequest {
  static const int maxFileBytes = 3 * 1024 * 1024;
  static const int maxPlateLength = 10;

  /// Nombre de la parte en el multipart por cada foto o documento.
  static const Map<String, String> fileFields = {
    'principal': 'foto',
    'frontal': 'fotoFrente',
    'trasera': 'fotoTrasera',
    'lateral_derecha': 'fotoDerecha',
    'lateral_izquierda': 'fotoIzquierda',
    'extra': 'fotoExtra',
    'tarjeta_circulacion': 'tarjetaCirculacion',
    'poliza_seguro': 'polizaSeguro',
    'permiso_carga': 'permisoCarga',
  };

  final String? clientId;
  final String plate;
  final String economicNumber;
  final String? brandId;
  final String? modelId;
  final String year;
  final String color;
  final String serialNumber;
  final String? fuelId;
  final String km;
  final String capacityLiters;

  /// Solo archivos nuevos, con la llave de la foto (`principal`, `frontal`…).
  final Map<String, Uint8List> files;

  const VehicleRequest({
    this.clientId,
    required this.plate,
    this.economicNumber = '',
    this.brandId,
    this.modelId,
    this.year = '',
    this.color = '',
    this.serialNumber = '',
    this.fuelId,
    this.km = '',
    this.capacityLiters = '',
    this.files = const {},
  });

  /// Partes de texto. Los vacíos no se envían.
  Map<String, String> toFields() {
    final fields = <String, String>{};
    void add(String key, String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) fields[key] = text;
    }

    add('idCliente', clientId);
    add('placa', plate.toUpperCase());
    add('numeroEconomico', economicNumber);
    add('idMarcaVehiculo', brandId);
    add('idModeloVehiculo', modelId);
    add('anio', year);
    add('color', color);
    add('numeroSerie', serialNumber.toUpperCase());
    add('idCombustible', fuelId);
    add('km', km.replaceAll(',', '.'));
    add('capacidadLitros', capacityLiters.replaceAll(',', '.'));
    return fields;
  }

  /// Valida formato y tamaño de cada archivo antes de enviarlo.
  List<ApiFile> toFiles({Map<String, String> labels = const {}}) {
    final result = <ApiFile>[];
    for (final entry in files.entries) {
      final field = fileFields[entry.key];
      if (field == null) continue;
      final label = labels[entry.key] ?? field;
      final bytes = entry.value;
      final type = FileType.detect(bytes);
      if (type == null) {
        throw ValidationFailure(
          '$label: formato no permitido. Usa PNG, JPG, WEBP o PDF.',
        );
      }
      if (bytes.length > maxFileBytes) {
        throw ValidationFailure('$label: el archivo supera el máximo de 3 MB.');
      }
      result.add(ApiFile(
        field: field,
        bytes: bytes,
        filename: '$field.${type.extension}',
        contentType: type.mimeType,
      ));
    }
    return result;
  }
}
