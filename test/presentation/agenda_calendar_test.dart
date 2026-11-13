import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/agenda/agenda_page.dart';
import 'package:monitoreo/presentation/orders/order_models.dart';
import 'package:monitoreo/presentation/service_order/widgets/service_order_ui.dart';

import '../helpers/fake_service_order_repository.dart';

/// Hora de pared de la Ciudad de México (UTC−6) como la guarda el modelo.
DateTime mx(int month, int day, int hour) =>
    DateTime.utc(2026, month, day, hour + 6);

void main() {
  late FakeServiceOrderRepository repository;
  late List<Object?> opened;

  // Hoy: viernes 30 de octubre de 2026, 9:00 en la Ciudad de México.
  DateTime today() => mx(10, 30, 9);

  Future<void> pumpAgenda(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened = [];
    repository = FakeServiceOrderRepository(scheduledOrder())
      ..agenda = [
        scheduledOrder(id: '1', status: ServiceOrderStatus.borrador),
        scheduledOrder(
          id: '2',
          type: ServiceType.instalacion,
          appointment: mx(10, 30, 10),
        ),
        scheduledOrder(id: '3', appointment: mx(10, 30, 13)),
        scheduledOrder(
          id: '4',
          type: ServiceType.cEquipo,
          appointment: mx(10, 28, 16),
        ),
        scheduledOrder(id: '5', appointment: mx(11, 3, 9)),
      ];
    await tester.pumpWidget(Provider<ServiceOrderRepository>.value(
      value: repository,
      child: MaterialApp(
        home: Scaffold(body: AgendaPage(now: today)),
        onGenerateRoute: (settings) => MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) {
            opened.add(settings.arguments);
            return const Scaffold(body: Text('flujo de la orden'));
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('agenda: las en curso arriba y las programadas por día',
      (tester) async {
    await pumpAgenda(tester);

    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('OS-00001'), findsOneWidget);

    // Orden: selector Agenda | Mes, "En curso" y después el calendario.
    double top(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(top('Agenda'), lessThan(top('EN CURSO')));
    expect(top('EN CURSO'), lessThan(top('OS-00001')));
    expect(top('OS-00001'), lessThan(top('Octubre 2026')));

    // Vista "Agenda": encabezado de mes y un renglón por día, en orden.
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('MIÉ'), findsOneWidget);
    expect(find.text('VIE'), findsOneWidget);
    expect(find.text('MAR'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('OS-00004')).dy,
      lessThan(tester.getTopLeft(find.text('OS-00002')).dy),
      reason: 'el 28 va antes que el 30',
    );
    expect(
      tester.getTopLeft(find.text('OS-00002')).dy,
      lessThan(tester.getTopLeft(find.text('OS-00003')).dy),
      reason: 'el mismo día, por hora',
    );
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Instalación'), findsOneWidget);
  });

  testWidgets('agenda: tocar una orden abre el flujo de inicio',
      (tester) async {
    await pumpAgenda(tester);

    await tester.tap(find.text('OS-00002'));
    await tester.pumpAndSettle();

    expect(find.text('flujo de la orden'), findsOneWidget);
    expect((opened.single as ServiceOrderRecord).id, '2');
    expect(
      ModalRoute.of(tester.element(find.text('flujo de la orden')))!
          .settings
          .name,
      AppConstants.serviceOrderRoute,
    );
  });

  testWidgets('mes: muestra hoy y al elegir un día lista sus órdenes',
      (tester) async {
    await pumpAgenda(tester);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('3 órdenes este mes'), findsOneWidget);
    // "En curso" también se ve en la vista Mes, debajo del selector.
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('EN CURSO')).dy,
      lessThan(tester.getTopLeft(find.text('Octubre 2026')).dy),
    );
    // Hoy está elegido: sus dos órdenes, abajo.
    expect(find.text('Viernes 30 de octubre'), findsOneWidget);
    expect(find.text('OS-00002'), findsOneWidget);
    expect(find.text('OS-00003'), findsOneWidget);
    expect(find.text('OS-00004'), findsNothing);

    await tester.tap(find.bySemanticsLabel('28 de octubre, 1 orden'));
    await tester.pumpAndSettle();
    expect(find.text('Miércoles 28 de octubre'), findsOneWidget);
    expect(find.text('OS-00004'), findsOneWidget);

    await tester.tap(find.text('OS-00004'));
    await tester.pumpAndSettle();
    expect((opened.single as ServiceOrderRecord).id, '4');
  });

  testWidgets('mes: cambia de mes y "Hoy" regresa', (tester) async {
    await pumpAgenda(tester);
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('1 orden este mes'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('3 de noviembre, 1 orden'));
    await tester.pumpAndSettle();
    expect(find.text('Martes 3 de noviembre'), findsOneWidget);
    expect(find.text('OS-00005'), findsOneWidget);

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('Viernes 30 de octubre'), findsOneWidget);
  });

  testWidgets('mes: un día sin órdenes lo dice', (tester) async {
    await pumpAgenda(tester);
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('29 de octubre, sin órdenes'));
    await tester.pumpAndSettle();
    expect(find.text('Sin órdenes programadas este día.'), findsOneWidget);
  });

  testWidgets('pantalla angosta (320): números completos y sin desbordes',
      (tester) async {
    await pumpAgenda(tester, width: 320);

    // Cada número del día ocupa un solo renglón.
    double lineHeight(String text) =>
        tester.getSize(find.text(text).first).height;
    expect(lineHeight('28'), lessThan(30));
    expect(lineHeight('30'), lessThan(30));
    expect(find.text('10:00 – 12:00'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(lineHeight('30'), lessThan(30));
    expect(tester.takeException(), isNull);
  });

  test('colores: revisión en amarillo, cambios en violeta y "En curso" en azul',
      () {
    expect(
      orderTypeColor(scheduledOrder(type: ServiceType.revision)),
      ServiceOrderColors.warning,
    );
    expect(ServiceOrderStatus.borrador.color, ServiceOrderColors.accent);
    // Cada tipo con su propio color.
    final colors = {
      for (final type in ServiceType.values)
        orderTypeColor(scheduledOrder(type: type)),
    };
    expect(colors.length, ServiceType.values.length - 1,
        reason: 'cambio de SIM y de equipo comparten color');
    expect(
      orderTypeColor(scheduledOrder(type: ServiceType.cSim)),
      ServiceOrderColors.violet,
    );
  });
}
