# Contrato de Instaladores Spring con NextAPI

Qué servicios usa la app, qué envía y qué lee de cada respuesta. La fuente oficial es el contrato de NextAPI para la App de instaladores (`docs/app-instaladores.md` en el repositorio de NextAPI, rama `dev-isra`); los números **§** de los documentos de la app se refieren a sus secciones. Si el contrato y el código del API no coinciden, manda el código del API.

Ver también: [CONTEXTO.md](CONTEXTO.md) (reglas de negocio) y [OPERACION_APLICACION.md](OPERACION_APLICACION.md) (cuándo se llama cada servicio).

---

## 1. Generalidades

| Tema | Valor |
|---|---|
| URL base | `https://springtelecom.mx/nextAPI/api`. Otro entorno: `--dart-define=API_BASE_URL=https://...` |
| Origen | La PWA y el API están en el mismo dominio, así que la PWA no necesita CORS del API |
| Formato | JSON (`Content-Type: application/json`), salvo archivos (`multipart/form-data`) y el PDF (`application/pdf`) |
| Autenticación | `Authorization: Bearer <accessToken>` en todo, excepto login, refresh, logout y recuperar contraseña |
| Tiempo de espera | 30 s en JSON; 120 s al subir archivos |
| Límite de solicitudes | 100 por minuto (responde 429) |
| Archivos de S3 | `https://nextspring.s3.us-east-1.amazonaws.com`. URL firmadas que duran 5 minutos; no se guardan |

### Cómo lee la app las respuestas

- Acepta los datos en la raíz o dentro de `data` (y en algunos casos `user`, `usuario`, `vehiculo`).
- No distingue mayúsculas en las claves (`idCliente` = `IdCliente`).
- Las listas pueden venir como arreglo directo o dentro de `data`.
- Ignora los elementos de un catálogo sin `id` o sin nombre.
- Los IDs se envían como número cuando lo son (`"42"` → `42`).

### Fechas

- **El API envía** la hora de la Ciudad de México, aunque traiga el sufijo `Z`. La app la lee como hora de México (`MexicoCityTime.parseApi`).
- **La app envía** `fechaCaptura` con la hora del teléfono y su desfase: `2026-10-30T10:42:00-06:00`.

### Errores

El mensaje se toma de `message`, `mensaje`, `error`, `title` o `detail`, o del texto plano si es corto. Los textos genéricos de Express (`Unauthorized`, `Not Found`, `Internal server error`…) se reemplazan por un mensaje en español.

| HTTP | Significado | Qué hace la app |
|---|---|---|
| 400 | Datos inválidos o faltantes | Muestra el mensaje. En `cerrar` lee `faltantes` |
| 401 | Token vencido | `POST /login/refresh` una sola vez y reintenta; si falla, cierra la sesión («Tu sesión expiró») |
| 403 | Sin permiso | Muestra el mensaje; no reintenta |
| 404 | No existe o ya no es del técnico | En una orden: avisa y regresa a la agenda |
| 409 | Otra acción se adelantó | Recarga la orden y muestra el mensaje |
| 429 | Demasiadas solicitudes | Pide esperar un momento |
| 5xx / red | Falla del servidor o sin conexión | Muestra el mensaje; no cierra la sesión. Iniciar, guardar, subir archivos y cerrar son seguros de repetir |

---

## 2. Autenticación y perfil (§1)

| Método | Ruta | Envía | Lee |
|---|---|---|---|
| POST | `/login` | `{ userName, password }` sin Bearer | `token` (o `accessToken`), `refreshToken` |
| GET | `/login/me` | Bearer | Usuario (ver abajo) |
| POST | `/login/refresh` | `{ refreshToken }` sin Bearer | Tokens nuevos |
| POST | `/login/logout` | `{ refreshToken }` sin Bearer | — (la sesión local se borra aunque falle) |
| POST | `/login/usuario/recuperar/acceso` | `{ userName }` sin Bearer | Texto con el resultado |
| PATCH | `/usuarios/actualizar/contrasena` | `{ passwordActual, passwordNueva, passwordNuevaConfirmacion }` | — (un 401 aquí es contraseña actual incorrecta y **no** cierra la sesión) |

**Usuario de `/login/me`:**

| Campo | Uso |
|---|---|
| `id` | Identificador |
| `nombre`, `apellidoPaterno`, `apellidoMaterno` | Nombre completo |
| `userName` / `correo` | Correo |
| `telefono` | Perfil |
| `fotoPerfil` | Avatar |
| `rol.id` | **Debe ser `8`**; si no, la app cierra la sesión |
| `rol.descripcion` | Rol mostrado (`nombre` es un código, p. ej. «SA») |
| `idCliente`, `nombreCliente` | Cliente del técnico |
| `estatus` / `activo` | «Activo» o «Inactivo» (si no llega: «Activo») |
| `ultimoLogin` | Último acceso («Sin registro» si falta) |
| `permisos[].idPermiso` | Se guardan |

Errores del login: 401 «Correo o contraseña incorrectos.», 429 límite de intentos.

Duración: access token 6 horas (confirmado por backend). Duración y rotación del refresh token: **pendiente de confirmar**.

---

## 3. Catálogos (§2)

Se cargan al entrar a Inicio y se guardan en memoria hasta cerrar sesión.

### `GET /ordenes-servicio/catalogo`

```json
{
  "secciones": {
    "vehiculo_cuenta_con": [{ "clave": "inmovilizador", "nombre": "Inmovilizador" }],
    "funcionamiento_vehiculo": [...],
    "fallas_equipo": [...],
    "pruebas": [{ "clave": "paro_motor", "nombre": "Paro de motor" }],
    "fotos": [{ "clave": "tablero_inicio", "nombre": "Tablero al iniciar", "obligatorio": true }],
    "firmas": [{ "clave": "firma_cliente", "nombre": "Firma del cliente", "obligatorio": true }]
  },
  "monitoristas": [{ "id": 7, "nombre": "Ana López" }]
}
```

| Sección | Claves con regla en la app |
|---|---|
| `vehiculo_cuenta_con` | `inmovilizador`: si es sí, se exige la prueba `paro_motor` |
| `fallas_equipo` | `otro`: si es sí, las observaciones son obligatorias |
| `fotos` | `tablero_inicio`, `tablero_final`, `falla_extra_1..3`, `equipo_existente` |
| `firmas` | `firma_cliente`, `firma_tecnico` |

Si una clave no viene en el catálogo, la app la muestra legible (`cables_cortados` → «Cables cortados»).

### `GET /ordenes-servicio/motivos`

`[{ clave, nombre, resultado: [...], quien: [...], requiereObservaciones }]`. La app solo muestra los que tienen `no_cumplida` en `resultado` y `tecnico` en `quien`.

### Catálogos del vehículo

| Ruta | Uso |
|---|---|
| `GET /clientes/list` | Nombres de clientes |
| `GET /cat-marcas/list` | Marcas |
| `GET /cat-modelos/list` | Modelos; cada uno trae su marca (`marca` o `idMarca`) para filtrar |
| `GET /cat-tipo-combustible/list` | Combustibles |

Cada elemento: `id` y `nombre` (o `name`, `descripcion`). Se ordenan por nombre.

---

## 4. Agenda e historial (§3)

### `GET /ordenes-servicio/paginado/:page/:limit?estatus=<estatus>`

| Pantalla | Consulta |
|---|---|
| Agenda | `estatus=programada` y `estatus=borrador`, 50 por página, hasta 10 páginas |
| Historial | `estatus=cerrada` o `estatus=no_cumplida`, 20 por página, más al llegar al final |

Lee `data` (lista de órdenes) y `paginated` (`total`, `page`, `limit`).

### `GET /ordenes-servicio/:id`

Detalle de una orden. Es la misma estructura que la del paginado, completa:

| Campo | Uso |
|---|---|
| `id`, `folio` (o `nombre`) | Identificador y folio `OS-000042` |
| `tipoServicio`, `tipoProgramado` | Tipo actual y el que programó operación |
| `estatus` | `programada`, `borrador`, `cerrada`, `no_cumplida`, `cancelada` |
| `origen` | Sin `origen` ni `tipoProgramado` = orden heredada |
| `cita`, `citaFin`, `nombreProgramo` | Agenda |
| `idCliente`, `nombreCliente` | Cliente |
| `placa`, `numeroEconomico`, `nombreProducto`, `idProducto` | Vehículo |
| `idInstalacionProgramada`, `idInstalacion`, `idInstalacionResultado` | Instalaciones |
| `instalacion`, `instalacionResultado` | `{ tipoEquipo, dispositivo, sim }` en texto listo para mostrar |
| `dispositivoNuevo`, `simNuevo` | Lo que entra, en texto o como objeto |
| `idDispositivoNuevo`, `idSimNuevo`, `estatusSalienteAnterior`, `estatusInstalacionBaja` | Lo capturado en Instalación |
| `referenciaCrm`, `unidad`, `unidadesTotal` | «Unidad x de y» |
| `codigoValidado` | Código del mantenimiento ya validado |
| `autorizacion` | `pendiente`, `autorizada`, `rechazada` |
| `idTecnico`, `idMonitorista`, `observaciones`, `claveMotivo` | Captura |
| `fechaCaptura`, `lat`, `lng` | Inicio en campo |
| `fechaCreacion`, `fechaInicio`, `fechaCierre` | Fechas |
| `respuestas[]` | `{ seccion, clave, valor }` |
| `pruebas[]` | `{ clave, estatus, fechaSolicitud, notaTecnico, fechaValidacion, nombreValido, notaOperador }` |
| `archivos[]` | `{ clave, url, fechaCreacion }` (fotos y firmas de la orden) |
| `fotosVehiculo[]` | `{ clave, nombre, url }` (fotos del vehículo) |
| `faltantesParaCerrar[]` | Textos con lo que falta para cerrar |

---

## 5. Orden de servicio

Todas las rutas empiezan con `/ordenes-servicio/:id`.

### Iniciar (§4)

`POST /:id/iniciar`

```json
{ "claveApp": "uuid-v4", "tipoServicio": "c_equipo", "idInstalacion": 15 }
```

- `claveApp`: obligatoria; UUID v4 generado una vez por orden y guardado en el teléfono. Reintentar con la misma es seguro.
- `tipoServicio`: solo si cambia respecto al programado, y solo entre mantenimientos.
- `idInstalacion`: solo en «Atender otro vehículo». El API valida que sea vigente y del cliente.

Responde `{ id, nombre }` (folio).

### Guardar (§5)

`PATCH /:id` con solo los campos que cambian. Un campo en `null` se borra.

| Campo | Cuándo |
|---|---|
| `fechaCaptura`, `lat`, `lng` | Al iniciar (`lat`/`lng` en `null` si no hay ubicación) |
| `idProducto` | Vehículo del alta |
| `idDispositivoNuevo` | Alta y cambio de equipo |
| `idSimNuevo` | Alta (opcional) y cambio de SIM |
| `estatusSalienteAnterior` | Cambio de equipo o de SIM: 3, 4 o 5 |
| `estatusInstalacionBaja` | Desinstalación: 0 o 5 |
| `respuestas` | `[{ seccion, clave, valor }]` de checklist y, si las contesta el técnico, pruebas |
| `idMonitorista` | Pruebas y firmas |
| `observaciones` | Pruebas y firmas |

### Archivos (§5)

`POST /:id/archivos/:clave`, multipart con la parte `file`.

- PNG o JPG, máximo 10 MB. La app convierte otros formatos a JPG.
- Volver a subir la misma clave reemplaza el archivo.
- Claves: las de `fotos` y `firmas` del catálogo, más `equipo_existente`.

### Vehículo del alta (§6, §7)

| Método | Ruta | Detalle |
|---|---|---|
| GET | `/productos/vehiculos/placa/:placa` | Placa en mayúsculas. 404 = no existe; 400 = hay más de uno con esa placa. Lee `idProducto` (o `id`) e `idCliente` |
| POST | `/productos/vehiculos` | Multipart. Responde el `idProducto` (o `id`, `insertId`) |

Partes de texto (las vacías no se envían):

| Parte | Valor |
|---|---|
| `idCliente` | Cliente de la orden |
| `placa` | Mayúsculas, máx. 10 |
| `numeroEconomico`, `color`, `anio` | Texto |
| `idMarcaVehiculo`, `idModeloVehiculo`, `idCombustible` | IDs de catálogo |
| `numeroSerie` | VIN en mayúsculas |
| `km`, `capacidadLitros` | Decimal con punto |

Partes de archivo (PNG, JPG, WEBP o PDF, máximo 3 MB cada una):

| Foto | Parte | Obligatoria en la app |
|---|---|---|
| Imagen principal | `foto` | Sí |
| Frontal | `fotoFrente` | Sí |
| Trasera | `fotoTrasera` | Sí |
| Lateral derecha | `fotoDerecha` | Sí |
| Lateral izquierda | `fotoIzquierda` | Sí |
| Tarjeta de circulación | `tarjetaCirculacion` | Sí |
| Extra, póliza de seguro, permiso de carga | `fotoExtra`, `polizaSeguro`, `permisoCarga` | No |

Después: `PATCH /:id { idProducto }`.

**Equipo existente:** si `faltantesParaCerrar` contiene «ya tiene un equipo instalado», el vehículo ya tiene equipo. La app sube `equipo_existente` y llama:

`POST /:id/autorizacion { observaciones }`

Luego consulta `GET /:id` cada 12 s hasta que `autorizacion` sea `autorizada` o `rechazada` (rechazada deja la orden en `no_cumplida`).

**Reporte manual:** si el vehículo se registró en la app (Next no conocía el equipo), `faltantesParaCerrar` no trae el aviso. El técnico lo reporta (equipo de otro proveedor) y la app usa la misma secuencia, agregando un campo:

`POST /:id/autorizacion { observaciones, equipoTercero: true }`

- **Pendiente en backend:** aceptar esta solicitud aunque Next no tenga equipo registrado y seguir el ciclo `pendiente → autorizada / rechazada`. Al cerrar no hay instalación anterior que dar de baja.
- Hoy responde 400; la app muestra «Next no tiene registrado este equipo y todavía no se puede pedir autorización para equipos de otro proveedor desde la App. Comunícate con operación.» Cuando el backend lo acepte, la app funciona sin cambios.
- La solicitud normal (equipo detectado por el servidor) no envía `equipoTercero`.

### Código de verificación (§8)

| Método | Ruta | Envía | Respuesta |
|---|---|---|---|
| POST | `/:id/codigo` | — | `{ message, expira }`. El código **no** llega a la app. 409 = se agotaron los códigos |
| POST | `/:id/codigo/validar` | `{ codigo }` | 400 = incorrecto (el mensaje trae los intentos que quedan); 409 = se emitió otro código |

### Equipo y SIM (§5)

| Ruta | Detalle |
|---|---|
| `GET /dispositivos/list?idCliente=` | Del almacén y reservados al cliente |
| `GET /sims/list?idCliente=` | Igual |
| `GET /instalaciones/:id` | Equipo y SIM actuales de la instalación (mantenimientos) |
| `POST /instalaciones/paginado` | `{ page: 1, limit: 50, idProducto, estatusInstalacion: 1 }` para «Atender otro vehículo» |

Cada dispositivo o SIM: `id` (o `idDispositivo`/`idSim`), `idCliente` o `cliente.id` (vacío = almacén), `estatus` (1 = disponible), marca, modelo, IMEI, serie, compañía, ICCID y teléfono para armar el texto. Solo se puede instalar lo disponible del almacén o del cliente de la orden.

### Pruebas (§9)

`POST /:id/pruebas/:clave/solicitar`, con `{ observaciones }` si el técnico escribe una nota; sin cuerpo si no.

Mientras alguna prueba esté `solicitada`, la app consulta `GET /:id` cada 12 s. Una prueba `fallida` se puede volver a solicitar con la misma petición.

### Cerrar (§10)

`POST /:id/cerrar`, sin cuerpo.

- Éxito: `{ id, nombre, idInstalacionResultado }`.
- 400 con `faltantes` (o `faltantesParaCerrar`): la app muestra la lista.
- Seguro de reintentar.

### No cumplida (§11)

`POST /:id/no-cumplida { claveMotivo, observaciones? }`. Si la orden aún no estaba iniciada, la app la inicia antes.

---

## 6. PDF y compartir (§12)

| Método | Ruta | Envía | Lee |
|---|---|---|---|
| GET | `/:id/pdf` | `Accept: application/pdf` | Bytes del PDF (cualquier estatus) |
| POST | `/:id/compartir` | `{ telefono }` solo dígitos, opcional; sin cuerpo si no hay | `{ url, whatsapp, vigenciaHoras }` (168 h) |
| POST | `/:id/enviar-correo` | `{ correos: [...] }`, de 1 a 5 | `{ message }` |

Compartir y correo solo con la orden `cerrada` o `no_cumplida`.

---

## 7. Valores fijos

### Tipos de servicio

| Clave | Nombre | Mantenimiento | Pruebas las contesta |
|---|---|---|---|
| `instalacion` | Alta | No | Operador |
| `revision` | Revisión | Sí | Operador |
| `c_sim` | Cambio de SIM | Sí | Operador |
| `c_equipo` | Cambio de equipo | Sí | Operador |
| `desinstalacion` | Desinstalación | Sí | Técnico |

### Estatus de la orden

| Clave | En la app | Quién la pone |
|---|---|---|
| `programada` | Programada | Operación |
| `borrador` | En curso | Al iniciar |
| `cerrada` | Cerrada | Al cerrar |
| `no_cumplida` | No cumplida | Técnico (motivo) o autorización rechazada |
| `cancelada` | Cancelada | Solo operación |

### Otros

| Catálogo | Valores |
|---|---|
| Estatus de prueba | `solicitada` (Esperando al operador), `correcta`, `fallida`, `anulada` |
| Autorización | `pendiente`, `autorizada`, `rechazada` |
| `estatusSalienteAnterior` | 3 Por revisar, 4 Laboratorio, 5 Inservible (0 y 1 ya no se aceptan desde el 30 oct 2026) |
| `estatusInstalacionBaja` | 0 Inactiva (equipo y SIM a revisión), 5 Inservible (equipo inservible, SIM a revisión) |
| `estatusInstalacion` | 0 Inactivo, 1 Activa, 2 Asignado, 3 Baja por reemplazo, 4 Baja por mantenimiento, 5 Inservible |
| Disponibilidad de dispositivo o SIM | 1 = disponible |

---

## 8. Qué guarda la app en el dispositivo

| Dato | Dónde | Cuándo se borra |
|---|---|---|
| `auth_token`, `refresh_token` | `flutter_secure_storage` (Keychain, Keystore o almacenamiento cifrado del navegador) | Al cerrar sesión o si expira |
| `user_data`, `is_logged_in` | `shared_preferences` | Igual |
| `service_order_app_keys` (`claveApp` por orden) | `shared_preferences` | Al cerrar la orden, marcarla no cumplida o cerrar sesión |
| Catálogos y motivos | Memoria | Al cerrar sesión |

Nunca se guardan respuestas del API, fotos ni la contraseña. El service worker de la PWA no guarda nada del API ni de S3.

---

## 9. Pendientes con backend

| Tema | Estado |
|---|---|
| Duración y rotación del refresh token; que el logout lo invalide | Por confirmar |
| Filtro por `idCliente` en `/instalaciones/paginado` | Solicitado. Mientras tanto la app revisa las primeras 50 filas del vehículo |
| `POST /:id/autorizacion { observaciones, equipoTercero: true }` aceptado para equipos de otro proveedor (hoy responde 400) | Pendiente en backend |
| Campo explícito para saber que la orden necesita autorización | Por confirmar. Hoy se detecta por el texto de `faltantesParaCerrar` |
| Filtros de «Atender otro vehículo» | Por confirmar |
| Textos con acentos mal codificados (`SupÃ©r`) | La app los corrige; conviene arreglarlo en la base de datos |
| Error 500 al volver a solicitar una prueba fallida | ✅ Resuelto (11 nov 2026) |

---

## 10. Despliegue de la versión web

Lo que se entrega al servidor y lo que el servidor debe cumplir. El paso a paso completo está en [CONTEXTO.md](CONTEXTO.md) §8 y la configuración de nginx en el [Anexo A de PLAN_PWA.md](PLAN_PWA.md#anexo-a-publicación-de-la-versión-web).

### Compilar en local

En la computadora (no en el servidor), desde la carpeta raíz del proyecto, con Flutter 3.47, `git` y `bash`:

```bash
flutter pub get
```

```bash
tool/build_web.sh
```

- Si dice `permission denied`: `bash tool/build_web.sh`.
- Otra ruta: `BASE_HREF=/otra-ruta/ tool/build_web.sh`. Otro API: `tool/build_web.sh --dart-define=API_BASE_URL=https://...`.
- Resultado: la carpeta `build/web/` y el mensaje `Compilación <número> lista en build/web/`.
- Publicar desde la rama a liberar sin cambios pendientes; si no, el número termina en `-cambios`.

### Qué se entrega

Todo el contenido de `build/web/`, que reemplaza por completo al anterior en la carpeta servida en `https://springtelecom.mx/ordenservicioapp/`:

| Archivo | Para qué |
|---|---|
| `index.html`, `flutter_bootstrap.js`, `main.dart.js` | La app |
| `canvaskit/` | Motor de Flutter (se sirve desde nuestro servidor, no desde `gstatic.com`) |
| `assets/` | Imágenes y fuentes |
| `sw.js`, `pwa.js` | Service worker y aviso de versión nueva |
| `build.json` | `{"build":"<número>"}`: número de la versión publicada |
| `manifest.json`, `icons/`, `favicon.png` | Instalación de la PWA |
| `flutter.js`, `version.json`, `flutter_service_worker.js` | Los genera Flutter; se suben igual (el último no se registra) |

Ejemplo de copia (ruta y acceso los da infraestructura):

```bash
rsync -av --delete build/web/ <usuario>@<servidor>:<carpeta-de-ordenservicioapp>/
```

### Qué debe cumplir el servidor

| Requisito | Motivo |
|---|---|
| HTTPS | Sin él no se instala la PWA ni funcionan cámara y ubicación |
| `Cache-Control: no-cache` en todo | Los archivos no llevan hash en el nombre; así siempre se revisa si cambiaron (responde 304 si no) |
| `.wasm` como `application/wasm` y gzip en `.js`, `.wasm`, `.json` y fuentes | Carga más rápida |
| `Permissions-Policy: camera=(self), geolocation=(self)` | Fotos y ubicación |
| CSP del Anexo A.5 (hoy en `Report-Only`) | Seguridad |
| No cachear `index.html`, `sw.js` ni `build.json` en un CDN o proxy | Detectar versiones nuevas |

### Comprobar después de publicar

```bash
curl -s https://springtelecom.mx/ordenservicioapp/build.json
```

Debe responder el número de la compilación recién subida. No hace falta limpiar cachés: la app avisa «Hay una versión nueva de la app» con **Recargar**.
