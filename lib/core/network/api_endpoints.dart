class ApiEndpoints {
  ApiEndpoints._();

  static const String login = '/login';
  static const String me = '/login/me';
  static const String refresh = '/login/refresh';
  static const String logout = '/login/logout';
  static const String requestPasswordReset = '/login/usuario/recuperar/acceso';
  static const String changePassword = '/usuarios/actualizar/contrasena';

  static const String vehicles = '/productos/vehiculos';
  static String vehicleByPlate(String plate) =>
      '/productos/vehiculos/placa/${Uri.encodeComponent(plate)}';

  static const String serviceOrderCatalog = '/ordenes-servicio/catalogo';
  static const String serviceOrderReasons = '/ordenes-servicio/motivos';
  static String serviceOrder(String id) => '/ordenes-servicio/$id';
  static String serviceOrdersPaged(int page, int limit) =>
      '/ordenes-servicio/paginado/$page/$limit';
  static String serviceOrderStart(String id) => '/ordenes-servicio/$id/iniciar';
  static String serviceOrderFile(String id, String key) =>
      '/ordenes-servicio/$id/archivos/$key';
  static String serviceOrderAuthorization(String id) =>
      '/ordenes-servicio/$id/autorizacion';
  static String serviceOrderCode(String id) => '/ordenes-servicio/$id/codigo';
  static String serviceOrderCodeValidate(String id) =>
      '/ordenes-servicio/$id/codigo/validar';
  static String serviceOrderTestRequest(String id, String key) =>
      '/ordenes-servicio/$id/pruebas/$key/solicitar';
  static String serviceOrderClose(String id) => '/ordenes-servicio/$id/cerrar';
  static String serviceOrderNotCompleted(String id) =>
      '/ordenes-servicio/$id/no-cumplida';
  static String serviceOrderPdf(String id) => '/ordenes-servicio/$id/pdf';
  static String serviceOrderShare(String id) =>
      '/ordenes-servicio/$id/compartir';
  static String serviceOrderEmail(String id) =>
      '/ordenes-servicio/$id/enviar-correo';

  static const String clients = '/clientes/list';
  static const String brands = '/cat-marcas/list';
  static const String models = '/cat-modelos/list';
  static const String fuelTypes = '/cat-tipo-combustible/list';

  static const String installationsPaged = '/instalaciones/paginado';
  static String installation(String id) => '/instalaciones/$id';
  static const String devices = '/dispositivos/list';
  static const String sims = '/sims/list';
}
