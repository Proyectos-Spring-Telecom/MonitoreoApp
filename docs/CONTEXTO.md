# Contexto de Instaladores Spring (MonitoreoApp)

Punto de partida para quien llega al proyecto: qué es la app, para quién, qué hace, qué reglas sigue y cómo está construida.

| Documento | Para qué sirve |
|---|---|
| **CONTEXTO.md** (este) | Visión general, funcionalidades, reglas de negocio, diseño, arquitectura y decisiones |
| [CONTRATO.md](CONTRATO.md) | Contrato con el API: endpoints, campos, estatus, catálogos y errores |
| [OPERACION_APLICACION.md](OPERACION_APLICACION.md) | Cómo opera la app paso a paso: arranque, sesión y el flujo completo de una orden |
| [PLAN_PWA.md](PLAN_PWA.md) | Plan de la versión web (PWA) y, en su anexo, cómo compilar y publicar |

---

## 1. Qué es

App de **Spring Telecom** para los **técnicos instaladores** (rol 8). El técnico atiende en campo las órdenes de servicio que **operación** le programa desde el portal web de NextAPI:

- **Alta:** instalar un equipo GPS (dispositivo y SIM) en un vehículo.
- **Revisión:** revisar una instalación vigente.
- **Cambio de SIM** y **cambio de equipo:** reemplazar la SIM o el dispositivo de una instalación.
- **Desinstalación:** retirar el equipo.

Durante la orden el técnico registra el vehículo, el equipo, un checklist con fotos, las pruebas (que valida un operador de monitoreo a distancia) y las firmas. Al cerrar, el servidor aplica el movimiento en la instalación y genera un PDF que se puede compartir por WhatsApp o correo.

**Quién participa:**

| Actor | Qué hace |
|---|---|
| Técnico instalador (rol 8) | Usa esta app. Inicia, captura y cierra las órdenes, o las marca como no cumplidas |
| Operación | Programa, reasigna y cancela órdenes en el portal web; autoriza desinstalar un equipo encontrado |
| Operador de monitoreo | Valida las pruebas que pide el técnico y le dicta el código de verificación |
| Cliente | Dueño del vehículo; firma la orden y recibe el PDF |

## 2. Plataformas

| Plataforma | Estado |
|---|---|
| **PWA** (navegador e instalada en Android e iPhone) | **Forma oficial de uso.** Publicada en `https://springtelecom.mx/ordenservicioapp/` |
| Android e iOS nativos | Se mantienen compilables (iOS mínimo 15.0, Android `minSdk` 21), pero no se distribuyen |

El mismo código de Flutter sirve a las tres. Las diferencias de web están aisladas en `lib/core/platform/` (PDF y conversión de imágenes) y en la carpeta `web/` (service worker, manifiesto, arranque).

## 3. Glosario

| Término | Significado |
|---|---|
| Orden de servicio (OS) | Visita programada. Folio `OS-000042` generado por el servidor |
| Agenda | Órdenes del técnico `programada` y `borrador` (en curso) |
| Instalación | Relación vehículo + dispositivo + SIM de un cliente. La crea o modifica el servidor al cerrar la orden |
| Producto | El vehículo (`idProducto`) |
| `claveApp` | UUID que identifica el inicio de una orden en este teléfono; hace seguro reintentar |
| Mantenimiento | Revisión, cambio de SIM, cambio de equipo o desinstalación |
| `faltantesParaCerrar` | Lista que calcula el servidor con lo que falta para cerrar |
| Orden heredada (*legacy*) | Orden sin origen ni tipo programado, creada con el flujo anterior. No pide código y el técnico contesta las pruebas |
| No cumplida | Orden que no se pudo realizar, con un motivo |

## 4. Funcionalidades

### Acceso

- **Iniciar sesión** con correo y contraseña. Solo entra el rol 8; cualquier otro rol ve «Esta aplicación es solo para técnicos instaladores».
- **¿Olvidaste tu contraseña?:** envía el correo de recuperación. El restablecimiento se hace en el portal web (no en la app).
- La sesión se conserva al cerrar y volver a abrir la app. Si expira, se regresa al login con «Tu sesión expiró».

### Navegación

Barra inferior con cuatro pestañas y menú lateral con las mismas más **Cambio de contraseña** y **Cerrar sesión**.

| Pestaña | Contenido |
|---|---|
| **Inicio** | Saludo con nombre y rol, «Ver mi agenda» y «Ver mi historial» |
| **Agenda** | «En curso» arriba y, debajo, el calendario en vista **Agenda** (lista por día) o **Mes** (cuadrícula con el detalle del día elegido y botón «Hoy») |
| **Servicios** | Historial de órdenes **cerradas** o **no cumplidas**, con búsqueda (folio, cliente, tipo, estatus, observaciones, instalación) y filtro por fecha |
| **Perfil** | Foto, nombre, correo, rol, teléfono, cliente y último acceso (solo lectura) |

### Orden de servicio

Se abre al tocar una orden de la agenda. Resumen; el detalle está en [OPERACION_APLICACION.md](OPERACION_APLICACION.md):

1. **Datos de la visita** e **iniciar**: muestra cliente, cita, vehículo, quién programó, observaciones, «Unidad x de y» y referencia CRM. En un mantenimiento se confirma el servicio y se puede **atender otro vehículo** por placa.
2. **Vehículo** (solo alta): buscar por placa o registrarlo con 6 fotos; si ya tiene equipo, pedir autorización a operación y esperar.
3. **Código de verificación** (solo mantenimientos): el operador lo dicta.
4. **Instalación:** equipo y SIM que entran, o destino del que sale.
5. **Checklist:** accesorios del vehículo, funcionamiento, fallas y fotos.
6. **Pruebas y firmas:** pedir cada prueba al operador, monitorista, observaciones y firmas.
7. **Resumen y cierre:** lista de faltantes del servidor; «Registrar orden» cuando ya no falta nada.

En cualquier momento: **No se pudo realizar** (no cumplida con motivo).

### Después de la orden

- **Detalle** de la orden con respuestas, pruebas, fotos, firmas y equipo.
- **Ver PDF** en cualquier estatus (en el teléfono se abre con el visor; en web se descarga como `<folio>.pdf`).
- **Compartir** (solo cerrada o no cumplida): por **WhatsApp**, con teléfono opcional, o por **correo**, de 1 a 5 destinatarios. En web aparece «Abrir WhatsApp» para que el navegador no bloquee la ventana.

### Versión web (PWA)

- Se instala desde Chrome (Android) o con «Agregar a inicio» (Safari, iPhone).
- Abre sin conexión (solo la interfaz; operar requiere red).
- Avisa con «Hay una versión nueva de la app» y **Recargar** cuando se publica otra compilación.
- Las direcciones llevan `#` y el id de la orden: recargar a mitad de una orden vuelve a la misma.

## 5. Reglas de negocio

Las reglas que valida el servidor se respetan también en la app para avisar antes. Si el servidor responde distinto, manda el servidor.

### Acceso y sesión

| # | Regla |
|---|---|
| RN-01 | Solo el rol 8 (técnico instalador) usa la app. Se revisa al iniciar sesión, al abrir con sesión guardada y en cada consulta del perfil. |
| RN-02 | La contraseña nueva debe tener de 7 a 15 caracteres, con mayúscula, minúscula, número y carácter especial. |
| RN-03 | El access token dura 6 horas. Ante un 401 se renueva una sola vez; si la renovación falla, se cierra la sesión. Un error de red o 5xx no cierra la sesión. |
| RN-04 | Al cerrar sesión se borran tokens, usuario, catálogos en memoria y las `claveApp` guardadas. |

### Agenda y estatus

| # | Regla |
|---|---|
| RN-05 | Ciclo de una orden: `programada` → `borrador` (en curso) → `cerrada` o `no_cumplida`. `cancelada` solo la aplica operación. |
| RN-06 | El técnico no crea ni cancela órdenes: solo atiende las de su agenda. |
| RN-07 | Una orden que deja de responder (404) ya no es del técnico: se avisa y se regresa a la agenda. |

### Inicio de la orden

| # | Regla |
|---|---|
| RN-08 | La `claveApp` se genera una sola vez por orden y se guarda en el teléfono; un reintento usa la misma. |
| RN-09 | El alta no se puede cambiar a mantenimiento ni al revés: eso lo programa operación. |
| RN-10 | Entre mantenimientos, en revisión y cambio de equipo se pregunta «¿El dispositivo funciona?»: sí → revisión, no → cambio de equipo. `tipoServicio` solo se envía si cambia. |
| RN-11 | «Atender otro vehículo» solo acepta una instalación vigente (estatus 1) del mismo cliente. |
| RN-12 | Al iniciar se registran fecha y ubicación. La ubicación espera como máximo 15 s (30 s con el permiso); si no llega, se usa la última conocida o la orden sigue sin coordenadas. |

### Vehículo (alta)

| # | Regla |
|---|---|
| RN-13 | Primero se busca por placa. Si existe y es del cliente, se usa sin modificarlo. |
| RN-14 | Un vehículo nuevo exige la placa (máx. 10 caracteres, letras, números y guion) y **6 fotos**: principal, frontal, trasera, lateral derecha, lateral izquierda y tarjeta de circulación. Cada archivo: PNG, JPG, WEBP o PDF, máximo 3 MB. |
| RN-15 | Si el vehículo ya tiene equipo, se exige foto `equipo_existente` y observaciones para pedir la autorización. Autorizada → sigue el alta; rechazada → la orden queda no cumplida. |
| RN-16 | Después de pedir la autorización el vehículo ya no se puede cambiar. |

### Código de verificación (mantenimientos)

| # | Regla |
|---|---|
| RN-17 | Todo mantenimiento de la agenda exige validar el código antes de continuar. El código no llega a la app: lo dicta el operador. |
| RN-18 | Hay un límite de códigos: al sexto se muestra «Comunícate con operación para que reinicie los códigos». Si se emitió otro código, se limpia el campo para capturar el nuevo. |

### Instalación

| # | Regla |
|---|---|
| RN-19 | Solo se pueden instalar equipos y SIMs del almacén o reservados al cliente, con estatus disponible (1). Los demás aparecen como «No disponible». |
| RN-20 | Qué se captura según el tipo: alta → dispositivo y SIM (opcional); cambio de equipo → dispositivo nuevo y destino del saliente; cambio de SIM → SIM nueva y destino de la saliente; desinstalación → estatus de baja; revisión → nada. |
| RN-21 | Destino de lo que sale en un cambio: 3 por revisar, 4 laboratorio o 5 inservible. Baja en desinstalación: 0 inactiva (equipo y SIM a revisión) o 5 inservible. |

### Checklist, pruebas y firmas

| # | Regla |
|---|---|
| RN-22 | Se envían **todas** las opciones sí/no de accesorios, funcionamiento y fallas. En el alta las fallas no se muestran y van en «no». |
| RN-23 | Fotos del tablero al inicio y al final obligatorias; fallas extra 1 a 3 opcionales (no en el alta). Cada foto se sube en cuanto se toma; se acepta PNG o JPG hasta 10 MB y otros formatos se convierten a JPG. |
| RN-24 | La prueba `paro_motor` solo se exige si el vehículo cuenta con inmovilizador. |
| RN-25 | En órdenes de la agenda las pruebas las valida el operador; en desinstalación y en órdenes heredadas las contesta el técnico. Una prueba fallida se puede volver a solicitar. |
| RN-26 | El monitorista es obligatorio. Las observaciones son obligatorias si la falla «otro» es sí. |

### Cierre y después

| # | Regla |
|---|---|
| RN-27 | Solo se puede cerrar con `faltantesParaCerrar` vacío. Cerrar es seguro de reintentar. |
| RN-28 | «No se pudo realizar» solo ofrece motivos de resultado `no_cumplida` y quién `tecnico`; algunos exigen observaciones. Si la orden no estaba iniciada, se inicia primero. |
| RN-29 | El PDF se puede ver en cualquier estatus; compartir y enviar por correo solo con la orden cerrada o no cumplida. El enlace de WhatsApp dura 168 h. |
| RN-30 | Las URL de fotos y firmas duran 5 minutos; al deslizar hacia abajo en el detalle se renuevan. |

## 6. Diseño

### Estilo

- Tema **oscuro** con Material 3. Fondo `#09081C`, tarjetas `#1A1930`, campos `#0F0E22`.
- Interfaz y mensajes en **español de México**, tuteando al técnico. Fechas y horas en hora de la Ciudad de México.
- Logotipo de Spring en la barra superior y fondo ilustrado en Inicio y Login.

### Paleta

| Uso | Color | Constante |
|---|---|---|
| Fondo | `#09081C` | `AppColors.backgroundDark` |
| Azul de marca y botón principal | `#001C6A` | `AppColors.primaryBlue` |
| Error | `#F44336` | `AppColors.error` |
| Tarjeta / campo / mosaico | `#1A1930` / `#0F0E22` / `#2A2940` | `ServiceOrderColors.card`, `field`, `tile` |
| Acento | `#6FA8E8` | `ServiceOrderColors.accent` |
| Éxito | `#34C38F` | `ServiceOrderColors.success` |
| Advertencia | `#F5A524` | `ServiceOrderColors.warning` |
| Violeta | `#A78BFA` | `ServiceOrderColors.violet` |
| Texto secundario / pista | blanco 70 % / 50 % | `mutedText`, `hintText` |

**Color por tipo de servicio** (agenda, calendario, «En curso» e historial; `orderTypeColor` en `order_models.dart`):

| Tipo | Color |
|---|---|
| Alta | Acento `#6FA8E8` |
| Revisión | Amarillo `#F5A524` |
| Cambio de SIM / equipo | Violeta `#A78BFA` |
| Desinstalación | Rojo `#F26D6D` |

**Color por estatus** (etiquetas, `ServiceOrderStatusStyle`): programada y **en curso** en azul `#6FA8E8`, cerrada en verde `#34C38F`, no cumplida en rojo `#F26D6D` y cancelada en gris.

### Tipografía y transiciones

- En web se usa **Roboto** (incluida en la compilación). En iPhone la fuente del sistema partía los números.
- Transiciones: deslizamiento en iOS y macOS; en Android la de Flutter con fondo oscuro, para evitar el destello blanco.

### Componentes y patrones

| Patrón | Dónde |
|---|---|
| Indicador de pasos que no deja saltar un paso que bloquea | Orden de servicio (`ServiceOrderStepper`) |
| Etiquetas tipo píldora (`ServiceOrderTag`) | Tipo, estatus, unidad |
| Casillas de foto con estado ⏳ enviando, ✓ enviada, ↻ reintentar | Checklist, equipo encontrado |
| Botón principal con indicador de carga y texto «…ando» («Registrando vehículo…») | Acciones que llaman al API |
| Tres estados en cada pantalla con datos: cargando, error con **Reintentar** y vacío | Agenda, historial, detalle, perfil |
| Deslizar hacia abajo para recargar | Agenda, historial, detalle, perfil |
| Avisos en la parte superior (`AppMessage`) | Éxito, error e información |
| Avatar con iniciales mientras carga o si no hay foto (`UserAvatar`) | Menú y perfil |

### Íconos y PWA

- Ícono de la app: `assets/images/icons/icono_de_instalador.png` (Android e iOS con `flutter_launcher_icons`).
- PWA: nombre «Instaladores Spring» (corto «Instaladores»), color `#09081C`, íconos en `web/icons/` (192, 512, versiones *maskable* con fondo `#0B3FCF` y `apple-touch-icon`).

## 7. Arquitectura

Arquitectura limpia en tres capas más `core`. Las pantallas nunca llaman al HTTP directamente.

```
presentation  → pantallas, AuthController, ServiceOrderFlowController
    ↓
domain        → entidades, contratos de repositorio, casos de uso
    ↑
data          → modelos JSON, datasources remotos y locales, repositorios
    ↓
core          → ApiClient, rutas, tema, ubicación, utilidades, plataforma
```

- **Estado:** `provider` con `ChangeNotifier`. `AuthController` maneja la sesión; `ServiceOrderFlowController` es el único que habla con el API durante una orden.
- **Errores:** llegan a la interfaz como `Failure` (`ServerFailure`, `NetworkFailure`, `AuthFailure`, `CacheFailure`, `ValidationFailure`, `IncompleteOrderFailure`) con un mensaje en español listo para mostrarse.
- **Lectura de JSON:** `JsonReader` acepta datos en la raíz o dentro de `data` y no distingue mayúsculas en las claves.
- **Rutas:** `AppRoutes` revisa la sesión al abrir cada pantalla. Sin sesión todo va a `/login`.
- **Fechas:** `MexicoCityTime` lee las fechas del API (hora de la Ciudad de México aunque traigan `Z`).

### Estructura

```
lib/
├── core/
│   ├── constants/      URL del API, rutas, colores
│   ├── errors/         Failure y sus tipos
│   ├── network/        ApiClient (tokens, renovación, multipart) y endpoints
│   ├── platform/       PDF y conversión a JPG: versión móvil y web
│   ├── routes/         AppRoutes con revisión de sesión
│   ├── services/       Ubicación con tiempos máximos
│   ├── theme/          Tema oscuro, fuente y transiciones
│   ├── utils/          JsonReader, hora de México, validaciones, imágenes
│   └── widgets/        AppMessage
├── data/
│   ├── datasources/    remote (auth, catálogos, vehículos, instalación) y local (sesión, claveApp)
│   ├── models/         Lectura y escritura de JSON
│   └── repositories/   Implementaciones
├── domain/
│   ├── entities/       Usuario, orden, estatus, catálogos, recursos de instalación
│   ├── repositories/   Contratos
│   └── usecases/       Login, logout, perfil, contraseñas
├── presentation/
│   ├── auth/           Login, recuperar y cambiar contraseña, perfil
│   ├── home/           Inicio, barra inferior y menú lateral
│   ├── agenda/         Agenda y calendario
│   ├── service_order/  Flujo de la orden: controlador, pasos y widgets
│   ├── orders/         Historial, detalle, PDF y compartir
│   └── widgets/        Comunes (avatar)
└── main.dart           Arma dependencias y arranca
web/                    index.html, manifest.json, sw.js, pwa.js, flutter_bootstrap.js, íconos
tool/build_web.sh       Compilación web para publicar
test/                   Pruebas de core, data y presentation
```

### Tecnología

| Qué | Con qué |
|---|---|
| Framework | Flutter 3.47 (Dart 3) |
| Estado | `provider` |
| HTTP | `http` + `ApiClient` propio |
| Sesión | `flutter_secure_storage` (tokens) y `shared_preferences` (usuario, `claveApp`) |
| Fotos | `image_picker`; conversión con `image` (móvil) o canvas del navegador (web) |
| Firmas | `signature` |
| Ubicación | `geolocator` |
| PDF | `path_provider` + `open_filex` (móvil); descarga con `web` (navegador) |
| Compartir | `url_launcher` |
| Fechas | `MexicoCityTime` propio (hora de la Ciudad de México) |
| Pruebas | `flutter_test`, `fake_async`, fakes del GPS y del selector de imágenes |

## 8. Cómo trabajar en el proyecto

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # teléfono o simulador
flutter analyze
flutter test
tool/build_web.sh            # compilación para publicar
```

- Otro API: `--dart-define=API_BASE_URL=https://...`. Por defecto, `https://springtelecom.mx/nextAPI/api`.
- Ramas: se trabaja en `dev_and` y se hace Pull Request a `Dev` con **merge commit** (no *squash*), para que las ramas no se desalineen.
- Commits con prefijo: `[Add]`, `[Update]` o `[Fix]`.
- Antes de subir: `flutter analyze` sin errores y todos los tests en verde. Cada corrección lleva un test que falla sin ella.
- Las pruebas usan fakes de repositorios en `test/helpers/`; no llaman al servidor real.

### Compilar en local y publicar en el servidor

La versión web se compila **en la computadora** con el script `tool/build_web.sh` y lo que genera se sube al servidor. No se ejecuta en el servidor.

**Requisitos en la computadora:**

- Flutter 3.47 en el `PATH`. Se comprueba con `flutter --version`.
- `git`, porque el número de compilación incluye el commit.
- Una terminal `bash`: macOS, Linux o, en Windows, Git Bash o WSL.

**Pasos:**

1. Abrir una terminal en la carpeta raíz del proyecto (donde está `pubspec.yaml`):

   ```bash
   cd ruta/al/proyecto/monitoreo
   ```

2. Estar en la rama que se va a publicar, actualizada y sin cambios pendientes. Si hay cambios sin commit, la compilación lleva `-cambios` en su número; sirve para probar, pero no para producción.

   ```bash
   git status
   ```

3. Bajar las dependencias:

   ```bash
   flutter pub get
   ```

4. Ejecutar el script:

   ```bash
   tool/build_web.sh
   ```

   Si la terminal dice `permission denied`, ejecutarlo con `bash tool/build_web.sh`.

5. Al terminar muestra `Compilación <número> lista en build/web/ (ruta /ordenservicioapp/).`. Ese número (fecha + commit, p. ej. `20261112125936-d9f0f36`) identifica la versión.

**Variantes del script:**

| Caso | Comando |
|---|---|
| Publicar en otra ruta | `BASE_HREF=/otra-ruta/ tool/build_web.sh` |
| Usar otro API | `tool/build_web.sh --dart-define=API_BASE_URL=https://...` |
| Versión WebAssembly (sin probar todavía) | `tool/build_web.sh --wasm` |

No usar `flutter build web` directo: la app funcionaría, pero sin service worker, sin modo sin conexión y sin aviso de versión nueva.

**Probar la compilación en local (opcional):** la app espera estar en `/ordenservicioapp/`, así que se sirve desde una carpeta con ese nombre. Usa el API real, así que se puede iniciar sesión.

```bash
mkdir -p /tmp/sitio && ln -sfn "$PWD/build/web" /tmp/sitio/ordenservicioapp && python3 -m http.server 8090 --directory /tmp/sitio
```

Después abrir `http://localhost:8090/ordenservicioapp/`. Se detiene con `Ctrl + C`.

**Publicar en el servidor:**

1. Copiar **todo** el contenido de `build/web/` (no la carpeta, su contenido) a la carpeta que nginx sirve en `/ordenservicioapp/`, reemplazando lo anterior. La ruta y el acceso al servidor los da infraestructura. Por ejemplo, con `rsync`:

   ```bash
   rsync -av --delete build/web/ <usuario>@<servidor>:<carpeta-de-ordenservicioapp>/
   ```

2. Comprobar que el servidor ya tiene la versión nueva; debe responder el número del paso 5:

   ```bash
   curl -s https://springtelecom.mx/ordenservicioapp/build.json
   ```

3. No hace falta limpiar cachés. Quien tenga la app abierta verá «Hay una versión nueva de la app» con **Recargar** (al volver a la app o, como máximo, en 30 minutos); quien la abra después recibe la nueva directamente.

La configuración de nginx, la seguridad y la lista de verificación están en el [Anexo A de PLAN_PWA.md](PLAN_PWA.md#anexo-a-publicación-de-la-versión-web).

## 9. Decisiones importantes

| Fecha | Decisión |
|---|---|
| 27 oct 2026 | Tokens cifrados en el teléfono (Keychain/Keystore; en web, almacenamiento cifrado del navegador). La contraseña no se guarda. |
| 27 oct 2026 | Las 6 fotos del vehículo son obligatorias en la app aunque el API las acepte como opcionales. Confirmado por negocio el 11 nov. |
| 28 oct 2026 | El restablecimiento de contraseña desde el correo se hace en el portal web; la app no necesita *deep link*. |
| 28 oct 2026 | El perfil es de solo lectura; la edición vive en el portal. |
| 3 nov 2026 | La app pasa a trabajar solo con la agenda de NextAPI (contrato «App de instaladores»): ya no crea ni cancela órdenes. Acceso solo para el rol 8. |
| 3 nov 2026 | La orden vive en el servidor: cada paso se guarda con `PATCH` y se retoma desde «En curso». |
| 10 nov 2026 | La app se usa siempre como PWA, en `https://springtelecom.mx/ordenservicioapp/`, con URLs con `#`. |
| 10 nov 2026 | Sin conexión, nivel A: la app abre pero operar requiere red; no hay cola offline. |
| 10 nov 2026 | Las fotos del checklist y del equipo encontrado se suben en cuanto se toman. |
| 11 nov 2026 | iOS mínimo 15.0 (lo exige Flutter 3.47). |
| 11 nov 2026 | Servidor con `Cache-Control: no-cache`, gzip, encabezados de seguridad y CSP en `Report-Only`. |
| 11 nov 2026 | Mi agenda con calendario (Agenda y Mes) y «En curso» debajo del selector. |
| 12 nov 2026 | En web, la foto de perfil se muestra con `<img>` si el navegador tiene una copia sin CORS. |

## 10. Pendientes conocidos

| Pendiente | Con quién |
|---|---|
| Sesión en web: duración del refresh token, rotación y que el logout lo invalide | Backend |
| Pasar la CSP de `Report-Only` a obligatoria tras una semana sin avisos | Infraestructura |
| Acordar y medir el tiempo de primera carga en 4G | Equipo |
| Filtro por `idCliente` en `/instalaciones/paginado` para «Atender otro vehículo» (hoy se revisan las primeras 50 filas) | Backend |
| Un campo para saber que la orden necesita autorización (hoy se detecta por el texto de `faltantesParaCerrar`) | Backend |
| Probar la versión `--wasm`, más ligera en Chrome | Equipo |
