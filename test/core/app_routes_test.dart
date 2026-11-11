import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/core/routes/app_routes.dart';
import 'package:monitoreo/data/datasources/local/order_key_storage.dart';
import 'package:monitoreo/domain/entities/user.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/auth/login/login_page.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/presentation/service_order/service_order_flow_page.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_service_order_repository.dart';

void main() {
  String? resolved(String name, {required bool signedIn, Object? arguments}) =>
      AppRoutes.resolve(
        RouteSettings(name: name, arguments: arguments),
        isAuthenticated: signedIn,
      ).name;

  group('sin sesión', () {
    test('las pantallas protegidas abren el login', () {
      for (final route in [
        AppConstants.homeRoute,
        AppConstants.profileRoute,
        AppConstants.completedOrdersRoute,
        AppConstants.changePasswordRoute,
        '${AppConstants.serviceOrderRoute}?id=42',
        '${AppConstants.orderDetailRoute}?id=42',
      ]) {
        expect(resolved(route, signedIn: false), AppConstants.loginRoute,
            reason: route);
      }
    });

    test('el login y la recuperación de contraseña sí se abren', () {
      expect(resolved(AppConstants.loginRoute, signedIn: false),
          AppConstants.loginRoute);
      expect(resolved(AppConstants.forgotPasswordRoute, signedIn: false),
          AppConstants.forgotPasswordRoute);
    });

    test('una ruta desconocida abre el login', () {
      expect(resolved('/no-existe', signedIn: false), AppConstants.loginRoute);
      expect(resolved('/', signedIn: false), AppConstants.loginRoute);
    });
  });

  group('con sesión', () {
    test('el login y las rutas desconocidas abren el inicio', () {
      expect(resolved(AppConstants.loginRoute, signedIn: true),
          AppConstants.homeRoute);
      expect(resolved('/', signedIn: true), AppConstants.homeRoute);
    });

    test('las demás pantallas conservan nombre y argumentos', () {
      final settings = AppRoutes.resolve(
        const RouteSettings(name: AppConstants.homeRoute, arguments: 1),
        isAuthenticated: true,
      );
      expect(settings.name, AppConstants.homeRoute);
      expect(settings.arguments, 1);
    });

    test('la orden pone su id en la URL y conserva la orden', () {
      final order = scheduledOrder(id: '42');
      final settings = AppRoutes.resolve(
        RouteSettings(name: AppConstants.serviceOrderRoute, arguments: order),
        isAuthenticated: true,
      );
      expect(settings.name, '${AppConstants.serviceOrderRoute}?id=42');
      expect(settings.arguments, same(order));

      expect(
        resolved(AppConstants.orderDetailRoute, signedIn: true, arguments: '7'),
        '${AppConstants.orderDetailRoute}?id=7',
      );
    });

    test('al recargar, el id de la URL llega como argumento', () {
      final settings = AppRoutes.resolve(
        const RouteSettings(name: '${AppConstants.serviceOrderRoute}?id=42'),
        isAuthenticated: true,
      );
      expect(settings.name, '${AppConstants.serviceOrderRoute}?id=42');
      expect(settings.arguments, '42');
    });

    test('al abrir una orden por URL queda el inicio debajo', () {
      final routes = AppRoutes.onGenerateInitialRoutes(
        '${AppConstants.serviceOrderRoute}?id=42',
        isAuthenticated: true,
      );
      expect(routes.map((route) => route.settings.name), [
        AppConstants.homeRoute,
        '${AppConstants.serviceOrderRoute}?id=42',
      ]);
    });
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required String initialRoute,
    required AuthController auth,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServiceOrderRepository>.value(
          value: FakeServiceOrderRepository(scheduledOrder(id: '42')),
        ),
        Provider<OrderKeyStorage>.value(value: MemoryOrderKeyStorage()),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        initialRoute: initialRoute,
        onGenerateInitialRoutes: (name) => AppRoutes.onGenerateInitialRoutes(
          name,
          isAuthenticated: auth.isAuthenticated,
        ),
        onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
          settings,
          isAuthenticated: auth.isAuthenticated,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sin sesión, abrir /service-order muestra el login',
      (tester) async {
    await pumpApp(
      tester,
      initialRoute: '${AppConstants.serviceOrderRoute}?id=42',
      auth: FakeAuthRepository().controller(),
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ServiceOrderFlowPage), findsNothing);
  });

  testWidgets('con sesión, recargar /service-order?id=42 carga la orden',
      (tester) async {
    final auth = await signedInController(
      const User(id: '65', name: 'Técnico', email: 't@next.mx', roleId: '8'),
    );
    await pumpApp(
      tester,
      initialRoute: '${AppConstants.serviceOrderRoute}?id=42',
      auth: auth,
    );
    expect(find.byType(ServiceOrderFlowPage), findsOneWidget);
    expect(find.text(scheduledOrder(id: '42').folio), findsWidgets);
  });
}
