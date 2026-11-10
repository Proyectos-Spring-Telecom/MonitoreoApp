import 'package:equatable/equatable.dart';

/// Equipo o SIM que puede entrar en una orden: del almacén (sin cliente) o
/// reservado al cliente de la orden (§5).
class InstallationResource extends Equatable {
  static const int availableStatus = 1;

  final String id;
  final String label;

  /// `null` = almacén.
  final String? clientId;

  /// `null` cuando el API no informa el estatus.
  final int? status;

  /// Tipo de equipo del dispositivo ("AVL").
  final String? typeName;

  /// Texto como en el PDF de la orden: "Suntech ST210 - IMEI 3333 -
  /// Serie: 0009" o "Telcel - ICCID 0002 - Tel: 7775642667".
  final String? summary;

  const InstallationResource({
    required this.id,
    required this.label,
    this.clientId,
    this.status,
    this.typeName,
    this.summary,
  });

  bool get isAvailable => status == null || status == availableStatus;

  bool get isInWarehouse => clientId == null;

  /// Se puede instalar en una orden de [orderClientId].
  bool canInstallFor(String? orderClientId) =>
      isAvailable && (isInWarehouse || clientId == orderClientId);

  @override
  List<Object?> get props => [id, label, clientId, status, typeName, summary];
}

/// Equipos y SIMs que `GET /dispositivos/list` y `/sims/list` devuelven para
/// el cliente: lo reservado más el almacén.
class InstallationStock {
  final List<InstallationResource> devices;
  final List<InstallationResource> sims;

  const InstallationStock({required this.devices, required this.sims});
}
