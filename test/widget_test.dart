import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitoreo/core/network/api_client.dart';
import 'package:monitoreo/data/datasources/local/local_storage.dart';
import 'package:monitoreo/data/datasources/local/auth_local_datasource.dart';
import 'package:monitoreo/data/datasources/remote/auth_remote_datasource.dart';
import 'package:monitoreo/data/repositories/auth_repository_impl.dart';
import 'package:monitoreo/domain/usecases/login_usecase.dart';
import 'package:monitoreo/domain/usecases/logout_usecase.dart';
import 'package:monitoreo/domain/usecases/get_current_user_usecase.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/main.dart' as app;

void main() {
  testWidgets('App builds and shows login page', (WidgetTester tester) async {
    // Setup
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final sharedPreferences = await SharedPreferences.getInstance();
    final localStorage = LocalStorageImpl(sharedPreferences);
    final authLocalDataSource = AuthLocalDataSourceImpl(localStorage);
    final apiClient = ApiClient();
    final authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient);
    final authRepository = AuthRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
      localDataSource: authLocalDataSource,
    );

    final loginUseCase = LoginUseCase(authRepository);
    final logoutUseCase = LogoutUseCase(authRepository);
    final getCurrentUserUseCase = GetCurrentUserUseCase(authRepository);

    final authController = AuthController(
      loginUseCase: loginUseCase,
      logoutUseCase: logoutUseCase,
      getCurrentUserUseCase: getCurrentUserUseCase,
    );

    await authController.checkAuthStatus();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      app.MyApp(authController: authController),
    );

    await tester.pumpAndSettle();

    // Verify that login page is shown
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
