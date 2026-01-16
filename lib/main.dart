import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_routes.dart';
import 'core/network/api_client.dart';
import 'data/datasources/local/local_storage.dart';
import 'data/datasources/local/auth_local_datasource.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/get_current_user_usecase.dart';
import 'presentation/controllers/auth_controller.dart';
import 'core/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solicitar permisos de ubicación al iniciar
  await LocationService.requestLocationPermission();

  // Inicializar dependencias
  final sharedPreferences = await SharedPreferences.getInstance();
  final localStorage = LocalStorageImpl(sharedPreferences);
  final authLocalDataSource = AuthLocalDataSourceImpl(localStorage);
  final apiClient = ApiClient();
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
  );

  // Inicializar casos de uso
  final loginUseCase = LoginUseCase(authRepository);
  final logoutUseCase = LogoutUseCase(authRepository);
  final getCurrentUserUseCase = GetCurrentUserUseCase(authRepository);

  // Inicializar controlador
  final authController = AuthController(
    loginUseCase: loginUseCase,
    logoutUseCase: logoutUseCase,
    getCurrentUserUseCase: getCurrentUserUseCase,
  );

  // Verificar estado de autenticación
  await authController.checkAuthStatus();

  runApp(
    MyApp(
      authController: authController,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthController authController;

  const MyApp({
    super.key,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: authController,
      child: MaterialApp(
        title: 'Monitoreo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: authController.isAuthenticated
            ? AppConstants.homeRoute
            : AppConstants.loginRoute,
        routes: AppRoutes.getRoutes(),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
