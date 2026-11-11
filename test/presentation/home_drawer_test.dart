import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/domain/entities/user.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/presentation/home/home_page.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_service_order_repository.dart';

/// Inicio y Agenda del menú lateral son pestañas de la misma pantalla.
void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await signedInController(
      const User(id: '65', name: 'Juan Pérez', email: 't@next.mx', roleId: '8'),
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServiceOrderRepository>.value(
          value: FakeServiceOrderRepository(scheduledOrder()),
        ),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        initialRoute: AppConstants.homeRoute,
        routes: {AppConstants.homeRoute: (_) => const HomePage()},
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapInDrawer(WidgetTester tester, String label) async {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('desde Mi agenda, "Inicio" regresa a la pestaña de inicio',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Ver mi agenda'), findsOneWidget);

    await tapInDrawer(tester, 'Agenda');
    expect(find.text('Mi agenda'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing, reason: 'el menú se cierra');

    await tapInDrawer(tester, 'Inicio');
    expect(find.text('Mi agenda'), findsNothing);
    expect(find.text('Ver mi agenda'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('el menú marca la pestaña visible', (tester) async {
    await pumpHome(tester);

    await tapInDrawer(tester, 'Agenda');
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // _DrawerItem es privado: se lee su `selected` del widget.
    bool selected(String label) {
      final item = tester.widget(find.ancestor(
        of: find.descendant(
          of: find.byType(Drawer),
          matching: find.text(label),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_DrawerItem',
        ),
      ));
      return (item as dynamic).selected as bool;
    }

    expect(selected('Agenda'), isTrue);
    expect(selected('Inicio'), isFalse);
  });
}
