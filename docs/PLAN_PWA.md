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
| Fase 0: Preparar el proyecto | ✅ Terminada | 10-nov-2026 |
| Fase 1: Habilitar web y la PWA básica | ✅ Terminada | 10-nov-2026 |
| Fase 2: Bloqueantes de web | ✅ Terminada | 10-nov-2026 |
| Fase 3: Robustez en web | 🟡 Código listo; falta probar en teléfono | 10-nov-2026 |
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
- [x] Hacer commit de los cambios pendientes en `dev_and`.

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

- [x] **2.1 El PDF no abre en web.** Código separado por plataforma en `lib/core/platform/pdf_opener*.dart`: en móvil se abre con el visor del teléfono, igual que antes; en web se descarga como archivo `<folio>.pdf`.
- [x] **2.2 El navegador bloquea WhatsApp.** Solo en web: al terminar la llamada al API aparece "Enlace listo" con el botón **Abrir WhatsApp**, que abre la ventana con ese toque. En móvil se abre directo, como antes.
- [x] **2.3 Se puede entrar sin sesión escribiendo la URL.** `AppRoutes.onGenerateRoute` revisa la sesión al abrir cada pantalla: sin sesión todo va a `/login`; con sesión, `/login` y las rutas desconocidas van a `/home`.
- [x] **2.4 La ubicación se puede quedar colgada.** Máximo 15 s para obtener la posición y 30 s para todo el proceso, incluido el aviso de permiso. Si no llega, en móvil se usa la última posición conocida; si tampoco hay, la orden inicia sin coordenadas.
- [x] **2.5 Recargar a mitad de una orden.** La orden y su detalle ponen el id en la URL (`/#/service-order?id=42`, `/#/order-detail?id=42`). Al recargar se carga desde el API, con el inicio debajo para poder regresar.
- [x] Tests nuevos en `test/core/app_routes_test.dart` (10 casos). Total: 129 tests en verde.

**Criterio de aceptación:**

- [x] En Chrome de Android y en Safari de iPhone se puede iniciar y cerrar una orden completa, y abrir y compartir el PDF.

**Pruebas del 10-nov-2026 (todas correctas):**

- Teléfono: la orden inicia aunque no haya buena señal de GPS.
- Teléfono: el PDF se abre y se envía por correo.
- Web (Chrome): al recargar a mitad de una orden vuelve a la misma orden.
- Web (Chrome): el PDF se descarga.
- Web (Chrome): "Abrir WhatsApp" abre WhatsApp sin que el navegador lo bloquee.
- Web (Chrome): sin sesión, una URL de orden manda al login.

## Fase 3: Robustez en web (2–3 días)

- [x] **3.1 Fotos:** las fotos del checklist y la del equipo encontrado se suben en cuanto se toman. Cada foto muestra si se está enviando (⏳), si ya se envió (✓) o si falló (↻, se toca para reintentar). "Siguiente" y "Solicitar autorización" esperan a que terminen y reintentan las que fallaron.
  - Las fotos del alta de un vehículo nuevo siguen enviándose al registrarlo: el vehículo no existe antes, así que no se pueden subir por separado.
- [x] **3.2 Volver a la app:** mientras la app está oculta se pausa la consulta de cada 12 s. Al volver, la orden se recarga de inmediato si se esperaba la autorización o una prueba, o si pasó más de 1 minuto.
- [x] **3.3 Conversión de imágenes:** en web la conversión a JPG usa el canvas del navegador, que es nativo y no congela la pantalla. En el teléfono sigue en un proceso aparte, igual que antes. La foto ya llegaba reducida (1600 px, calidad 70). El código de web pesa 0.37 MB menos.
- [x] **3.4 Botón atrás:** ya funcionaba con el `PopScope` de la orden. Se agregó un test que lo comprueba: atrás regresa un paso y en el primer paso sale de la orden. En iPhone, la PWA instalada no tiene gesto de atrás del navegador; se usa el botón de la app.
- [x] **3.5 Formularios:** el login usa autocompletado (`username` y `current-password`) y al entrar ofrece guardar la contraseña. Los campos se desplazan solos cuando aparece el teclado. Falta revisarlo en un teléfono real.
- [x] Tests nuevos: 6 del controlador (fotos y volver a la app) y 1 del botón atrás. Total: 136 tests en verde.

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
