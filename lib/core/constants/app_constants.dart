class AppConstants {
  // Rutas de navegación
  static const String loginRoute = '/login';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String homeRoute = '/home';
  static const String profileRoute = '/profile';
  static const String serviceOrderRoute = '/service-order';
  static const String completedOrdersRoute = '/completed-orders';
  static const String orderDetailRoute = '/order-detail';
  static const String changePasswordRoute = '/change-password';

  // Claves de almacenamiento local
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';

  // Configuración de red. Otro entorno: --dart-define=API_BASE_URL=https://...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://springtelecom.mx/nextAPI/api',
  );
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 120);
}
