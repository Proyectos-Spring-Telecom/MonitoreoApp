/// Catálogo `estatusInstalacion` del API.
enum InstallationStatus {
  inactivo(0, 'INACTIVO', 'Inactivo'),
  activa(1, 'ACTIVA', 'Activa'),
  asignado(2, 'ASIGNADO', 'Asignado'),
  bajaRemplazo(3, 'BAJA_REMPLAZO', 'Baja por reemplazo'),
  bajaMantenimiento(4, 'BAJA_MANTENIMIENTO', 'Baja por mantenimiento'),
  inservible(5, 'INSERVIBLE', 'Inservible');

  const InstallationStatus(this.id, this.code, this.label);

  final int id;
  final String code;
  final String label;

  static InstallationStatus? fromId(int? id) {
    for (final status in values) {
      if (status.id == id) return status;
    }
    return null;
  }

  static InstallationStatus? fromCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    for (final status in values) {
      if (status.code == normalized) return status;
    }
    return null;
  }
}
