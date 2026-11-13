import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:monitoreo/core/constants/app_constants.dart';
import 'package:monitoreo/core/errors/failures.dart';
import 'package:monitoreo/core/utils/mexico_time.dart';
import 'package:monitoreo/domain/entities/service_order.dart';
import 'package:monitoreo/domain/entities/service_order_record.dart';
import 'package:monitoreo/domain/entities/user.dart';
import 'package:monitoreo/domain/repositories/service_order_repository.dart';
import 'package:monitoreo/presentation/controllers/auth_controller.dart';
import 'package:monitoreo/presentation/orders/completed_orders_page.dart';
import 'package:monitoreo/presentation/orders/order_detail_page.dart';
import 'package:monitoreo/presentation/service_order/widgets/service_order_ui.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/fake_service_order_repository.dart';

final closedOrder = ServiceOrderRecord(
  id: '3',
  folio: 'OS-000003',
  typeKey: 'instalacion',
  scheduledTypeKey: 'instalacion',
  statusKey: 'cerrada',
  clientId: '33',
  clientName: 'Transportes del Norte',
  plate: 'NV4126B',
  resultingInstallationId: '1000439',
  newDeviceId: '1000438',
  technicianId: '65',
  monitorId: '15',
  capturedAt: MexicoCityTime.parseApi('2026-10-28T18:45:54.000Z'),
  closedAt: MexicoCityTime.parseApi('2026-10-28T18:46:17.000Z'),
  observations: 'Pruebas correctas.',
  answers: const [
    ServiceOrderAnswer('vehiculo_cuenta_con', 'estereo', true),
    ServiceOrderAnswer('vehiculo_cuenta_con', 'inmovilizador', false),
  ],
  tests: const [
    ServiceOrderTest(
      key: 'transmision',
      status: TestStatus.correcta,
      validatedBy: 'Ana López Ruiz',
    ),
    ServiceOrderTest(key: 'boton_panico', status: TestStatus.anulada),
  ],
);

final notCompletedOrder = ServiceOrderRecord(
  id: '4',
  folio: 'OS-000004',
  typeKey: 'revision',
  scheduledTypeKey: 'revision',
  statusKey: 'no_cumplida',
  clientName: 'Grúas Morelos',
  reasonKey: 'cliente_ausente',
  closedAt: MexicoCityTime.parseApi('2026-10-29T10:00:00.000Z'),
);

class _HistoryRepository extends FakeServiceOrderRepository {
  Failure? listFailure;
  final listed = <ServiceOrderStatus?>[];

  _HistoryRepository() : super(closedOrder);

  @override
  Future<PagedServiceOrders> listOrders({
    ServiceOrderStatus? status,
    int page = 1,
    int limit = 50,
  }) {
    listed.add(status);
    if (listFailure != null) throw listFailure!;
    return super.listOrders(status: status, page: page, limit: limit);
  }
}

void main() {
  late _HistoryRepository repository;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await signedInController(
      const User(
        id: '65',
        name: 'Emmanuel Avila',
        email: 'tecnico@next.mx',
        roleId: '8',
      ),
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServiceOrderRepository>.value(value: repository),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        home: const CompletedOrdersPage(),
        routes: {
          AppConstants.orderDetailRoute: (_) => const OrderDetailPage(),
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = _HistoryRepository()
      ..agenda = [closedOrder, notCompletedOrder];
  });

  testWidgets('historial: cerradas por omisión y filtro de no cumplidas',
      (tester) async {
    await pumpPage(tester);

    expect(repository.listed, [ServiceOrderStatus.cerrada]);
    expect(find.text('OS-000003'), findsOneWidget);
    expect(find.text('Transportes del Norte'), findsOneWidget);
    expect(find.text('OS-000004'), findsNothing);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar servicios'), findsOneWidget);

    await tester.tap(find.text('No cumplidas'));
    await tester.pumpAndSettle();

    expect(find.text('Filtrar servicios'), findsNothing);
    expect(repository.listed.last, ServiceOrderStatus.noCumplida);
    expect(find.text('OS-000004'), findsOneWidget);
    expect(find.text('OS-000003'), findsNothing);

    await tester.tap(find.byTooltip('Quitar filtro'));
    await tester.pumpAndSettle();

    expect(repository.listed.last, ServiceOrderStatus.cerrada);
    expect(find.text('OS-000003'), findsOneWidget);
  });

  testWidgets('la etiqueta del tipo usa el color del tipo, como la agenda',
      (tester) async {
    final simChange = ServiceOrderRecord(
      id: '10',
      folio: 'OS-000010',
      typeKey: 'c_sim',
      scheduledTypeKey: 'revision',
      statusKey: 'cerrada',
      clientName: 'Andrea Barajas',
      closedAt: MexicoCityTime.parseApi('2026-11-12T16:19:00.000Z'),
    );
    repository.agenda = [closedOrder, simChange];
    await pumpPage(tester);

    Color? tagColor(String label) => tester
        .widget<ServiceOrderTag>(find.ancestor(
          of: find.text(label),
          matching: find.byType(ServiceOrderTag),
        ))
        .color;

    expect(tagColor('Instalación'), ServiceOrderColors.accent);
    expect(tagColor('Cambio de SIM'), ServiceOrderColors.violet);
  });

  testWidgets('si falla muestra el error y permite reintentar', (tester) async {
    repository.listFailure = const ServerFailure('Sin conexión');
    await pumpPage(tester);

    expect(find.text('Sin conexión'), findsOneWidget);

    repository.listFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('OS-000003'), findsOneWidget);
  });

  testWidgets('el detalle muestra pruebas del operador y permite compartir',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Transportes del Norte'));
    await tester.pumpAndSettle();

    expect(find.text('Orden cerrada'), findsOneWidget);
    expect(find.byTooltip('Ver PDF'), findsOneWidget);
    expect(find.byTooltip('Compartir PDF'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Transmisión'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Correcta'), findsOneWidget);
    expect(find.text('Anulada'), findsOneWidget);
    expect(find.textContaining('Validó Ana López Ruiz'), findsOneWidget);
    expect(find.text('Ana López Ruiz'), findsOneWidget,
        reason: 'monitorista del catálogo');
  });
}
