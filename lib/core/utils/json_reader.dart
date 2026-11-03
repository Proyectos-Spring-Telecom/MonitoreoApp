import 'dart:convert';

/// Lectura tolerante de respuestas del API: las claves se comparan sin
/// distinguir mayúsculas y se buscan en varios objetos (p. ej. la raíz y `data`).
class JsonReader {
  JsonReader._();

  /// Devuelve [json] seguido de los objetos anidados bajo [wrapperKeys],
  /// del más externo al más interno.
  static List<Map<String, dynamic>> layers(
    dynamic json, {
    List<String> wrapperKeys = const ['data'],
  }) {
    final result = <Map<String, dynamic>>[];
    var current = json;
    while (current is Map) {
      final map = Map<String, dynamic>.from(current);
      result.add(map);
      current = null;
      for (final key in wrapperKeys) {
        final nested = _lookup(map, key);
        if (nested is Map) {
          current = nested;
          break;
        }
      }
    }
    return result;
  }

  /// Lista que viene en la raíz o dentro de alguna de [wrapperKeys].
  static List<dynamic> list(
    dynamic json, {
    List<String> wrapperKeys = const ['data'],
  }) {
    if (json is List) return json;
    for (final layer in layers(json, wrapperKeys: wrapperKeys)) {
      for (final key in wrapperKeys) {
        final value = _lookup(layer, key);
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// Primer valor no nulo de [keys], buscando de la capa más interna a la externa.
  static dynamic pick(List<Map<String, dynamic>> layers, List<String> keys) {
    for (final layer in layers.reversed) {
      for (final key in keys) {
        final value = _lookup(layer, key);
        if (value != null) return value;
      }
    }
    return null;
  }

  static String? string(List<Map<String, dynamic>> layers, List<String> keys) {
    final value = pick(layers, keys);
    if (value == null || value is Map || value is List) return null;
    final text = repairEncoding(value.toString().trim());
    return text.isEmpty ? null : text;
  }

  /// Corrige textos UTF-8 que el servidor guardó como Latin-1
  /// (p. ej. "SupÃ©r" → "Supér").
  static String repairEncoding(String text) {
    if (!text.contains('Ã') && !text.contains('Â')) return text;
    try {
      return utf8.decode(latin1.encode(text));
    } catch (_) {
      return text;
    }
  }

  static bool? boolean(List<Map<String, dynamic>> layers, List<String> keys) {
    final value = pick(layers, keys);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (const ['true', '1', 'activo', 'activa', 'active', 'si', 'sí']
          .contains(normalized)) {
        return true;
      }
      if (const ['false', '0', 'inactivo', 'inactiva', 'inactive', 'no']
          .contains(normalized)) {
        return false;
      }
    }
    return null;
  }

  static dynamic _lookup(Map<String, dynamic> map, String key) {
    if (map.containsKey(key)) return map[key];
    final lower = key.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}
