import 'package:equatable/equatable.dart';

class User extends Equatable {
  /// La App de instaladores es solo para el técnico (rol 8).
  static const String installerRoleId = '8';

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? role;

  /// `rol.id` de `GET /login/me`.
  final String? roleId;
  final bool? isActive;

  /// Cliente (empresa) al que pertenece el usuario.
  final String? clientId;
  final String? clientName;

  /// IDs de permisos como texto.
  final List<String> permissions;

  final DateTime? lastLogin;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.roleId,
    this.isActive,
    this.clientId,
    this.clientName,
    this.permissions = const [],
    this.lastLogin,
  });

  bool get isInstaller => roleId == installerRoleId;

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatarUrl,
        role,
        roleId,
        isActive,
        clientId,
        clientName,
        permissions,
        lastLogin,
      ];
}
