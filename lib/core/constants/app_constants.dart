class AppConstants {
  // Rutas de navegación
  static const String loginRoute = '/login';
  static const String homeRoute = '/home';
  static const String profileRoute = '/profile';
  static const String serviceDetailsRoute = '/service-details';
  static const String gpsDataRoute = '/gps-data';
  static const String serviceReviewRoute = '/service-review';
  static const String completedOrdersRoute = '/completed-orders';
  static const String changePasswordRoute = '/change-password';

  // Claves de almacenamiento local
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String isLoggedInKey = 'is_logged_in';

  // Configuración de red (preparado para APIs)
  static const String baseUrl = 'https://api.example.com';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
