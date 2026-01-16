# Assets - Archivos Multimedia

Esta carpeta contiene todos los archivos multimedia de la aplicación.

## Estructura

```
assets/
├── images/          # Imágenes (PNG, JPG, SVG, etc.)
│   ├── logos/      # Logos de la aplicación
│   ├── icons/      # Iconos personalizados
│   └── backgrounds/ # Fondos e ilustraciones
```

## Uso en el Código

### Imágenes

```dart
// Imagen simple
Image.asset('assets/images/logo.png')

// Con ancho y alto específicos
Image.asset(
  'assets/images/logo.png',
  width: 100,
  height: 100,
)

// Con fit
Image.asset(
  'assets/images/background.jpg',
  fit: BoxFit.cover,
)

// En un Container o Decoration
Container(
  decoration: BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/background.jpg'),
      fit: BoxFit.cover,
    ),
  ),
)
```

### Iconos

```dart
// Usando Image.asset
Image.asset(
  'assets/images/icons/custom_icon.png',
  width: 24,
  height: 24,
)
```

## Formato de Archivos Recomendados

- **Imágenes**: PNG (con transparencia) o JPG
- **Iconos**: PNG o SVG (usando paquete `flutter_svg`)
- **Logos**: PNG o SVG
- **Fondos**: JPG o PNG

## Optimización

- Usa imágenes optimizadas para reducir el tamaño de la app
- Considera usar diferentes resoluciones (@1x, @2x, @3x) si es necesario
- Para imágenes grandes, considera cargarlas de forma lazy o desde URL

## Nota

Después de agregar nuevos assets, ejecuta:
```bash
flutter pub get
```
