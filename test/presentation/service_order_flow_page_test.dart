import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/data/datasources/local/order_key_storage.dart';
import 'package:monitoreo/data/datasources/remote/installation_remote_datasource.dart';
import 'package:monitoreo/domain/entities/installation_resources.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/domain/entities/user.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/agenda/agenda_page.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/presentation/service_order/service_order_flow_controller.dart';
import 'package:monitoreo/presentation/service_order/service_order_flow_page.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_service_order_repository.dart';

class _FakeStock implements InstallationRemoteDataSource {
  @override
  Future<InstallationStock> getStock({required String clientId}) async =>
      const InstallationStock(
        devices: [
          InstallationResource(
            id: '981',
            label: 'Imei: 222',
            status: 1,
            typeName: 'AVL',
            summary: 'Suntech ST210 - IMEI 222 - Serie: 0000222',
          ),
          InstallationResource(id: '500', label: 'Imei: 111', status: 2),
        ],
        sims: [
          InstallationResource(
            id: '77',
            label: 'Telefono: 777',
            summary: 'Telcel - ICCID 0009999 - Tel: 777',
          ),
        ],
      );
}

void main() {
  late FakeServiceOrderRepository repository;
  late MemoryOrderKeyStorage keys;

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await signedInController(
      const User(
          id: '65', name: 'Emmanuel Avila', email: 't@next.mx', roleId: '8'),
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServiceOrderRepository>.value(value: repository),
        Provider<OrderKeyStorage>.value(value: keys),
        Provider<InstallationRemoteDataSource>.value(value: _FakeStock()),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        home: home,
        routes: {
          AppConstants.serviceOrderRoute: (_) => ServiceOrderFlowPage(
                readLocation: () async => (lat: 18.9, lng: -99.2),
              ),
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Abre la orden como lo hace la agenda.
  Future<void> openOrder(WidgetTester tester, ServiceOrderRecord order) async {
    repository = FakeServiceOrderRepository(order);
    keys = MemoryOrderKeyStorage();
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pushNamed(
            AppConstants.serviceOrderRoute,
            arguments: order,
          ),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  /// Desplaza hasta [finder] antes de tocarlo (el pie de cada paso queda
  /// fuera de la pantalla).
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    final vertical = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 300, scrollable: vertical.last);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ServiceOrderFlowController controllerOf(WidgetTester tester) =>
      Provider.of<ServiceOrderFlowController>(
        tester.element(find.byType(Scaffold).last),
        listen: false,
      );

  testWidgets('agenda: órdenes en curso y programadas', (tester) async {
    repository = FakeServiceOrderRepository(scheduledOrder())
      ..agenda = [
        scheduledOrder(id: '1', status: ServiceOrderStatus.borrador),
        scheduledOrder(id: '2', type: ServiceType.instalacion),
      ];
    keys = MemoryOrderKeyStorage();
    await pump(tester, const Scaffold(body: AgendaPage()));

    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('PROGRAMADAS'), findsOneWidget);
    expect(find.text('OS-00001'), findsOneWidget);
    expect(find.text('OS-00002'), findsOneWidget);
    expect(find.text('Transportes del Sur'), findsNWidgets(2));
  });

  testWidgets(
      'iniciar mantenimiento: "¿El dispositivo funciona?" → cambio de equipo',
      (tester) async {
    await openOrder(tester, scheduledOrder());
    repository.onAction = (action, repo) {
      if (action == 'start') {
        repo.order = scheduledOrder(
          type: ServiceType.cEquipo,
          status: ServiceOrderStatus.borrador,
        );
      }
    };

    expect(find.text('Datos de la visita'), findsOneWidget);
    expect(find.text('¿El dispositivo funciona?'), findsOneWidget);
    await tapVisible(tester, find.text('No, cambiar equipo'));
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Iniciar servicio'));

    expect(repository.started.single.$3, ServiceType.cEquipo);
    expect(repository.started.single.$2, keys.keys['42']);
    expect(find.text('Código de verificación'), findsWidgets);
  });

  testWidgets('código: el sexto pedido avisa que llame a operación',
      (tester) async {
    await openOrder(
      tester,
      scheduledOrder(status: ServiceOrderStatus.borrador),
    );
    repository.failures['code'] =
        const ServerFailure('Máximo de códigos', statusCode: 409);

    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'Solicitar código'));

    expect(find.text('Se agotaron los códigos'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Solicitar código'), findsNothing);
  });

  testWidgets('código validado: pasa a la edición de la instalación',
      (tester) async {
    await openOrder(
      tester,
      scheduledOrder(status: ServiceOrderStatus.borrador),
    );
    repository.onAction = (action, repo) {
      if (action.startsWith('validate:')) {
        repo.order = scheduledOrder(
          type: ServiceType.cEquipo,
          status: ServiceOrderStatus.borrador,
          codeValidated: true,
        );
      }
    };

    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '482913');
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Validar código'));
    expect(find.text('Vehículo confirmado'), findsOneWidget);

    await tapVisible(tester, find.text('Siguiente'));
    expect(find.text('Edición de la instalación'), findsOneWidget);
    expect(find.text('Sustitución del equipo'), findsOneWidget);
    expect(find.text('Imei: 111'), findsOneWidget, reason: 'equipo actual');
  });

  testWidgets('pruebas: sin inmovilizador no se ofrece el paro de motor',
      (tester) async {
    await openOrder(
      tester,
      scheduledOrder(status: ServiceOrderStatus.borrador, codeValidated: true),
    );
    controllerOf(tester).goTo(ServiceOrderStep.tests);
    await tester.pumpAndSettle();

    expect(find.text('Transmisión'), findsOneWidget);
    expect(find.text('Paro de motor'), findsNothing);

    await tapVisible(tester, find.text('Solicitar prueba').first);
    await tester.enterText(find.byType(TextField).last, 'presioné 10:42');
    await tester.tap(find.text('Solicitar').last);
    await tester.pumpAndSettle();

    expect(repository.requestedTests.single, ('transmision', 'presioné 10:42'));
  });

  testWidgets('resumen: con faltantes no deja registrar', (tester) async {
    await openOrder(
      tester,
      scheduledOrder(
        status: ServiceOrderStatus.borrador,
        codeValidated: true,
        missing: const ['Falta el monitorista'],
      ),
    );
    controllerOf(tester).goTo(ServiceOrderStep.summary);
    await tester.pumpAndSettle();

    expect(find.text('Pendiente para cerrar'), findsOneWidget);
    expect(find.text('Falta el monitorista'), findsOneWidget);
    await tapVisible(tester, find.text('Registrar orden'));
    expect(repository.calls, isNot(contains('close')));
  });

  testWidgets('resumen del alta: equipo y SIM elegidos sin textos del API',
      (tester) async {
    final base = scheduledOrder(
      type: ServiceType.instalacion,
      status: ServiceOrderStatus.borrador,
      productId: '7',
    );
    await openOrder(
      tester,
      ServiceOrderRecord(
        id: base.id,
        folio: base.folio,
        typeKey: base.typeKey,
        scheduledTypeKey: base.scheduledTypeKey,
        statusKey: base.statusKey,
        origin: base.origin,
        clientId: base.clientId,
        plate: base.plate,
        productId: base.productId,
        newDeviceId: '981',
        newSimId: '77',
      ),
    );
    controllerOf(tester).goTo(ServiceOrderStep.summary);
    await tester.pumpAndSettle();

    expect(find.text('Vehículo e instalación'), findsOneWidget);
    expect(find.text('AVL'), findsOneWidget);
    expect(find.text('Suntech ST210'), findsOneWidget);
    expect(find.text('222'), findsOneWidget, reason: 'IMEI');
    expect(find.text('0000222'), findsOneWidget, reason: 'Serie');
    expect(find.text('Telcel'), findsOneWidget);
    expect(find.text('0009999'), findsOneWidget, reason: 'ICCID');
    expect(find.text('777'), findsOneWidget, reason: 'Teléfono');
  });

  testWidgets('no se pudo realizar: motivo del técnico', (tester) async {
    await openOrder(tester, scheduledOrder());
    repository.onAction = (action, repo) {
      if (action.startsWith('not_completed:')) {
        repo.order = scheduledOrder(status: ServiceOrderStatus.noCumplida);
      }
    };

    await tapVisible(tester, find.text('No se pudo realizar').first);
    await tester.tap(find.text('Cliente ausente'));
    await tester.pump();
    await tapVisible(tester, find.text('Marcar como no cumplida'));

    expect(repository.calls,
        containsAllInOrder(['start', 'not_completed:cliente_ausente']));
    expect(find.text('Orden no cumplida'), findsOneWidget);
    expect(find.text('Compartir PDF'), findsOneWidget);
  });

  testWidgets('atrás del sistema o del navegador regresa un paso',
      (tester) async {
    await openOrder(
      tester,
      scheduledOrder(status: ServiceOrderStatus.borrador, codeValidated: true),
    );
    final controller = controllerOf(tester);
    controller.goTo(ServiceOrderStep.tests);
    await tester.pumpAndSettle();
    final index = controller.stepIndex;

    // Lo mismo que hace el botón atrás de Android o del navegador.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ServiceOrderFlowPage), findsOneWidget);
    expect(controller.stepIndex, index - 1);
    expect(controller.currentStep, ServiceOrderStep.checklist);

    // En el primer paso sí sale de la orden.
    controller.goTo(controller.steps.first);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ServiceOrderFlowPage), findsNothing);
  });
}
