# Monitoreo - Aplicación Base Flutter

Proyecto base Flutter con arquitectura limpia y escalable. Desarrollada para generar ordenes de servicio generados por los instaladores

## Estructura del Proyecto

```
lib/
├── core/           # Funcionalidades base y compartidas
├── data/           # Capa de datos (repositorios, modelos, datasources)
├── domain/         # Capa de dominio (entidades, casos de uso)
├── presentation/   # Capa de presentación (UI, controllers)
└── main.dart       # Punto de entrada
```

## Características

- ✅ Login con autenticación mock
- ✅ Menú lateral (Drawer)
- ✅ Navegación inferior (Bottom Navigation)
- ✅ Perfil de usuario
- ✅ Cierre de sesión
- ✅ Arquitectura Clean Architecture
- ✅ Gestión de estado con Provider
- ✅ Preparado para consumo de APIs REST

## Inicio Rápido

```bash
flutter pub get
flutter run
```
