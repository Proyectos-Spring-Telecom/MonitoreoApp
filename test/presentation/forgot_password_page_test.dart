import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/routes/app_routes.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repository = FakeAuthRepository();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: repository.controller(),
      child: MaterialApp(
        initialRoute: '/login',
        routes: AppRoutes.getRoutes(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> openForgot(WidgetTester tester, {String email = ''}) async {
    if (email.isNotEmpty) {
      await tester.enterText(find.byType(TextFormField).first, email);
    }
    await tapText(tester, '¿Olvidaste tu contraseña?');
    expect(find.text('Recupera tu contraseña'), findsOneWidget);
  }

  group('Olvidaste tu contraseña', () {
    testWidgets('abre desde el login con el correo ya escrito', (tester) async {
      await pumpApp(tester);
      await openForgot(tester, email: 'tecnico@spring.mx');

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('tecnico@spring.mx'), findsOneWidget);

      await tapText(tester, 'Volver a iniciar sesión');
      expect(find.text('Hola, inicia sesión'), findsOneWidget);
    });

    testWidgets('valida el correo antes de enviar', (tester) async {
      await pumpApp(tester);
      await openForgot(tester);

      await tapText(tester, 'Enviar instrucciones');
      expect(find.text('El email es requerido'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'correo-invalido');
      await tapText(tester, 'Enviar instrucciones');
      expect(find.text('Email inválido'), findsOneWidget);
      expect(repository.resetRequests, isEmpty);
    });

    testWidgets('envía, muestra los pasos a seguir y permite reenviar',
        (tester) async {
      await pumpApp(tester);
      await openForgot(tester, email: 'tecnico@spring.mx');

      await tapText(tester, 'Enviar instrucciones');

      expect(repository.resetRequests, ['tecnico@spring.mx']);
      expect(find.text('¡Ya casi está listo!'), findsOneWidget);
      expect(find.text('tecnico@spring.mx', findRichText: true), findsNothing);
      expect(
        find.textContaining('tecnico@spring.mx', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Toca el enlace y crea tu nueva contraseña.'),
          findsOneWidget);
      expect(find.text('Reenviar correo en 60 s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 60));
      await tapText(tester, '¿No te llegó? Reenviar correo');
      expect(repository.resetRequests.length, 2);

      await tapText(tester, 'Usar otro correo');
      expect(find.text('Recupera tu contraseña'), findsOneWidget);
    });

    testWidgets('muestra el mensaje del backend y permite reintentar',
        (tester) async {
      await pumpApp(tester);
      await openForgot(tester, email: 'tecnico@spring.mx');
      repository.failure = const ServerFailure('El usuario no existe');

      await tapText(tester, 'Enviar instrucciones');
      expect(find.text('El usuario no existe'), findsOneWidget);

      repository.failure = null;
      await tapText(tester, 'Reintentar');
      expect(find.text('¡Ya casi está listo!'), findsOneWidget);
    });
  });
}
