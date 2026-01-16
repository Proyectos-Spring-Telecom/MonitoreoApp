# Guía de Colores de la Aplicación

## Colores Principales

- **Azul Principal**: `#001C6A` - `AppColors.primaryBlue`
- **Rojo/Burgundy**: `#681330` - `AppColors.primaryRed`

## Uso en el Código

### Importar

```dart
import 'package:monitoreo/core/constants/app_colors.dart';
```

### Ejemplos de Uso

#### Container con color primario
```dart
Container(
  color: AppColors.primaryBlue,
  child: Text(
    'Texto',
    style: TextStyle(color: AppColors.textOnBlue),
  ),
)
```

#### Botón con color primario
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primaryBlue,
    foregroundColor: AppColors.textOnBlue,
  ),
  onPressed: () {},
  child: Text('Botón'),
)
```

#### AppBar personalizado
```dart
AppBar(
  backgroundColor: AppColors.primaryBlue,
  foregroundColor: AppColors.textOnBlue,
  title: Text('Título'),
)
```

#### Card con borde de color secundario
```dart
Card(
  shape: RoundedRectangleBorder(
    side: BorderSide(color: AppColors.primaryRed, width: 2),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('Contenido'),
)
```

#### Usando el ColorScheme del tema
```dart
// Acceder a través del tema
Container(
  color: Theme.of(context).colorScheme.primary, // Azul principal
  child: Text(
    'Texto',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onPrimary, // Blanco
    ),
  ),
)
```

## Colores Disponibles

### Principales
- `AppColors.primaryBlue` - Azul principal (#001C6A)
- `AppColors.primaryRed` - Rojo/Burgundy (#681330)

### Variaciones
- `AppColors.primaryBlueLight` - Azul claro
- `AppColors.primaryBlueDark` - Azul oscuro
- `AppColors.primaryRedLight` - Rojo claro
- `AppColors.primaryRedDark` - Rojo oscuro

### Texto
- `AppColors.textOnBlue` - Texto sobre azul (blanco)
- `AppColors.textOnRed` - Texto sobre rojo (blanco)

### Fondos
- `AppColors.backgroundLight` - Fondo claro
- `AppColors.backgroundWhite` - Fondo blanco

### Estados
- `AppColors.success` - Éxito (verde)
- `AppColors.warning` - Advertencia (naranja)
- `AppColors.error` - Error (rojo)
- `AppColors.info` - Información (azul principal)

### Neutros
- `AppColors.greyLight` - Gris claro
- `AppColors.greyMedium` - Gris medio
- `AppColors.greyDark` - Gris oscuro
- `AppColors.borderGrey` - Borde gris
