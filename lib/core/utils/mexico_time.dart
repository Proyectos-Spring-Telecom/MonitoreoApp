/// Hora de la Ciudad de México: UTC−6 todo el año (México eliminó el horario
/// de verano en 2022), sin importar la zona horaria configurada en el celular.
class MexicoCityTime {
  MexicoCityTime._();

  static const Duration offset = Duration(hours: -6);

  /// Fecha y hora de pared en la Ciudad de México.
  static DateTime from(DateTime date) => date.toUtc().add(offset);

  /// Fechas de `/ordenes-servicio`: el servidor guarda la hora de pared de la
  /// Ciudad de México y la devuelve con sufijo `Z`, como si fuera UTC. Si la
  /// fecha trae un desfase explícito (`-06:00`) se respeta tal cual.
  static DateTime? parseApi(String? raw) {
    final text = raw?.trim() ?? '';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    if (text.contains('T') && RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text)) {
      return parsed.toUtc();
    }
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
    ).subtract(offset);
  }
}
