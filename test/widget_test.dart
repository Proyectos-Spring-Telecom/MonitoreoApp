import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/data/datasources/local/local_storage.dart';
import 'package:monitoreo/data/datasources/local/auth_local_datasource.dart';
import 'package:monitoreo/data/datasources/remote/auth_remote_datasource.dart';
import 'package:monitoreo/data/datasources/remote/catalog_remote_datasource.dart';
import 'package:monitoreo/data/datasources/remote/installation_remote_datasource.dart';
import 'package:monitoreo/data/datasources/local/order_key_storage.dart';
import 'package:monitoreo/data/datasources/remote/vehicle_remote_datasource.dart';
import 'package:monitoreo/data/repositories/catalog_repository_impl.dart';
import 'package:monitoreo/data/repositories/service_order_repository_impl.dart';
import 'package:monitoreo/data/repositories/auth_repository_impl.dart';
import 'package:monitoreo/domain/usecases/fetch_profile_usecase.dart';
import 'package:monitoreo/domain/usecases/login_usecase.dart';
import 'package:monitoreo/domain/usecases/logout_usecase.dart';
import 'package:monitoreo/domain/usecases/get_current_user_usecase.dart';
import 'package:monitoreo/domain/usecases/change_password_usecase.dart';
import 'package:monitoreo/domain/usecases/request_password_reset_usecase.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/main.dart' as app;

import 'helpers/in_memory_secure_storage.dart';

void main() {
  testWidgets('App builds and shows login page', (WidgetTester tester) async {
    // Setup
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final sharedPreferences = await SharedPreferences.getInstance();
    final localStorage = LocalStorageImpl(sharedPreferences);
    final authLocalDataSource =
        AuthLocalDataSourceImpl(localStorage, InMemorySecureStorage());
    final apiClient = ApiClient();
    final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
    final authRepository = AuthRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
      localDataSource: authLocalDataSource,
    );

    final authController = AuthController(
      loginUseCase: LoginUseCase(authRepository),
      logoutUseCase: LogoutUseCase(authRepository),
      getCurrentUserUseCase: GetCurrentUserUseCase(authRepository),
      fetchProfileUseCase: FetchProfileUseCase(authRepository),
      requestPasswordResetUseCase: RequestPasswordResetUseCase(authRepository),
      changePasswordUseCase: ChangePasswordUseCase(authRepository),
    );

    await authController.checkAuthStatus();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      app.MyApp(
        authController: authController,
        catalogRepository:
            CatalogRepositoryImpl(CatalogRemoteDataSourceImpl(apiClient)),
        vehicleDataSource: VehicleRemoteDataSourceImpl(apiClient),
        installationDataSource: InstallationRemoteDataSourceImpl(apiClient),
        serviceOrderRepository: ServiceOrderRepositoryImpl(apiClient),
        orderKeyStorage: OrderKeyStorageImpl(localStorage),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that login page is shown
    expect(find.text('Hola, inicia sesión'), findsOneWidget);
  });
}
