import 'package:flutter/material.dart';
import '../service_order/widgets/service_order_ui.dart';

/// Foto de perfil del usuario (`fotoPerfil`) con el aro de degradado de la
/// app. Muestra las iniciales mientras carga, si no hay foto o si falla.
class UserAvatar extends StatelessWidget {
  static const Color _purple = Color(0xFFA78BFA);

  final String? imageUrl;
  final String? name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.radius,
  });

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final initials = parts.map((part) => part[0].toUpperCase()).join();
    return initials.isEmpty ? 'U' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final size = radius * 2;
    final fallback = Center(
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.68,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.all(radius > 30 ? 3 : 2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ServiceOrderColors.accent, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: ServiceOrderColors.accentBackground,
          child: url == null || url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto de perfil',
                  // Web: la URL es fija y el navegador puede tener guardada
                  // una copia sin encabezados CORS (S3 no manda `Vary` si la
                  // petición no trae `Origin`). Si la carga por CORS falla,
                  // se muestra con un <img>, que no los necesita.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous || frame != null ? child : fallback,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}
