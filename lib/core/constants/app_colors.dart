import 'package:flutter/material.dart';

/// Colores globales de la aplicación
class AppColors {
  AppColors._(); // Constructor privado para evitar instanciación

  // Colores principales
  /// Azul oscuro principal: #001C6A
  static const Color primaryBlue = Color(0xFF001C6A);

  /// Rojo/Burgundy oscuro: #681330
  static const Color primaryRed = Color(0xFF681330);

  // Colores de texto
  /// Texto sobre fondo azul
  static const Color textOnBlue = Colors.white;

  /// Texto sobre fondo rojo
  static const Color textOnRed = Colors.white;

  // Colores de fondo
  /// Fondo oscuro principal: #09081C
  static const Color backgroundDark = Color(0xFF09081C);

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

  /// Gris oscuro
  static const Color greyDark = Color(0xFF424242);
}
