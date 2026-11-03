import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/widgets/app_message.dart';
import 'package:monitoreo/presentation/auth/change_password/change_password_page.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = FakeAuthRepository();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: repository.controller(),
      child: MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: Text('PERFIL')),
          '/change-password': (_) => const ChangePasswordPage(),
        },
        initialRoute: '/change-password',
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  Future<void> fill(WidgetTester tester,
      {String current = '', String next = '', String confirm = ''}) async {
    await tester.enterText(field('Ingresa tu contraseña actual'), current);
    await tester.enterText(field('Ingresa la nueva contraseña'), next);
    await tester.enterText(field('Repite la nueva contraseña'), confirm);
  }

  Future<void> submit(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    AppMessage.hide();
    await tester.pumpAndSettle();
    final button = find.widgetWithText(ElevatedButton, 'Cambiar contraseña');
    await tester.scrollUntilVisible(button, 300,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('valida antes de llamar al API', (tester) async {
    await pumpPage(tester);
    await submit(tester);

    expect(find.text('Ingresa tu contraseña actual.'), findsOneWidget);
    expect(find.text('Ingresa la nueva contraseña.'), findsOneWidget);
    expect(find.text('Confirma la nueva contraseña.'), findsOneWidget);

    await fill(tester,
        current: 'Actual1!', next: 'abcdefgh', confirm: 'abcdefgh');
    await submit(tester);
    expect(find.text('No cumple con todos los requisitos.'), findsOneWidget);

    await fill(tester,
        current: 'Actual1!', next: 'Nueva12!', confirm: 'Nueva13!');
    await submit(tester);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(repository.changes, isEmpty);
  });

  testWidgets('el medidor refleja las reglas del API (7 a 15)', (tester) async {
    await pumpPage(tester);
    expect(find.text('Sin evaluar'), findsOneWidget);

    Future<void> type(String text) async {
      await tester.enterText(field('Ingresa la nueva contraseña'), text);
      await tester.pump();
    }

    await type('abc');
    expect(find.text('Débil'), findsOneWidget);
    await type('Abcdefg1');
    expect(find.text('Media'), findsOneWidget);
    await type('Abcde1!');
    expect(find.text('Segura'), findsOneWidget, reason: '7 caracteres');
    await type('Abcdefghijk123!!');
    expect(find.text('Media'), findsOneWidget, reason: 'más de 15');
  });

  testWidgets('envía los tres campos y regresa con el mensaje', (tester) async {
    await pumpPage(tester);
    repository.serverMessage = 'Contraseña actualizada';
    await fill(tester,
        current: 'ClaveVieja1!', next: 'ClaveNueva2!', confirm: 'ClaveNueva2!');
    await submit(tester);

    expect(repository.changes.single, (
      current: 'ClaveVieja1!',
      newPassword: 'ClaveNueva2!',
      confirm: 'ClaveNueva2!',
    ));
    expect(find.text('Contraseña actualizada'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
  });

  testWidgets('muestra el error del backend y se queda', (tester) async {
    await pumpPage(tester);
    repository.failure =
        const ServerFailure('La contraseña actual no coincide');
    await fill(tester,
        current: 'Mala1234!', next: 'ClaveNueva2!', confirm: 'ClaveNueva2!');
    await submit(tester);

    expect(find.text('La contraseña actual no coincide'), findsOneWidget);
    expect(find.text('PERFIL'), findsNothing);
  });
}
