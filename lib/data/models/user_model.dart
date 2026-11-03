import '../../core/utils/json_reader.dart';
import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.avatarUrl,
    super.role,
    super.roleId,
    super.isActive,
    super.clientId,
    super.clientName,
    super.permissions,
    super.lastLogin,
  });

  /// Lee tanto la respuesta de `GET /login/me` como el usuario guardado
  /// localmente con [toJson].
  factory UserModel.fromJson(dynamic json) {
    final layers = JsonReader.layers(
      json,
      wrapperKeys: const ['data', 'user', 'usuario'],
    );

    return UserModel(
      id: JsonReader.string(
            layers,
            const ['id', 'idUsuario', 'usuarioId', 'userId', 'idUser'],
          ) ??
          '',
      name: _readName(layers),
      email: _readEmail(layers),
      phone: JsonReader.string(
        layers,
        const ['phone', 'telefono', 'celular', 'movil', 'phoneNumber'],
      ),
      avatarUrl: JsonReader.string(
        layers,
        const ['avatarUrl', 'fotoPerfil', 'avatar', 'foto', 'fotoUrl'],
      ),
      clientId: JsonReader.string(layers, const ['clientId', 'idCliente']),
      clientName: _readClientName(layers),
      role: _readRole(layers),
      roleId: _readRoleId(layers),
      isActive: JsonReader.boolean(
        layers,
        const ['isActive', 'activo', 'active', 'estatus', 'enabled'],
      ),
      permissions: _readPermissions(layers),
      lastLogin: DateTime.tryParse(
        JsonReader.string(layers, const ['lastLogin', 'ultimoLogin']) ?? '',
      ),
    );
  }

  static String _readName(List<Map<String, dynamic>> layers) {
    final fullName = JsonReader.string(
      layers,
      const ['name', 'nombreCompleto', 'fullName', 'displayName'],
    );
    if (fullName != null) return fullName;

    final firstName = JsonReader.string(
      layers,
      const ['nombre', 'nombres', 'firstName'],
    );
    final lastNames = JsonReader.string(
          layers,
          const ['apellidos', 'apellido', 'lastName'],
        ) ??
        [
          JsonReader.string(layers, const ['apellidoPaterno']),
          JsonReader.string(layers, const ['apellidoMaterno']),
        ].whereType<String>().join(' ');

    return [firstName, lastNames]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  static String? _readClientName(List<Map<String, dynamic>> layers) {
    final saved = JsonReader.string(layers, const ['clientName']);
    if (saved != null) return saved;
    final name = [
      JsonReader.string(layers, const ['nombreCliente']),
      JsonReader.string(layers, const ['apellidoPaternoCliente']),
      JsonReader.string(layers, const ['apellidoMaternoCliente']),
    ].whereType<String>().join(' ');
    return name.isEmpty ? null : name;
  }

  static String _readEmail(List<Map<String, dynamic>> layers) {
    final email = JsonReader.string(
      layers,
      const ['email', 'correo', 'correoElectronico'],
    );
    if (email != null) return email;
    final userName = JsonReader.string(
      layers,
      const ['userName', 'username', 'usuario'],
    );
    return userName != null && userName.contains('@') ? userName : '';
  }

  static String? _readRole(List<Map<String, dynamic>> layers) {
    final value = JsonReader.pick(
      layers,
      const [
        'role',
        'rol',
        'rolNombre',
        'perfil',
        'puesto',
        'tipoUsuario',
        'roles',
      ],
    );
    final role = value is List && value.isNotEmpty ? value.first : value;
    // `nombre` es un código corto (p. ej. "SA"); `descripcion` es el texto visible.
    if (role is Map) {
      return JsonReader.string(
        [Map<String, dynamic>.from(role)],
        const ['descripcion', 'description', 'nombre', 'name'],
      );
    }
    final text = role?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// `rol: { id: '8', ... }`, `idRol` o el `roleId` guardado localmente.
  static String? _readRoleId(List<Map<String, dynamic>> layers) {
    final direct =
        JsonReader.string(layers, const ['roleId', 'idRol', 'rolId']);
    if (direct != null) return direct;
    final value = JsonReader.pick(layers, const ['rol', 'role', 'roles']);
    final role = value is List && value.isNotEmpty ? value.first : value;
    if (role is! Map) return null;
    return JsonReader.string(
      [Map<String, dynamic>.from(role)],
      const ['id', 'idRol'],
    );
  }

  static List<String> _readPermissions(List<Map<String, dynamic>> layers) {
    final value = JsonReader.pick(
      layers,
      const ['permissions', 'permisos', 'permissionList'],
    );
    if (value is! List) return const [];
    return value
        .map((permission) {
          if (permission is Map) {
            return JsonReader.string(
              [Map<String, dynamic>.from(permission)],
              const ['id', 'idPermiso', 'permisoId', 'permissionId'],
            );
          }
          return permission?.toString();
        })
        .whereType<String>()
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role,
      'roleId': roleId,
      'isActive': isActive,
      'clientId': clientId,
      'clientName': clientName,
      'permissions': permissions,
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
      role: user.role,
      roleId: user.roleId,
      isActive: user.isActive,
      clientId: user.clientId,
      clientName: user.clientName,
      permissions: user.permissions,
      lastLogin: user.lastLogin,
    );
  }
}
