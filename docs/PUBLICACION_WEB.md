# Publicación de la versión web (PWA)

Cómo compilar y publicar la app de instaladores en `https://springtelecom.mx/ordenservicioapp/`, y qué debe configurar el servidor.

Ver también [PLAN_PWA.md](PLAN_PWA.md).

## 1. Compilar

Siempre con el script, no con `flutter build web` directo:

```bash
tool/build_web.sh
```

Variantes:

| Caso | Comando |
|---|---|
| Otra ruta en el servidor | `BASE_HREF=/otra-ruta/ tool/build_web.sh` |
| Otro API | `tool/build_web.sh --dart-define=API_BASE_URL=https://...` |
| Versión WebAssembly (ver §6) | `tool/build_web.sh --wasm` |

El script hace tres cosas además de compilar:

1. Usa `--no-web-resources-cdn`: el motor de Flutter (CanvasKit) y las fuentes se sirven desde nuestro servidor y no desde `gstatic.com`. Así quedan en la caché offline y la CSP no necesita dominios de Google.
2. Pone un número de compilación (fecha + commit) en `sw.js` y `pwa.js`.
3. Escribe ese número en `build.json`. Con él la app detecta que se publicó una versión nueva.

> Si se compila con `flutter build web` sin el script, la app funciona pero **no** registra el service worker. Sin él no abre sin conexión ni avisa de versiones nuevas.

## 2. Publicar

1. Copiar **todo** el contenido de `build/web/` a la carpeta que nginx sirve en `/ordenservicioapp/`, reemplazando lo anterior.
2. No hace falta limpiar cachés a mano:
   - Quien tenga la app abierta verá **"Hay una versión nueva de la app"** con el botón **Recargar**. El aviso aparece al volver a la app o, como máximo, 30 minutos después.
   - Quien la abra después recibe la versión nueva directamente.

## 3. Cómo funciona la caché (offline nivel A)

- `web/sw.js` (service worker) siempre pide primero la versión de la red. Solo sin conexión usa la copia guardada. Los archivos de Flutter no llevan hash en el nombre (`main.dart.js`), así que servir primero la caché podría mezclar versiones.
- Sin conexión, la app abre y muestra la interfaz. Operar requiere red.
- **Nunca** se guardan respuestas del API ni fotos de S3.
- Cada compilación usa su propia caché (`instaladores-<número>`). La anterior se borra al activarse la nueva.
- `web/flutter_bootstrap.js` arranca Flutter **sin** su service worker, que está obsoleto: se da de baja solo y reemplazaría al nuestro.

## 4. Configuración de nginx

> **Estado (11-nov-2026): aplicada en el servidor.** Infraestructura la aplicó y se verificó desde internet:
> - `/`, `index.html`, `sw.js`, `build.json`, `main.dart.js` y `canvaskit.wasm` responden con `Cache-Control: no-cache`, el tipo correcto (`.wasm` como `application/wasm`) y gzip. `build.json` no se comprime porque pesa 43 bytes.
> - Cada encabezado de seguridad sale una sola vez: HSTS, `nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY`, `Permissions-Policy` (cámara y ubicación permitidas) y la CSP en modo `Report-Only`, igual a la de esta guía.
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

    # Seguridad (ver §5).
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

## 5. Seguridad

### Content Security Policy (CSP)

La política de §4 se probó en local con la app compilada:

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

### CORS

| Recurso | Estado |
|---|---|
| **API** | Ya responde `Access-Control-Allow-Origin: *`. Como la PWA y el API están en el mismo dominio (`springtelecom.mx`), la PWA **no necesita CORS**. Cambiar `*` por una lista de dominios es una mejora de seguridad del API, no un requisito de la PWA. |
| **S3** | El bucket ya responde `Access-Control-Allow-Origin: *` para `GET` y `HEAD`, así que las fotos se ven en la PWA. Si se restringe, debe incluir `https://springtelecom.mx`. |

### Sesión en el navegador

- En el teléfono, los tokens van en el Keychain (iOS) o el Keystore (Android).
- En web, `flutter_secure_storage` los guarda cifrados en el almacenamiento del navegador. La llave también vive en el navegador, así que un script malicioso en la página podría leerlos. La CSP reduce ese riesgo.

Para revisar con backend:

- [ ] Duración del token de acceso. Se recomienda 15 minutos o menos.
- [ ] Rotación del refresh token: uno nuevo en cada renovación y el anterior invalidado.
- [ ] Que `logout` invalide el refresh token en el servidor.
- [ ] A futuro: refresh token en una cookie `HttpOnly; Secure; SameSite=Strict`, que JavaScript no puede leer. Requiere cambios en el API.

## 6. Rendimiento

Medido con la compilación del 10-nov-2026. Los tamaños son los que viajan por la red, comprimidos con gzip.

| Navegador | Versión JS (actual) | Versión `--wasm` |
|---|---|---|
| Chrome / Android | 1.0 MB código + 2.1 MB motor = **3.1 MB** | 1.1 MB código + 1.5 MB motor = **2.6 MB** |
| Safari / iPhone | 1.0 MB código + 2.9 MB motor = **3.9 MB** | Igual: Safari usa la versión JS |

- Las visitas siguientes salen de la caché o reciben 304, así que solo la primera descarga es pesada.
- En 4G (~10 Mbps reales), la primera carga tarda unos 3 s en Chrome y 4 s en Safari, más el arranque.
- **`--wasm`:** también corre más rápido en Chrome. Compila sin errores, pero dibuja con otro motor (`skwasm`), así que antes de adoptarla hay que probar todo el flujo con `tool/build_web.sh --wasm`.

## 7. Verificación después de publicar

Primera publicación: compilación `20261111133238-8760296-cambios`, revisada el 11-nov-2026.

- [x] `https://springtelecom.mx/ordenservicioapp/` abre el login.
- [x] DevTools → Application → Service Workers: `sw.js` activo.
- [x] DevTools → Network → Offline y recargar: la app abre.
- [x] Lighthouse (categoría PWA o "Installable"): sin errores.
- [x] Publicar una compilación nueva: con la app abierta aparece "Hay una versión nueva" y Recargar la carga. Probado en el navegador y en la PWA instalada en iPhone. Desde el 11-nov-2026 el aviso sale en la parte superior, debajo de la barra del título, para no tapar la barra inferior; confirmado en el servidor.
- [x] Instalar en iPhone (Safari → Compartir → Agregar a inicio): se instala correctamente.
- [x] Instalar en Android (Chrome → Instalar app): se instala con el nombre y los íconos correctos y funciona.
