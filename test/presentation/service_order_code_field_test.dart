import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/presentation/service_order/widgets/service_order_fields.dart';

/// Código de verificación: un recuadro por dígito sobre un solo campo.
void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    String? errorText,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceOrderCodeField(
          label: 'Código de 6 dígitos',
          controller: controller,
          isRequired: true,
          errorText: errorText,
        ),
      ),
    ));
    return controller;
  }

  testWidgets('cada dígito se ve en su recuadro', (tester) async {
    final controller = await pump(tester);

    await tester.enterText(find.byType(TextField), '76a5118');
    await tester.pump();

    expect(controller.text, '765118', reason: 'solo dígitos');
    for (final digit in ['7', '6', '5', '8']) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('no acepta más de 6 dígitos', (tester) async {
    final controller = await pump(tester);

    await tester.enterText(find.byType(TextField), '12345678');
    await tester.pump();

    expect(controller.text, '123456');
    expect(find.text('7'), findsNothing);
  });

  testWidgets('muestra el error debajo de los recuadros', (tester) async {
    await pump(tester, errorText: 'El código tiene 6 dígitos');

    expect(find.text('El código tiene 6 dígitos'), findsOneWidget);
  });
}
