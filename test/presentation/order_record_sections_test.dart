import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/presentation/orders/order_models.dart';
import 'package:monitoreo/presentation/orders/widgets/order_record_sections.dart';
import 'package:monitoreo/presentation/service_order/widgets/service_order_summary.dart';
import 'package:monitoreo/presentation/service_order/widgets/service_order_ui.dart';

/// Detalle de una orden cerrada: en un cambio se ve lo que entró y lo que
/// se retiró.
void main() {
  testWidgets('cambio de SIM cerrado: SIM nueva y SIM retirada',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OrderRecordSections(
            names: OrderNames(),
            order: ServiceOrderRecord(
              id: '10',
              folio: 'OS-000010',
              typeKey: 'c_sim',
              scheduledTypeKey: 'c_sim',
              statusKey: 'cerrada',
              installation: InstallationSummary(
                equipmentType: 'AVL',
                device: 'Suntech ST210 - IMEI 222',
                sim: 'Telcel - ICCID 8952020025494551111 - Tel: 7773246547',
              ),
              resultingInstallation: InstallationSummary(
                equipmentType: 'AVL',
                device: 'Suntech ST210 - IMEI 222',
                sim: 'Telcel - ICCID 8952020926393938002 - Tel: 7775047792',
              ),
              outgoingStatus: 3,
            ),
          ),
        ),
      ),
    ));

    expect(find.text('SIM nueva'), findsOneWidget);
    expect(find.text('SIM retirada'), findsOneWidget);
    expect(find.text('SIM a quitar'), findsNothing);
    expect(find.text('8952020926393938002'), findsOneWidget);
    expect(find.text('8952020025494551111'), findsOneWidget);
    expect(find.text('Por revisar'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('pruebas: el mismo ✓ y ✕ que la SIM nueva y la que se quita',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SummaryTestRow('Transmisión', TestStatus.correcta),
            SummaryTestRow('Botón de pánico', TestStatus.fallida),
            SummaryTestRow('Paro de motor', TestStatus.solicitada),
          ],
        ),
      ),
    ));

    Finder circleIn(String label, IconData icon) => find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(SummaryTestRow),
          ),
          matching: find.descendant(
            of: find.byType(CircleStatusIcon),
            matching: find.byIcon(icon),
          ),
        );

    expect(circleIn('Transmisión', Icons.check_rounded), findsOneWidget);
    expect(circleIn('Botón de pánico', Icons.close_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Paro de motor'),
          matching: find.byType(SummaryTestRow),
        ),
        matching: find.byType(CircleStatusIcon),
      ),
      findsNothing,
    );
  });
}
