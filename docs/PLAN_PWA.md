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
| Fase 3: Robustez en web | ✅ Terminada | 11-nov-2026 |
| Fase 4: Seguridad, caché y rendimiento | 🟡 Servidor configurado el 11-nov-2026; faltan la revisión de sesión con backend, pasar la CSP a obligatoria y el tiempo de carga en 4G | 11-nov-2026 |
| Fase 5: Pruebas y publicación | ✅ Terminada | 12-nov-2026 |

## Decisiones tomadas (10-nov-2026)

- [x] **Dónde se publica:** `https://springtelecom.mx/ordenservicioapp/` (antes se había planeado `/instaladores/`). La app se compila con `tool/build_web.sh`, que usa `--base-href /ordenservicioapp/`.
- [x] **Offline, opción A:** la app abre sin conexión con su interfaz en caché. Para operar necesita red y no hay cola offline.
- [x] **URLs con `#`:** las direcciones quedan como `/ordenservicioapp/#/home`. nginx no necesita reglas de reescritura.
- [x] **Fotos:** cada foto se sube al API en cuanto se toma.

---

## Fase 0: Preparar el proyecto (½ día) ✅

- [x] Agregar `cupertino_icons`. Sin ese paquete, los íconos que usa Flutter (por ejemplo en la barra para copiar y pegar en iOS y Safari) se veían como cuadros.
- [x] Quitar la dependencia `permission_handler`, que no se usaba.
- [x] Borrar `assets/images/backgrounds/bienvenida-1.jpg`. Pesaba 6.3 MB y no se usaba.
- [x] Hacer commit de los cambios pendientes en `dev_and`.

**Criterio de aceptación:**

- [x] Android funciona igual que antes y el paquete pesa unos 6 MB menos.

> ✅ **iOS aparte:** Flutter 3.47 pide como mínimo iOS 15.0. El mínimo se subió a 15.0 el 11-nov-2026 (ver Pendientes fuera del plan).

## Fase 1: Habilitar web y la PWA básica (1 día) ✅

- [x] Crear la carpeta `web/` con `flutter create --platforms=web .`.
- [x] Personalizar `web/manifest.json`:
  - Nombre "Instaladores Spring" y nombre corto "Instaladores", en `es-MX`.
  - Colores `#09081C`.
  - `start_url` y `scope` relativos a `/ordenservicioapp/`.
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

- [x] Compila con `flutter build web --release --base-href /ordenservicioapp/` y abre el login sin errores en la consola.
- [x] Se instala desde Chrome en Android con el nombre y el ícono correctos (probado el 11-nov-2026).
- [x] Se instala con "Agregar a inicio" en Safari de iPhone (probado el 11-nov-2026 en `https://springtelecom.mx/ordenservicioapp/`).

## Fase 2: Bloqueantes de web (2–3 días) ✅

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

## Fase 3: Robustez en web (2–3 días) ✅

- [x] **3.1 Fotos:** las fotos del checklist y la del equipo encontrado se suben en cuanto se toman. Cada foto muestra si se está enviando (⏳), si ya se envió (✓) o si falló (↻, se toca para reintentar). "Siguiente" y "Solicitar autorización" esperan a que terminen y reintentan las que fallaron.
  - Las fotos del alta de un vehículo nuevo siguen enviándose al registrarlo: el vehículo no existe antes, así que no se pueden subir por separado.
- [x] **3.2 Volver a la app:** mientras la app está oculta se pausa la consulta de cada 12 s. Al volver, la orden se recarga de inmediato si se esperaba la autorización o una prueba, o si pasó más de 1 minuto.
- [x] **3.3 Conversión de imágenes:** en web la conversión a JPG usa el canvas del navegador, que es nativo y no congela la pantalla. En el teléfono sigue en un proceso aparte, igual que antes. La foto ya llegaba reducida (1600 px, calidad 70). El código de web pesa 0.37 MB menos.
- [x] **3.4 Botón atrás:** ya funcionaba con el `PopScope` de la orden. Se agregó un test que lo comprueba: atrás regresa un paso y en el primer paso sale de la orden. En iPhone, la PWA instalada no tiene gesto de atrás del navegador; se usa el botón de la app.
- [x] **3.5 Formularios:** el login usa autocompletado (`username` y `current-password`) y al entrar ofrece guardar la contraseña. Los campos se desplazan solos cuando aparece el teclado. Falta revisarlo en un teléfono real.
- [x] Tests nuevos: 6 del controlador (fotos y volver a la app) y 1 del botón atrás. Total: 136 tests en verde.

**Criterio de aceptación:**

- [x] Se puede cambiar de app a mitad de la orden y volver sin perder nada, con el estado actualizado. Probado el 11-nov-2026.

## Fase 4: Seguridad, caché y rendimiento (1–2 días + servidor)

- [x] **Caché:** service worker propio (`web/sw.js`) que siempre pide primero la red y usa la caché sin conexión. Probado en local: la app abre con el servidor apagado.
- [x] **Aviso de versión nueva:** al volver a la app o cada 30 min se compara `build.json` con la versión abierta. Si cambió, aparece "Hay una versión nueva de la app" con **Recargar**. Probado en local y en producción (11-nov-2026). Va en la parte superior, debajo de la barra del título, para no tapar la barra inferior; confirmado en el servidor.
- [x] **Compilación:** `tool/build_web.sh` compila, marca la versión y sirve el motor y las fuentes desde nuestro servidor (sin `gstatic.com`).
- [x] **Arranque sin el service worker obsoleto de Flutter:** `web/flutter_bootstrap.js` evita que reemplace al nuestro.
- [x] **Guía de publicación:** [Anexo A](#anexo-a-publicación-de-la-versión-web) con nginx, CSP, CORS, sesión, rendimiento y verificación.
- [ ] **Sesión en web:** revisar con backend la duración de los tokens, la rotación del refresh token y que el logout lo invalide (lista en el Anexo A.5).
- [x] **Servidor (equipo de infraestructura), según el Anexo A.4:** aplicado y verificado el 11-nov-2026.
  - [x] HTTPS obligatorio.
  - [x] `Cache-Control: no-cache` en todo, con revalidación (304). No se usa caché larga porque los archivos de Flutter no llevan hash en el nombre.
  - [x] Encabezados de seguridad: CSP primero como `Report-Only`, más `X-Frame-Options`, `nosniff`, `Referrer-Policy` y `Permissions-Policy`.
  - [x] Compresión gzip para `.js`, `.wasm`, `.json` y fuentes.
- [x] **S3:** el bucket ya permite `GET` desde cualquier origen (`*`). No hace falta cambiarlo.
- [x] **API:** la PWA y el API están en el mismo dominio, así que la PWA no necesita CORS. Restringir `*` queda como mejora de seguridad del API.
- [x] **Rendimiento:** primera carga de 3.1 MB en Chrome y 3.9 MB en Safari (gzip), unos 3–4 s en 4G. `--wasm` compila y baja Chrome a 2.6 MB, pero falta probarla antes de adoptarla.
- [x] **CSP probada en local:** login, service worker y fotos de S3 sin errores.
- [ ] **CSP obligatoria:** probarla con sesión iniciada en producción (está en `Report-Only`) y, sin avisos, cambiarla a `Content-Security-Policy` (Anexo A.5).

**Criterio de aceptación:**

- [ ] Lighthouse marca la PWA como instalable y la primera carga en 4G queda en el tiempo acordado.
  - [x] Instalable: Lighthouse sin errores (11-nov-2026).
  - [ ] Tiempo de primera carga en 4G: falta acordarlo y medirlo.

**Verificación en producción (11-nov-2026):** login, service worker activo, apertura sin conexión e instalación en iPhone, todo correcto. El aviso de versión nueva también funciona, en el navegador y en la PWA instalada en iPhone. La instalación en Android también funciona.

## Fase 5: Pruebas y publicación (1–2 días) ✅

- [x] Tests nuevos para:
  - [x] Rutas protegidas: `test/core/app_routes_test.dart` (10 casos).
  - [x] Tiempo máximo de la ubicación: `test/core/location_service_test.dart` (7 casos, con GPS simulado y reloj controlado).
  - [x] Recarga de la orden al volver a la app: grupo "al salir y volver a la app" en `test/presentation/service_order_flow_controller_test.dart`.
  - [x] Descarga del PDF: `test/presentation/order_pdf_test.dart` (4 casos). La descarga en el navegador se probó a mano (Fase 2).
- [x] Revisión manual con una orden real en el ambiente de pruebas (11-nov-2026, todo correcto):
  - [x] Android con Chrome.
  - [x] iPhone con Safari, instalada en inicio.
  - [x] Escritorio.
- [x] Documentar la publicación en `docs/`: compilar, subir y limpiar caché. Ver el Anexo A; la caché no se limpia a mano, el aviso de versión nueva se encarga.
- [x] Anotar la entrega en la bitácora, 12-nov-2026. Las decisiones quedaron en [CONTEXTO.md](CONTEXTO.md) §9.

---

## Pendientes fuera del plan

- [x] **Backend:** error 500 al volver a solicitar una prueba fallida. Resuelto por backend y probado (11-nov-2026).
- [ ] **Backend:** confirmar los filtros de "Atender otro vehículo".
- [x] **Backend:** confirmar si las fotos del vehículo son obligatorias. Sí lo son, porque se toman al hacer la instalación (11-nov-2026). Al registrar un vehículo nuevo en un alta, la app ya exige las 6 (principal, frontal, trasera, laterales y tarjeta de circulación) y muestra cuáles faltan.
- [ ] **Backend:** confirmar cómo se detecta que la orden necesita autorización.
- [x] **iOS:** el mínimo subió a iOS 15.0 (11-nov-2026) en `ios/Podfile`, el proyecto de Xcode y `AppFrameworkInfo.plist`. `pod install` ya funciona y la app compila para iOS. La app se usará siempre como PWA en Android e iOS; la versión nativa solo se mantiene compilable.
- [x] **Web:** la foto de perfil se bloqueaba por CORS cuando el navegador tenía guardada una copia sin encabezados. Ahora, si falla, se muestra con `<img>`. Validado en navegador y en la PWA en Android e iOS (12-nov-2026).

---

## Anexo A: Publicación de la versión web

Cómo compilar y publicar la app en `https://springtelecom.mx/ordenservicioapp/`, y qué debe configurar el servidor.

### A.1 Compilar

Siempre con el script, no con `flutter build web` directo:

```bash
tool/build_web.sh
```

Variantes:

| Caso | Comando |
|---|---|
| Otra ruta en el servidor | `BASE_HREF=/otra-ruta/ tool/build_web.sh` |
| Otro API | `tool/build_web.sh --dart-define=API_BASE_URL=https://...` |
| Versión WebAssembly (ver A.6) | `tool/build_web.sh --wasm` |

El script hace tres cosas además de compilar:

1. Usa `--no-web-resources-cdn`: el motor de Flutter (CanvasKit) y las fuentes se sirven desde nuestro servidor y no desde `gstatic.com`. Así quedan en la caché offline y la CSP no necesita dominios de Google.
2. Pone un número de compilación (fecha + commit) en `sw.js` y `pwa.js`.
3. Escribe ese número en `build.json`. Con él la app detecta que se publicó una versión nueva.

> Si se compila con `flutter build web` sin el script, la app funciona pero **no** registra el service worker. Sin él no abre sin conexión ni avisa de versiones nuevas.

### A.2 Publicar

1. Copiar **todo** el contenido de `build/web/` a la carpeta que nginx sirve en `/ordenservicioapp/`, reemplazando lo anterior.
2. No hace falta limpiar cachés a mano:
   - Quien tenga la app abierta verá **"Hay una versión nueva de la app"** con el botón **Recargar**. El aviso aparece al volver a la app o, como máximo, 30 minutos después.
   - Quien la abra después recibe la versión nueva directamente.

### A.3 Cómo funciona la caché (offline nivel A)

- `web/sw.js` (service worker) siempre pide primero la versión de la red. Solo sin conexión usa la copia guardada. Los archivos de Flutter no llevan hash en el nombre (`main.dart.js`), así que servir primero la caché podría mezclar versiones.
- Sin conexión, la app abre y muestra la interfaz. Operar requiere red.
- **Nunca** se guardan respuestas del API ni fotos de S3.
- Cada compilación usa su propia caché (`instaladores-<número>`). La anterior se borra al activarse la nueva.
- `web/flutter_bootstrap.js` arranca Flutter **sin** su service worker, que está obsoleto: se da de baja solo y reemplazaría al nuestro.

### A.4 Configuración de nginx

> **Estado (11-nov-2026): aplicada en el servidor.** Infraestructura la aplicó y se verificó desde internet:
> - `/`, `index.html`, `sw.js`, `build.json`, `main.dart.js` y `canvaskit.wasm` responden con `Cache-Control: no-cache`, el tipo correcto (`.wasm` como `application/wasm`) y gzip. `build.json` no se comprime porque pesa 43 bytes.
> - Cada encabezado de seguridad sale una sola vez: HSTS, `nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY`, `Permissions-Policy` (cámara y ubicación permitidas) y la CSP en modo `Report-Only`, igual a la de este anexo.
> - `/ordenservicioapp` sin barra redirige con 301 a `/ordenservicioapp/`. Una ruta inexistente dentro de la app devuelve `index.html`.
> - Este bloque **no** usa `snippets/spring-headers.conf`, el del resto del sitio: ese snippet bloquea la cámara y la ubicación (`camera=(), geolocation=()`) y su CSP no permite las fotos de S3. El resto de `springtelecom.mx` sigue con su snippet.
> - Respaldo de la configuración anterior: `/etc/nginx/sites-available/springtelecom.bak-2026-11-11-143945`.

Ejemplo para `/ordenservicioapp/`. La ruta de la carpeta (`/var/www/ordenservicioapp/`) es ilustrativa; ajústala a la del servidor.

```nginx
location /ordenservicioapp/ {
    alias /var/www/ordenservicioapp/;
    index index.html;

    # Los nombres no llevan hash: el navegador siempre pregunta si cambió y
    # el servidor responde 304 si no. index.html, sw.js y build.json deben
    # revalidarse siempre para detectar versiones nuevas.
    add_header Cache-Control "no-cache" always;

    # Seguridad (ver A.5).
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Frame-Options "DENY" always;
    add_header Permissions-Policy "camera=(self), geolocation=(self), microphone=()" always;
    add_header Content-Security-Policy-Report-Only "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https://nextspring.s3.us-east-1.amazonaws.com; connect-src 'self' https://nextspring.s3.us-east-1.amazonaws.com; font-src 'self' data:; worker-src 'self' blob:; manifest-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'" always;
}

# Compresión: main.dart.js baja de 3.4 MB a 1 MB y canvaskit.wasm de 5.4 a 2 MB.
gzip on;
gzip_types application/javascript application/wasm application/json
           application/manifest+json font/otf font/ttf image/svg+xml;
```

Puntos a revisar en el servidor:

- [x] **HTTPS:** obligatorio. Sin él no se puede instalar la app ni usar la cámara o la ubicación. El dominio ya envía `Strict-Transport-Security`.
- [x] **Tipo de los `.wasm`:** deben servirse como `application/wasm`. Las versiones recientes de nginx ya lo traen en `mime.types`; si no, agrégalo.
- [x] **`add_header` dentro de otro `location`:** si se agrega uno, nginx deja de heredar los encabezados del padre y hay que repetirlos.
- [x] **No cachear en el CDN o proxy** `index.html`, `sw.js` ni `build.json`, si hay alguno delante de nginx.

### A.5 Seguridad

#### Content Security Policy (CSP)

La política de A.4 se probó en local con la app compilada:

- Carga el login, registra el service worker y descarga fotos de S3 sin errores.
- **Falta probarla con sesión iniciada:** agenda, fotos, PDF y WhatsApp.

Por eso se publica primero como **`Content-Security-Policy-Report-Only`**, que solo avisa en la consola sin bloquear nada. Cuando una semana de uso no muestre avisos, cambiar el nombre del encabezado a `Content-Security-Policy`.

- [x] Publicada en modo `Report-Only` (11-nov-2026).
- [ ] Probar con sesión iniciada (agenda, fotos, PDF, WhatsApp, firmas) revisando la consola: los avisos empiezan con `[Report Only] Refused to…`.
- [ ] Sin avisos: pedir a infraestructura que cambie el encabezado a `Content-Security-Policy`.

Por qué lleva cada permiso:

| Directiva | Motivo |
|---|---|
| `script-src 'wasm-unsafe-eval'` | El motor de Flutter es WebAssembly. |
| `style-src 'unsafe-inline'` | Flutter inserta estilos en la página. |
| `img-src` y `connect-src` con S3 | Fotos de las órdenes (`nextspring.s3.us-east-1.amazonaws.com`). Flutter las descarga con `fetch`. |
| `img-src blob:` | Vista previa de las fotos tomadas. |
| `connect-src 'self'` | El API está en el mismo dominio (`/nextAPI/api`). Si cambia de dominio, agregarlo aquí. |
| `frame-ancestors 'none'` | Nadie puede incrustar la app en otra página. |

Los scripts de `index.html` están en `pwa.js` y no en línea, para que `script-src` no necesite `'unsafe-inline'`.

#### CORS

| Recurso | Estado |
|---|---|
| **API** | Ya responde `Access-Control-Allow-Origin: *`. Como la PWA y el API están en el mismo dominio (`springtelecom.mx`), la PWA **no necesita CORS**. Cambiar `*` por una lista de dominios es una mejora de seguridad del API, no un requisito de la PWA. |
| **S3** | El bucket ya responde `Access-Control-Allow-Origin: *` para `GET` y `HEAD`, así que las fotos se ven en la PWA. Si se restringe, debe incluir `https://springtelecom.mx`. |

#### Sesión en el navegador

- En el teléfono, los tokens van en el Keychain (iOS) o el Keystore (Android).
- En web, `flutter_secure_storage` los guarda cifrados en el almacenamiento del navegador. La llave también vive en el navegador, así que un script malicioso en la página podría leerlos. La CSP reduce ese riesgo.

Para revisar con backend:

- [ ] Duración del token de acceso. Se recomienda 15 minutos o menos.
- [ ] Rotación del refresh token: uno nuevo en cada renovación y el anterior invalidado.
- [ ] Que `logout` invalide el refresh token en el servidor.
- [ ] A futuro: refresh token en una cookie `HttpOnly; Secure; SameSite=Strict`, que JavaScript no puede leer. Requiere cambios en el API.

### A.6 Rendimiento

Medido con la compilación del 10-nov-2026. Los tamaños son los que viajan por la red, comprimidos con gzip.

| Navegador | Versión JS (actual) | Versión `--wasm` |
|---|---|---|
| Chrome / Android | 1.0 MB código + 2.1 MB motor = **3.1 MB** | 1.1 MB código + 1.5 MB motor = **2.6 MB** |
| Safari / iPhone | 1.0 MB código + 2.9 MB motor = **3.9 MB** | Igual: Safari usa la versión JS |

- Las visitas siguientes salen de la caché o reciben 304, así que solo la primera descarga es pesada.
- En 4G (~10 Mbps reales), la primera carga tarda unos 3 s en Chrome y 4 s en Safari, más el arranque.
- **`--wasm`:** también corre más rápido en Chrome. Compila sin errores, pero dibuja con otro motor (`skwasm`), así que antes de adoptarla hay que probar todo el flujo con `tool/build_web.sh --wasm`.

### A.7 Verificación después de publicar

Primera publicación: compilación `20261111133238-8760296-cambios`, revisada el 11-nov-2026.

- [x] `https://springtelecom.mx/ordenservicioapp/` abre el login.
- [x] DevTools → Application → Service Workers: `sw.js` activo.
- [x] DevTools → Network → Offline y recargar: la app abre.
- [x] Lighthouse (categoría PWA o "Installable"): sin errores.
- [x] Publicar una compilación nueva: con la app abierta aparece "Hay una versión nueva" y Recargar la carga. Probado en el navegador y en la PWA instalada en iPhone. Desde el 11-nov-2026 el aviso sale en la parte superior, debajo de la barra del título, para no tapar la barra inferior; confirmado en el servidor.
- [x] Instalar en iPhone (Safari → Compartir → Agregar a inicio): se instala correctamente.
- [x] Instalar en Android (Chrome → Instalar app): se instala con el nombre y los íconos correctos y funciona.
