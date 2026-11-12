import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/presentation/widgets/user_avatar.dart';

/// La foto de perfil es una URL fija de S3. En web, si el navegador tiene una
/// copia guardada sin encabezados CORS, la imagen debe mostrarse con un <img>.
void main() {
  testWidgets('en web la foto usa <img> si falla la carga por CORS',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: UserAvatar(
        imageUrl:
            'https://nextspring.s3.us-east-1.amazonaws.com/Imagenes/user.png',
        name: 'Juan Pérez',
        radius: 24,
      ),
    ));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).webHtmlElementStrategy,
      WebHtmlElementStrategy.fallback,
    );
    // Mientras carga (o si falla) se ven las iniciales.
    expect(find.text('JP'), findsOneWidget);
  });

  testWidgets('sin foto muestra las iniciales', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: UserAvatar(imageUrl: null, name: 'Juan Pérez', radius: 24),
    ));

    expect(find.byType(Image), findsNothing);
    expect(find.text('JP'), findsOneWidget);
  });
}
