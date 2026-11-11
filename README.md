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

## Versión web (PWA)

La app también se publica como PWA en `https://springtelecom.mx/ordenservicioapp/`.

Probar en local (Chrome):

```bash
flutter run -d chrome
```

Compilar para publicar (siempre con el script):

```bash
tool/build_web.sh
```

- El resultado queda en `build/web/`. Se sube completo a la carpeta que nginx sirve en `/ordenservicioapp/`.
- Otra ruta: `BASE_HREF=/otra-ruta/ tool/build_web.sh`. Otro API: agrega `--dart-define=API_BASE_URL=https://...`.
- Las rutas usan `#` (`/ordenservicioapp/#/home`), así que nginx no necesita reglas de reescritura.
- La app abre sin conexión (service worker en `web/sw.js`) y avisa cuando se publica una versión nueva.
- Para instalarla: en Android, Chrome ofrece **Instalar app**. En iPhone, Safari → Compartir → **Agregar a inicio**.
- Requiere HTTPS: sin él, el navegador no permite instalarla ni usar la ubicación o la cámara.
- Configuración de nginx, seguridad y verificación: [docs/PUBLICACION_WEB.md](docs/PUBLICACION_WEB.md).
- Nombre, colores e íconos de la PWA: `web/manifest.json`, `web/index.html` y `web/icons/`.
