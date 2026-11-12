# Instaladores Spring (MonitoreoApp)

App de Spring Telecom para los **técnicos instaladores** (rol 8). El técnico atiende en campo las órdenes de servicio que operación le programa en NextAPI: alta, revisión, cambio de SIM, cambio de equipo y desinstalación de equipos GPS en vehículos.

Se usa como **PWA** en `https://springtelecom.mx/ordenservicioapp/`, en el navegador o instalada en Android e iPhone. El mismo código compila para Android e iOS.

## Documentación

| Documento | Contenido |
|---|---|
| [docs/CONTEXTO.md](docs/CONTEXTO.md) | Qué es la app, funcionalidades, reglas de negocio, diseño, arquitectura y decisiones. **Empieza aquí** |
| [docs/CONTRATO.md](docs/CONTRATO.md) | Contrato con el API: endpoints, campos, estatus, catálogos y errores |
| [docs/OPERACION_APLICACION.md](docs/OPERACION_APLICACION.md) | Cómo opera paso a paso: sesión, agenda y flujo completo de una orden |
| [docs/PLAN_PWA.md](docs/PLAN_PWA.md) | Plan de la versión web y, en el Anexo A, compilación, nginx, seguridad y publicación |

## Funcionalidades

- **Acceso:** inicio de sesión solo para técnicos (rol 8), sesión que se conserva al reabrir, renovación automática del token, recuperar contraseña por correo y cambio de contraseña.
- **Inicio:** saludo con el nombre y el rol, accesos a la agenda y al historial.
- **Mi agenda:** órdenes en curso y calendario de las programadas en vista **Agenda** (por día) o **Mes**, con colores por tipo de servicio.
- **Orden de servicio**, guardada en el servidor en cada paso:
  - Iniciar en campo con fecha y ubicación; confirmar el tipo de mantenimiento o atender otro vehículo por placa.
  - Vehículo del alta: buscar por placa o registrarlo con 6 fotos; autorización de operación si ya tiene equipo.
  - Código de verificación en mantenimientos.
  - Equipo y SIM del almacén o reservados al cliente; destino del equipo que sale.
  - Checklist del vehículo con fotos que se suben al tomarse.
  - Pruebas validadas por el operador, monitorista, observaciones y firmas.
  - Resumen con lo que falta y cierre; o «No se pudo realizar» con motivo.
- **Servicios:** historial de órdenes cerradas y no cumplidas con búsqueda y filtro por fecha; detalle con fotos, firmas y pruebas.
- **PDF y compartir:** ver o descargar el PDF; enviarlo por WhatsApp o por correo (1 a 5 destinatarios).
- **Perfil:** datos y foto del técnico.
- **PWA:** se instala, abre sin conexión (solo la interfaz), avisa de versiones nuevas y conserva la orden al recargar.

## Tecnología

Flutter 3.47 · Dart 3 · arquitectura limpia (`core`, `data`, `domain`, `presentation`) · `provider` · `http` · `flutter_secure_storage` · `geolocator` · `image_picker` · `signature`.

```
lib/
├── core/           API, rutas, tema, ubicación, utilidades y código por plataforma
├── data/           Datasources, modelos JSON y repositorios
├── domain/         Entidades, contratos y casos de uso
├── presentation/   Pantallas y controladores (auth, home, agenda, service_order, orders)
└── main.dart       Arma dependencias y arranca
web/                PWA: index.html, manifest, service worker y arranque
tool/build_web.sh   Compilación web para publicar
test/               Pruebas automáticas
```

## Inicio rápido

```bash
flutter pub get
```

```bash
flutter run -d chrome
```

```bash
flutter test
```

- En un teléfono o simulador: `flutter run`.
- API por defecto: `https://springtelecom.mx/nextAPI/api`. Otro: `--dart-define=API_BASE_URL=https://...`.
- Antes de subir cambios: `flutter analyze` sin errores y todos los tests en verde.

## Publicar la versión web

Siempre con el script:

```bash
tool/build_web.sh
```

- El resultado queda en `build/web/` y se sube completo a la carpeta que nginx sirve en `/ordenservicioapp/`.
- Otra ruta: `BASE_HREF=/otra-ruta/ tool/build_web.sh`.
- No hace falta limpiar cachés: quien tenga la app abierta verá «Hay una versión nueva de la app» con **Recargar**.
- Requiere HTTPS: sin él no se puede instalar ni usar la cámara o la ubicación.
- Configuración de nginx, CSP, CORS y verificación: [Anexo A de docs/PLAN_PWA.md](docs/PLAN_PWA.md#anexo-a-publicación-de-la-versión-web).

## Flujo de trabajo

- Se trabaja en la rama `dev_and` y se hace Pull Request a `Dev` con **merge commit**.
- Mensajes de commit con prefijo `[Add]`, `[Update]` o `[Fix]`.
