import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/core/constants/app_colors.dart';
import 'package:monitoreo/core/theme/app_theme.dart';

/// Al abrir una pantalla, la anterior se desvanece sobre un fondo. En Android
/// ese fondo era `colorScheme.surface` (blanco) y se veía un destello blanco.
void main() {
  final theme = AppTheme.lightTheme;
  final surface = theme.colorScheme.surface;

  /// Colores de fondo pintados a mitad de la transición.
  Future<Set<Color>> backgroundsDuringPush(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Text('Agenda'),
      ),
    ));

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Text('Detalle'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final colors = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((box) => box.color)
        .toSet();
    await tester.pumpAndSettle();
    expect(find.text('Detalle'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    return colors;
  }

  test('Android usa la transición de Flutter con el fondo oscuro', () {
    final android = theme.pageTransitionsTheme.builders[TargetPlatform.android];
    expect(android, isA<PredictiveBackPageTransitionsBuilder>());
    expect(
      (android! as PredictiveBackPageTransitionsBuilder).fallbackColor,
      AppColors.backgroundDark,
    );
  });

  test('iOS y macOS conservan la transición deslizante', () {
    final builders = theme.pageTransitionsTheme.builders;
    expect(
        builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(
      builders[TargetPlatform.macOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  testWidgets('Android: sin fondo blanco a mitad de la transición',
      (tester) async {
    final colors = await backgroundsDuringPush(tester, TargetPlatform.android);
    expect(colors, isNot(contains(surface)));
    expect(colors, contains(AppColors.backgroundDark));
  });

  testWidgets('iOS: la transición no pinta fondo blanco', (tester) async {
    final colors = await backgroundsDuringPush(tester, TargetPlatform.iOS);
    expect(colors, isNot(contains(surface)));
  });
}
