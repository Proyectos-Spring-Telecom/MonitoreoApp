import 'package:flutter/material.dart';

/// Colores globales de la aplicación
class AppColors {
  AppColors._(); // Constructor privado para evitar instanciación

  // Colores principales
  /// Azul oscuro principal: #001C6A
  static const Color primaryBlue = Color(0xFF001C6A);

  /// Rojo/Burgundy oscuro: #681330
  static const Color primaryRed = Color(0xFF681330);

  // Variaciones del azul principal
  /// Azul más claro (para hover, estados activos)
  static const Color primaryBlueLight = Color(0xFF0033A0);

  /// Azul más oscuro (para sombras, profundidad)
  static const Color primaryBlueDark = Color(0xFF001144);

  // Variaciones del rojo principal
  /// Rojo más claro (para hover, estados activos)
  static const Color primaryRedLight = Color(0xFF8B1A42);

  /// Rojo más oscuro (para sombras, profundidad)
  static const Color primaryRedDark = Color(0xFF4D0E24);

  // Colores de texto
  /// Texto sobre fondo azul
  static const Color textOnBlue = Colors.white;

  /// Texto sobre fondo rojo
  static const Color textOnRed = Colors.white;

  // Colores de fondo
  /// Fondo oscuro principal: #09081C
  static const Color backgroundDark = Color(0xFF09081C);

  /// Fondo claro para contraste
  static const Color backgroundLight = Color(0xFFF5F5F5);

  /// Fondo blanco
  static const Color backgroundWhite = Colors.white;

  // Colores de estado
  /// Éxito
  static const Color success = Color(0xFF4CAF50);

  /// Advertencia
  static const Color warning = Color(0xFFFF9800);

  /// Error
  static const Color error = Color(0xFFF44336);

  /// Información
  static const Color info = primaryBlue;

  // Colores neutros
  /// Gris claro
  static const Color greyLight = Color(0xFFE0E0E0);

  /// Gris medio
  static const Color greyMedium = Color(0xFF9E9E9E);

  /// Gris oscuro
  static const Color greyDark = Color(0xFF424242);

  /// Borde gris
  static const Color borderGrey = Color(0xFFBDBDBD);

  // Colores de campos de texto
  /// Color de fondo para TextFields: #38384A
  static const Color textFieldBackground = Color(0xFF38384A);
}
