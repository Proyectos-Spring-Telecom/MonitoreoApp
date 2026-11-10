# Plan de resolución: MonitoreoApp como PWA

La app de instaladores debe funcionar también como PWA, sin romper Android ni iOS.

Cada fase se da por terminada cuando:

- `flutter analyze` no marca errores.
- Todos los tests pasan.
- Se revisó en el navegador.

**Estimado total:** de 8 a 12 días de trabajo, más lo que necesiten backend y servidor en la Fase 4.

## Avance

| Fase | Estado | Fecha |
|---|---|---|
| Fase 0: Preparar el proyecto | ✅ Terminada (sin commit) | 10-nov-2026 |
| Fase 1: Habilitar web y la PWA básica | ✅ Terminada (sin commit) | 10-nov-2026 |
| Fase 2: Bloqueantes de web | ⬜ Pendiente | |
| Fase 3: Robustez en web | ⬜ Pendiente | |
| Fase 4: Seguridad, caché y rendimiento | ⬜ Pendiente | |
| Fase 5: Pruebas y publicación | ⬜ Pendiente | |

## Decisiones tomadas (10-nov-2026)

- [x] **Dónde se publica:** `https://springtelecom.mx/instaladores/`. La app se compila con `--base-href /instaladores/`.
- [x] **Offline, opción A:** la app abre sin conexión con su interfaz en caché. Para operar necesita red y no hay cola offline.
- [x] **URLs con `#`:** las direcciones quedan como `/instaladores/#/home`. nginx no necesita reglas de reescritura.
- [x] **Fotos:** cada foto se sube al API en cuanto se toma.

---

## Fase 0: Preparar el proyecto (½ día) ✅

- [x] Agregar `cupertino_icons`. Sin ese paquete, los íconos que usa Flutter (por ejemplo en la barra para copiar y pegar en iOS y Safari) se veían como cuadros.
- [x] Quitar la dependencia `permission_handler`, que no se usaba.
- [x] Borrar `assets/images/backgrounds/bienvenida-1.jpg`. Pesaba 6.3 MB y no se usaba.
- [ ] Hacer commit de los cambios pendientes en `dev_and`.

**Criterio de aceptación:**

- [x] Android funciona igual que antes y el paquete pesa unos 6 MB menos.

> ⚠️ **iOS aparte:** Flutter 3.47 pide como mínimo iOS 15.0 y el proyecto tiene 13.0, por eso falla `pod install`. Subir el mínimo deja fuera iOS 13 y 14. Esa decisión está pendiente.

## Fase 1: Habilitar web y la PWA básica (1 día) ✅

- [x] Crear la carpeta `web/` con `flutter create --platforms=web .`.
- [x] Personalizar `web/manifest.json`:
  - Nombre "Instaladores Spring" y nombre corto "Instaladores", en `es-MX`.
  - Colores `#09081C`.
  - `start_url` y `scope` relativos a `/instaladores/`.
  - Orientación vertical.
- [x] Íconos en `web/icons/`:
  - 192 y 512.
  - Versiones con margen para Android (maskable), con fondo `#0B3FCF`.
  - Ícono para iPhone (`apple-touch-icon`).
  - Favicon con el rombo de Spring.
- [x] Ajustar `web/index.html`:
  - Título y descripción.
  - Color de la barra (`theme-color`).
  - Etiquetas para instalar en iPhone.
  - Pantalla de carga con el ícono.
  - Aviso para quien tenga JavaScript desactivado.
- [x] Cambiar el título de la app a "Instaladores Spring" en `lib/main.dart`.
- [x] Documentar en el README cómo compilar y publicar la versión web.

**Criterios de aceptación:**

- [x] Compila con `flutter build web --release --base-href /instaladores/` y abre el login sin errores en la consola.
- [ ] Se instala desde Chrome en Android con el nombre y el ícono correctos.
- [ ] Se instala con "Agregar a inicio" en Safari de iPhone. Requiere HTTPS, así que se prueba cuando esté publicada.

## Fase 2: Bloqueantes de web (2–3 días)

- [ ] **2.1 El PDF no abre en web.** Separar el código por plataforma: en móvil sigue igual; en web se descarga o se abre en otra pestaña. Archivos: `order_share_sheet.dart` y uno nuevo para la descarga en web.
- [ ] **2.2 El navegador bloquea WhatsApp.** Al terminar la llamada al API, mostrar un botón "Abrir WhatsApp" para que la ventana se abra con el toque del usuario. Archivo: `order_share_sheet.dart`.
- [ ] **2.3 Se puede entrar sin sesión escribiendo la URL.** Proteger las rutas en un solo lugar: sin sesión, todo va a `/login`. Cuando la sesión expire, regresar siempre al login. Archivos: `app_routes.dart` y `main.dart`.
- [ ] **2.4 La ubicación se puede quedar colgada.** Ponerle un tiempo máximo de unos 10 s y, si no llega, iniciar sin coordenadas. Archivo: `location_service.dart`.
- [ ] **2.5 Recargar a mitad de una orden.** Poner el id de la orden en la URL (`/service-order?id=42`) para que al recargar se cargue desde el API. Archivos: `app_routes.dart` y las páginas de la orden y del detalle.

**Criterio de aceptación:**

- [ ] En Chrome de Android y en Safari de iPhone se puede iniciar y cerrar una orden completa, y abrir y compartir el PDF.

## Fase 3: Robustez en web (2–3 días)

- [ ] **3.1 Fotos:** subir cada foto en cuanto se toma, con avance y opción de reintentar si falla. Así no se pierden si iOS recarga la página al abrir la cámara.
- [ ] **3.2 Volver a la app:** al regresar del portal o de WhatsApp, recargar la orden de inmediato. Mientras la app está oculta, pausar la consulta automática que hoy se hace cada 12 s.
- [ ] **3.3 Conversión de imágenes:** en web, convertir una foto grande congela la pantalla. Pedir a la cámara del navegador la imagen ya reducida en JPG, para que casi nunca haya que convertirla, y avisar cuando se esté procesando.
- [ ] **3.4 Botón atrás:** que el botón atrás del navegador y el gesto de iOS regresen de paso en paso dentro de la orden, como en la app.
- [ ] **3.5 Formularios:** revisar que el teclado no tape campos en el navegador del teléfono y activar el autocompletado del login.

**Criterio de aceptación:**

- [ ] Se puede cambiar de app a mitad de la orden y volver sin perder nada, con el estado actualizado.

## Fase 4: Seguridad, caché y rendimiento (1–2 días + servidor)

- [ ] **Caché:** service worker que guarde la interfaz (offline A) y avise "Hay una versión nueva, recargar".
- [ ] **Sesión en web:** revisar con backend cuánto duran los tokens. Opcionalmente, guardar solo en memoria el token que expira pronto.
- [ ] **Servidor:** en nginx, para `/instaladores/`:
  - [ ] HTTPS obligatorio.
  - [ ] `index.html` sin caché.
  - [ ] El resto de los archivos con caché larga.
  - [ ] Encabezados de seguridad: CSP y `X-Frame-Options`.
- [ ] **S3:** CORS del bucket de fotos para el dominio de la PWA.
- [ ] **API:** cambiar `access-control-allow-origin: *` por el dominio de la PWA.
- [ ] **Rendimiento:** medir la primera carga y probar la compilación `--wasm`.

**Criterio de aceptación:**

- [ ] Lighthouse marca la PWA como instalable y la primera carga en 4G queda en el tiempo acordado.

## Fase 5: Pruebas y publicación (1–2 días)

- [ ] Tests nuevos para:
  - [ ] Rutas protegidas.
  - [ ] Tiempo máximo de la ubicación.
  - [ ] Recarga de la orden al volver a la app.
  - [ ] Descarga del PDF.
- [ ] Revisión manual con una orden real en el ambiente de pruebas:
  - [ ] Android con Chrome.
  - [ ] iPhone con Safari, instalada en inicio.
  - [ ] Escritorio.
- [ ] Documentar la publicación en `docs/`: compilar, subir y limpiar caché.
- [ ] Anotar la entrega en la bitácora (`docs/PLAN_IMPLEMENTACION_API.md`).

---

## Pendientes fuera del plan

- [ ] **Backend:** error 500 al volver a solicitar una prueba fallida. Ver `docs/SOLICITUD_BACKEND_REINTENTO_PRUEBA.md`.
- [ ] **Backend:** confirmar los filtros de "Atender otro vehículo".
- [ ] **Backend:** confirmar si las fotos del vehículo son obligatorias.
- [ ] **Backend:** confirmar cómo se detecta que la orden necesita autorización.
- [ ] **iOS:** decidir si se sube el mínimo a iOS 15.0.
