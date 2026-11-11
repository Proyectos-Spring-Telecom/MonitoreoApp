import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  /// Transiciones entre pantallas. Son las mismas que usa Flutter por
  /// defecto, pero con el fondo oscuro de la app: en Android (y Windows/Linux)
  /// la pantalla que sale se desvanece sobre `colorScheme.surface`, que aquí
  /// es blanco, y se veía un destello blanco al abrir cualquier pantalla.
  /// iOS y macOS conservan su transición deslizante, que no pinta fondo.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
        fallbackColor: AppColors.backgroundDark,
      ),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(
        backgroundColor: AppColors.backgroundDark,
      ),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(
        backgroundColor: AppColors.backgroundDark,
      ),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // En web, Roboto (incluida en la app) para todos los textos. En iOS,
      // Flutter pide la fuente del sistema de Apple, que en el navegador no
      // existe, y cada carácter se busca en otras fuentes: en algunos
      // iPhone los números salían con otra fuente, separados y partidos.
      // En el teléfono se deja la fuente del sistema.
      fontFamily: kIsWeb ? 'Roboto' : null,
      pageTransitionsTheme: pageTransitions,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryRed,
        surface: AppColors.backgroundWhite,
        error: AppColors.error,
        onPrimary: AppColors.textOnBlue,
        onSecondary: AppColors.textOnRed,
        onSurface: AppColors.greyDark,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
