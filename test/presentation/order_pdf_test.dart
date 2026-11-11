import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/widgets/app_message.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/orders/widgets/order_share_sheet.dart';

import '../helpers/fake_service_order_repository.dart';

/// "Ver PDF": `GET /:id/pdf` y el visor del teléfono (o la descarga en web).
/// El visor real se reemplaza: en una computadora abriría el archivo.
void main() {
  late FakeServiceOrderRepository repository;
  late List<(Uint8List, String)> opened;

  final order = scheduledOrder(id: '42', status: ServiceOrderStatus.cerrada);

  Future<void> tapViewPdf(
    WidgetTester tester,
    PdfOpener opener, {
    Failure? serverFailure,
  }) async {
    repository = FakeServiceOrderRepository(order);
    if (serverFailure != null) repository.failures['pdf'] = serverFailure;
    await tester.pumpWidget(Provider<ServiceOrderRepository>.value(
      value: repository,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openOrderPdf(context, order, opener: opener),
              child: const Text('Ver PDF'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ver PDF'));
    await tester.pump();
    await tester.pump();
  }

  setUp(() => opened = []);

  // El aviso se queda 4 s; se quita para no dejar timers pendientes.
  tearDown(AppMessage.hide);

  Future<bool> opens(Uint8List bytes, String filename) async {
    opened.add((bytes, filename));
    return true;
  }

  testWidgets('descarga el PDF y lo abre como <folio>.pdf', (tester) async {
    await tapViewPdf(tester, opens);

    expect(repository.calls, ['pdf']);
    expect(opened.single.$2, '${order.folio}.pdf');
    expect(find.textContaining('No'), findsNothing);
  });

  testWidgets('sin una app para abrirlo lo avisa', (tester) async {
    await tapViewPdf(tester, (_, __) async => false);

    expect(
        find.text('No hay una aplicación para abrir el PDF.'), findsOneWidget);
  });

  testWidgets('si el servidor falla muestra su mensaje y no abre nada',
      (tester) async {
    await tapViewPdf(
      tester,
      opens,
      serverFailure: const ServerFailure('La orden no tiene PDF.'),
    );

    expect(opened, isEmpty);
    expect(find.text('La orden no tiene PDF.'), findsOneWidget);
  });

  testWidgets('si no se puede guardar o abrir avisa sin cerrar la app',
      (tester) async {
    await tapViewPdf(
      tester,
      (_, __) => Future.error(Exception('sin espacio')),
    );

    expect(find.text('No se pudo descargar el PDF.'), findsOneWidget);
  });
}
