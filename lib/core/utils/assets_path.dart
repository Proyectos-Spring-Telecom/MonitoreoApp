class AssetsPath {
  // Base path
  static const String images = 'assets/images';

  // Logos
  static const String logos = '$images/logos';

  // Icons
  static const String icons = '$images/icons';

  // Backgrounds
  static const String backgrounds = '$images/backgrounds';

  // Métodos helper para construir paths completos
  static String logo(String filename) => '$logos/$filename';
  static String icon(String filename) => '$icons/$filename';
  static String background(String filename) => '$backgrounds/$filename';
  static String image(String filename) => '$images/$filename';
}
