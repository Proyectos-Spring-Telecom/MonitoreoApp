# Estructura del Proyecto

Este documento explica la organización del proyecto según Clean Architecture.

## 📁 Estructura de Carpetas

```
lib/
├── core/                    # Funcionalidades base y compartidas
│   ├── constants/          # Constantes de la aplicación
│   │   └── app_constants.dart
│   ├── errors/             # Manejo de errores
│   │   └── failures.dart
│   ├── network/            # Cliente HTTP y configuración de red
│   │   └── api_client.dart
│   ├── routes/             # Configuración de rutas
│   │   └── app_routes.dart
│   ├── theme/              # Tema de la aplicación
│   │   └── app_theme.dart
│   └── utils/              # Utilidades generales
│       └── validators.dart
│
├── data/                    # Capa de datos
│   ├── datasources/        # Fuentes de datos
│   │   ├── local/          # Almacenamiento local
│   │   │   ├── local_storage.dart
│   │   │   └── auth_local_datasource.dart
│   │   └── remote/         # APIs remotas
│   │       └── auth_remote_datasource.dart
│   ├── models/             # Modelos de datos (JSON)
│   │   └── user_model.dart
│   └── repositories/       # Implementación de repositorios
│       └── auth_repository_impl.dart
│
├── domain/                  # Capa de dominio (lógica de negocio)
│   ├── entities/           # Entidades del dominio
│   │   └── user.dart
│   ├── repositories/       # Contratos de repositorios
│   │   └── auth_repository.dart
│   └── usecases/           # Casos de uso
│       ├── login_usecase.dart
│       ├── logout_usecase.dart
│       └── get_current_user_usecase.dart
│
├── presentation/            # Capa de presentación (UI)
│   ├── auth/               # Módulo de autenticación
│   │   ├── login/
│   │   │   └── login_page.dart
│   │   └── profile/
│   │       └── profile_page.dart
│   ├── home/               # Módulo principal
│   │   ├── drawer/
│   │   │   └── app_drawer.dart
│   │   ├── bottom_navigation/
│   │   │   └── bottom_navigation_widget.dart
│   │   └── home_page.dart
│   ├── controllers/        # Controladores de estado
│   │   └── auth_controller.dart
│   └── widgets/            # Widgets reutilizables
│       ├── loading_widget.dart
│       └── error_widget.dart
│
└── main.dart               # Punto de entrada
```

## 🏗️ Arquitectura

### Clean Architecture

El proyecto sigue los principios de Clean Architecture con tres capas principales:

1. **Domain (Dominio)**
   - Contiene la lógica de negocio pura
   - No depende de otras capas
   - Define entidades, contratos de repositorios y casos de uso

2. **Data (Datos)**
   - Implementa los contratos definidos en Domain
   - Maneja fuentes de datos (local y remoto)
   - Convierte modelos de datos a entidades del dominio

3. **Presentation (Presentación)**
   - Maneja la UI y la interacción del usuario
   - Usa controladores para gestionar el estado
   - Depende de Domain, no de Data

### Flujo de Datos

```
UI (Presentation) 
  ↓
Controller (Presentation)
  ↓
UseCase (Domain)
  ↓
Repository (Domain contract)
  ↓
Repository Implementation (Data)
  ↓
DataSource (Data)
```

## 🔐 Autenticación

### Flujo Actual (Mock)

1. Usuario ingresa email y contraseña
2. `LoginUseCase` valida y llama al repositorio
3. `AuthRemoteDataSource` simula una llamada API (mock)
4. Si es exitoso, se guarda el usuario y token localmente
5. El usuario es redirigido a Home

### Preparado para API Real

Para conectar con una API real:

1. Modificar `AuthRemoteDataSourceImpl.login()` en:
   ```
   lib/data/datasources/remote/auth_remote_datasource.dart
   ```

2. Descomentar el código de ejemplo que usa `ApiClient`

3. Configurar `AppConstants.baseUrl` con tu URL de API

## 📦 Gestión de Estado

Se utiliza **Provider** para la gestión de estado:

- `AuthController`: Maneja el estado de autenticación
- Estados: `initial`, `loading`, `authenticated`, `unauthenticated`, `error`
- Los widgets escuchan cambios mediante `Consumer` o `watch`

## 🎨 Tema

El tema está configurado en `core/theme/app_theme.dart` usando Material 3.

## 🧭 Navegación

- **Rutas centralizadas**: `core/routes/app_routes.dart`
- **Bottom Navigation**: 3 tabs (Inicio, Dashboard, Perfil)
- **Drawer**: Accesible desde Home, contiene perfil y logout

## 📝 Próximos Pasos

1. Conectar con API real (modificar `AuthRemoteDataSource`)
2. Agregar más módulos siguiendo la misma estructura
3. Implementar manejo de errores más robusto
4. Agregar tests unitarios y de integración
5. Implementar refresh token si es necesario

## 🚀 Comandos Útiles

```bash
# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run

# Analizar código
flutter analyze

# Formatear código
flutter format lib/
```
