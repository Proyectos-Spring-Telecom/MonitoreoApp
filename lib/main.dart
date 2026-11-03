import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_routes.dart';
import 'core/network/api_client.dart';
import 'data/datasources/local/local_storage.dart';
import 'data/datasources/local/auth_local_datasource.dart';
import 'data/datasources/local/order_key_storage.dart';
import 'data/datasources/local/secure_storage.dart';
import 'data/datasources/remote/auth_remote_datasource.dart';
import 'data/datasources/remote/catalog_remote_datasource.dart';
import 'data/datasources/remote/installation_remote_datasource.dart';
import 'data/datasources/remote/vehicle_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/catalog_repository_impl.dart';
import 'data/repositories/service_order_repository_impl.dart';
import 'domain/repositories/catalog_repository.dart';
import 'domain/repositories/service_order_repository.dart';
import 'domain/usecases/fetch_profile_usecase.dart';
import 'domain/usecases/login_usecase.dart';
import 'domain/usecases/logout_usecase.dart';
import 'domain/usecases/get_current_user_usecase.dart';
import 'domain/usecases/change_password_usecase.dart';
import 'domain/usecases/request_password_reset_usecase.dart';
import 'presentation/controllers/auth_controller.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar dependencias. El permiso de ubicación se pide al iniciar una
  // orden, que es cuando se registra la ubicación.
  final sharedPreferences = await SharedPreferences.getInstance();
  final localStorage = LocalStorageImpl(sharedPreferences);
  final authLocalDataSource =
      AuthLocalDataSourceImpl(localStorage, SecureStorageImpl());
  final apiClient = ApiClient();
  final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
  );
  apiClient.authHandler = authRepository;

  final catalogRepository =
      CatalogRepositoryImpl(CatalogRemoteDataSourceImpl(apiClient));
  final serviceOrderRepository = ServiceOrderRepositoryImpl(apiClient);
  final orderKeyStorage = OrderKeyStorageImpl(localStorage);

  // Inicializar controlador
  final authController = AuthController(
    loginUseCase: LoginUseCase(authRepository),
    logoutUseCase: LogoutUseCase(authRepository),
    getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
    fetchProfileUseCase: FetchProfileUseCase(authRepository),
    requestPasswordResetUseCase: RequestPasswordResetUseCase(authRepository),
    changePasswordUseCase: ChangePasswordUseCase(authRepository),
    onSignedOut: () async {
      catalogRepository.clearCache();
      serviceOrderRepository.clearCache();
      await orderKeyStorage.clear();
    },
  );

  authRepository.onSessionExpiredCallback = () {
    if (!authController.isAuthenticated) return;
    authController.expireSession();
    appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppConstants.loginRoute,
      (route) => false,
    );
  };

  // Verificar estado de autenticación
  await authController.checkAuthStatus();

  runApp(
    MyApp(
      authController: authController,
      catalogRepository: catalogRepository,
      vehicleDataSource: VehicleRemoteDataSourceImpl(apiClient),
      installationDataSource: InstallationRemoteDataSourceImpl(apiClient),
      serviceOrderRepository: serviceOrderRepository,
      orderKeyStorage: orderKeyStorage,
    ),
  );

  // Valida la sesión guardada contra el servidor una vez por arranque.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    authController.refreshProfile();
  });
}

class MyApp extends StatelessWidget {
  final AuthController authController;
  final CatalogRepository catalogRepository;
  final VehicleRemoteDataSource vehicleDataSource;
  final InstallationRemoteDataSource installationDataSource;
  final ServiceOrderRepository serviceOrderRepository;
  final OrderKeyStorage orderKeyStorage;

  const MyApp({
    super.key,
    required this.authController,
    required this.catalogRepository,
    required this.vehicleDataSource,
    required this.installationDataSource,
    required this.serviceOrderRepository,
    required this.orderKeyStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        Provider.value(value: catalogRepository),
        Provider.value(value: vehicleDataSource),
        Provider.value(value: installationDataSource),
        Provider.value(value: serviceOrderRepository),
        Provider.value(value: orderKeyStorage),
      ],
      child: MaterialApp(
        title: 'Monitoreo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorKey: appNavigatorKey,
        initialRoute: authController.isAuthenticated
            ? AppConstants.homeRoute
            : AppConstants.loginRoute,
        routes: AppRoutes.getRoutes(),
      ),
    );
  }
}
