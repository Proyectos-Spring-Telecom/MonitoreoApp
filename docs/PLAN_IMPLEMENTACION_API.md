# Plan de implementación del API — Monitoreo (Spring Telecom)

> La interfaz de usuario está terminada y funciona con datos simulados.
> Este plan reemplaza esas simulaciones por servicios reales, en el mismo orden en que el usuario recorre la app:
> **Inicio de sesión → Perfil → Catálogos → Orden de servicio → Órdenes realizadas → Detalle → Compartir.**
>
> Marca cada casilla (`- [x]`) conforme se complete. Una fase está terminada cuando cumple su **criterio de cierre**.

---

## Resumen de avance

| Fase | Nombre | Estado |
|---|---|---|
| 0 | Acuerdos con backend | 🟡 En progreso |
| 1 | Infraestructura de red | 🟡 En progreso |
| 2 | Autenticación y sesión | 🟡 Casi terminada — criterio de cierre cumplido; login, sesión, recuperación y cambio de contraseña validados en dispositivo; solo falta validar la renovación automática del token |
| 3 | Perfil de usuario | ✅ Terminada |
| 4 | Catálogos | 🟡 Casi terminada — todas las listas vienen del API; falta confirmar en dispositivo los nombres de campo y el catálogo de estatus |
| 5 | Orden de servicio: captura y registro | ✅ Terminada — validada en dispositivo; quedan mejoras opcionales (borrador local, progreso de subida, permisos) |
| 6 | Órdenes realizadas (historial) | 🟡 En progreso — listado real con paginación; búsqueda y filtro por fecha aún en la app |
| 7 | Detalle de instalación y estatus | 🟡 En progreso — detalle real con respuestas, fotos y firmas; faltan nombres de producto, dispositivo y SIM (backend) |
| 8 | Compartir (correo y WhatsApp) | ⬜ Pendiente |
| 9 | Calidad, seguridad y publicación | ⬜ Pendiente |

Estados sugeridos: ⬜ Pendiente · 🟡 En progreso · ✅ Terminada · ⛔ Bloqueada

> Una casilla marcada significa **implementado y cubierto por pruebas automáticas** (`test/data/auth_flow_test.dart`).
> Las casillas "Validado contra el servidor real" se marcan solo después de probar en el dispositivo con un usuario real.

---

## Inventario de lo que hoy está simulado

| Funcionalidad | Archivo | Qué hay hoy |
|---|---|---|
| ~~Login~~ | `lib/data/datasources/remote/auth_remote_datasource.dart` | ✅ Conectado a `POST /login` + `GET /login/me` |
| ~~Token de sesión~~ | `lib/data/repositories/auth_repository_impl.dart` | ✅ Tokens reales en almacenamiento seguro, con renovación automática |
| ~~Olvidé mi contraseña~~ | `lib/presentation/auth/forgot_password/forgot_password_page.dart` | ✅ `POST /login/usuario/recuperar/acceso` |
| ~~Restablecer con enlace~~ | — | ✅ Se hace en el portal web (decisión: los usuarios pertenecen al sistema web); la app no lo implementa |
| ~~Cambio de contraseña~~ | `lib/presentation/auth/change_password/change_password_page.dart` | ✅ `PATCH /usuarios/actualizar/contrasena` |
| ~~Perfil~~ | `lib/presentation/auth/profile/profile_page.dart` | ✅ Solo lectura con `GET /login/me` (la edición de datos no es parte del perfil según backend) |
| ~~Catálogos de Datos del vehículo~~ (clientes, marcas, modelos, combustibles) | `lib/data/repositories/catalog_repository_impl.dart` | ✅ Conectados al API |
| ~~Catálogos de instalación~~ (tipo de producto, productos, dispositivos, SIM) | `lib/data/datasources/remote/installation_remote_datasource.dart` | ✅ Conectados al API |
| ~~Instalación~~ | `lib/presentation/service_order/gps_data_page.dart` | ✅ Guarda en la orden (`PATCH /ordenes-servicio/:id`) según el tipo de servicio |
| ~~Monitoristas~~ | `lib/data/repositories/service_order_repository_impl.dart` | ✅ `GET /ordenes-servicio/catalogo` |
| ~~Opciones de tipo de servicio, accesorios, funcionamiento y fallas~~ | `lib/presentation/service_order/service_details_page.dart` | ✅ Catálogo del servidor; la orden se inicia aquí |
| ~~Pruebas generadas~~ | `lib/presentation/service_order/service_review_page.dart` | ✅ Catálogo del servidor, folio `OS-…`, GPS y firmas |
| ~~Datos del vehículo~~ | `lib/presentation/service_order/service_order_page.dart` | ✅ Alta (`POST`) y edición (`PATCH`) del vehículo al tocar "Siguiente" |
| ~~Registro de la orden~~ | `lib/presentation/service_order/service_summary_page.dart` | ✅ `POST /ordenes-servicio/:id/cerrar` |
| Validación de formularios | `lib/core/constants/app_constants.dart` | `enforceServiceOrderValidation = false` (solo afecta campos no obligatorios del vehículo; los obligatorios del contrato siempre se validan) |
| ~~Órdenes realizadas~~ | `lib/presentation/orders/completed_orders_page.dart` | ✅ `GET /ordenes-servicio/paginado/:page/:limit` |
| ~~Detalle de la orden~~ | `lib/presentation/orders/order_detail_page.dart` | ✅ `GET /ordenes-servicio/:id` |
| Envío por correo | `lib/data/datasources/remote/order_share_remote_datasource.dart` | Espera 1 s y responde éxito |
| ~~URL del API~~ | `lib/core/constants/app_constants.dart` | ✅ `https://springtelecom.mx/nextAPI/api` (configurable con `API_BASE_URL`) |

---

## Convenciones para todas las fases

Cada módulo sigue la misma arquitectura que ya usa la autenticación:

```
data/datasources/remote/*_remote_datasource.dart   → llamadas HTTP
data/models/*_model.dart                            → fromJson / toJson
data/repositories/*_repository_impl.dart            → une remoto + local, convierte errores
domain/entities/*.dart                              → modelos de la app
domain/repositories/*.dart                          → contrato
domain/usecases/*.dart                              → una acción por clase
presentation/controllers/*_controller.dart          → ChangeNotifier (Provider)
```

- Los errores llegan a la UI como `Failure` (`ServerFailure`, `NetworkFailure`, `AuthFailure`, `CacheFailure`) con un mensaje en español listo para mostrarse.
- Toda pantalla que consulte datos maneja tres estados: **cargando**, **error con botón "Reintentar"** y **vacío**.
- Cada datasource se prueba con `MockClient` del paquete `http` antes de conectarlo a la UI.
- Ningún mock se borra hasta que su reemplazo funcione contra el servidor real.
- Las respuestas se leen con `JsonReader` (`lib/core/utils/json_reader.dart`), que acepta datos en la raíz o dentro de `data` y no distingue mayúsculas en las claves.

---

## Fase 0 — Acuerdos con backend

**Objetivo:** tener el contrato del API definido antes de escribir código.

- [x] Recibir la documentación de autenticación (login, me, refresh, logout) — `Auth_Login_Refresh_Logout.md`
- [x] Recibir la documentación de vehículos, instalaciones, contraseñas y órdenes de servicio
- [ ] Recibir la documentación de compartir (correo con PDF)
- [x] Confirmar la URL de producción: `https://springtelecom.mx/nextAPI/api`
- [ ] Confirmar las URL de desarrollo y pruebas (si existen)
- [x] Definir el esquema de autenticación: access token Bearer + refresh token, renovación al recibir 401
- [x] Confirmar la duración del access token: **6 horas** (confirmado por backend)
- [ ] Confirmar la duración del refresh token (define cada cuánto el técnico debe volver a iniciar sesión)
- [ ] Acordar el formato estándar de respuestas y errores (observado: servidor Express; errores JSON con `message`; el 401 sin token responde texto plano `Unauthorized`)
- [x] Obtener un ejemplo real de la respuesta de `GET /login/me` para confirmar los nombres de los campos
- [ ] Reportar a backend que algunos textos llegan con acentos mal codificados (`SupÃ©r Administrador`); la app los corrige, pero conviene arreglarlo en la base de datos
- [ ] Decidir si la app necesita guardar la contraseña de la sesión ("uso interno de gateways" en la documentación web); por ahora **no se guarda**
- [ ] Confirmar el límite de solicitudes (el servidor reporta 100 por minuto) y si aplica por usuario o por IP
- [x] Acordar paginación para listados: `page`/`limit` (`/ordenes-servicio/paginado/:page/:limit`, `/instalaciones/paginado`)
- [x] Definir cómo se suben fotos y firmas: una petición multipart por archivo (`POST /ordenes-servicio/:id/archivos/:clave`, campo `file`)
- [x] Definir límites de imágenes: PNG o JPG, máximo 10 MB (la app convierte otros formatos a JPG)
- [x] Confirmar quién genera el folio: el servidor (`OS-…`)
- [ ] Confirmar el catálogo `estatusInstalacion` y qué transiciones puede hacer la app (`PATCH estatus`)
- [ ] Entregar al backend la especificación del PDF (`pdf_orden_servicio.md`) y el diseño generado
- [ ] Obtener usuarios de prueba (técnico activo, técnico inactivo)

### Endpoints

Las rutas marcadas como **confirmadas** vienen de la documentación del backend; el resto son una propuesta por validar.

| Módulo | Método | Ruta | Estado |
|---|---|---|---|
| Auth | POST | `/login` — body `{ userName, password }` | ✅ Confirmada |
| Auth / Perfil | GET | `/login/me` — Bearer | ✅ Confirmada |
| Auth | POST | `/login/refresh` — body `{ refreshToken }`, sin Bearer | ✅ Confirmada |
| Auth | POST | `/login/logout` — body `{ refreshToken }`, sin Bearer | ✅ Confirmada |
| Vehículos | POST | `/productos/vehiculos` — `multipart/form-data` | ✅ Confirmada |
| Vehículos | PATCH | `/productos/vehiculos/{idVehiculo}` — `multipart/form-data`, sin `idCliente` | ✅ Confirmada |
| Vehículos | GET | `/productos/vehiculos/{idVehiculo}` | ✅ Confirmada (aún no se usa: no hay pantalla de edición) |
| Catálogos | GET | `/clientes/list` | ✅ Confirmada |
| Catálogos | GET | `/cat-marcas/list` | ✅ Confirmada |
| Catálogos | GET | `/cat-modelos/list` (cada modelo trae su marca) | ✅ Confirmada |
| Catálogos | GET | `/cat-tipo-combustible/list` | ✅ Confirmada |
| Instalaciones | POST | `/instalaciones` — JSON `{ idCliente, idProducto, idDispositivo, idSim, comentario }` | ✅ Confirmada · la app ya no lo llama (lo hace el servidor al cerrar la orden) |
| Instalaciones | PATCH | `/instalaciones/{id}` — parcial, con `estatusInstalacionAnterior` y `comentario` | ✅ Confirmada · la app ya no lo llama (lo hace el servidor al cerrar la orden) |
| Instalaciones | GET | `/instalaciones/{id}` | ✅ Confirmada (aún no se usa) |
| Instalaciones | POST | `/instalaciones/paginado` — `{ page, limit, idTipoProducto? }` | ✅ Confirmada (para el listado, Fase 6) |
| Instalaciones | POST | `/instalaciones/paginado` con filtros `idCliente`, `estatusInstalacion` e `idProducto` (instalaciones vigentes del cliente para "Edición de la instalación") | ⏳ Solicitado a backend el 28 oct 2026. Mientras tanto la app solo revisa las primeras 50 filas y filtra por producto y estatus 1 |
| Instalaciones | PATCH | `/instalaciones/estatus/{id}` — `{ estatusInstalacion: 0\|1\|5, comentario }` | ✅ Confirmada (Fase 7) |
| Instalaciones | GET | `/instalaciones/historico/{id}` | ✅ Confirmada (Fase 7) |
| Catálogos | GET | `/productos/list?idCliente=&idTipoProducto=` | ✅ Confirmada |
| Catálogos | GET | `/dispositivos/list?idCliente=&idTipoDispositivo=` (una llamada por tipo) | ✅ Confirmada |
| Catálogos | GET | `/sims/list?idCliente=` | ✅ Confirmada |
| Geocercas | GET | `/geocercas/list?idCliente=` (se filtra por `idInstalacion` en la app) | ✅ Confirmada |
| Auth | POST | `/login/usuario/recuperar/acceso` — body `{ userName }`, sin Bearer, responde texto | ✅ Confirmada |
| Auth | PATCH | `/login/cambiar/accesso` — lo usa solo el portal web (restablecer con el enlace del correo) | ✅ Confirmada · no aplica a la app |
| Perfil | PATCH | `/usuarios/actualizar/contrasena` — body `{ passwordActual, passwordNueva, passwordNuevaConfirmacion }`, Bearer de sesión | ✅ Confirmada |
| Vehículos | GET | `/productos/vehiculos/placa/:placa` (buscar antes de crear) | ✅ Confirmada |
| Órdenes de servicio | GET | `/ordenes-servicio/catalogo` (opciones por sección y monitoristas) | ✅ Confirmada |
| Órdenes de servicio | POST | `/ordenes-servicio` — `{ claveApp, tipoServicio, idCliente, idInstalacion? }` | ✅ Confirmada |
| Órdenes de servicio | PATCH | `/ordenes-servicio/:id` — guardado parcial | ✅ Confirmada |
| Órdenes de servicio | POST | `/ordenes-servicio/:id/archivos/:clave` — multipart `file` (PNG/JPG) | ✅ Confirmada |
| Órdenes de servicio | POST | `/ordenes-servicio/:id/cerrar` | ✅ Confirmada |
| Órdenes de servicio | POST | `/ordenes-servicio/:id/cancelar` | ✅ Confirmada |
| Órdenes de servicio | GET | `/ordenes-servicio/:id` y `/ordenes-servicio/paginado/:page/:limit` | ✅ Confirmada (Fases 6 y 7) |
| Compartir | POST | `/ordenes/{id}/compartir/correo` | Propuesta |

**Criterio de cierre:** contrato documentado y aprobado; usuarios de prueba disponibles.

---

## Fase 1 — Infraestructura de red

**Objetivo:** un cliente HTTP robusto que usen todos los módulos.

- [x] Configurar la URL base por entorno con `--dart-define` (`API_BASE_URL`); por defecto, producción
- [x] Agregar a `ApiClient` los métodos `put`, `patch` y `delete`
- [x] Agregar a `ApiClient` la subida de archivos (`multipart`), con renovación del token y reenvío completo del archivo tras un 401
- [x] Inyectar el token automáticamente en cada petición (sin pasarlo a mano); `auth: false` para login, refresh y logout
- [x] Manejar `401`: una sola renovación aunque fallen varias peticiones a la vez, reintento de la petición original y, si el refresh se rechaza, cerrar sesión y llevar al login
- [x] Convertir errores del servidor a `Failure` con el mensaje que envía el API (`message`, `mensaje`, `error`, `title`, `detail`)
- [x] Ignorar cuerpos genéricos de Express (`Unauthorized`, `Not Found`…) y mostrar mensajes en español
- [x] Mensaje específico para el límite de solicitudes (429)
- [x] Distinguir errores de red (sin internet, timeout) de errores del servidor
- [x] Soportar respuestas que son listas JSON, no solo objetos
- [x] Registrar peticiones y respuestas en consola solo en modo debug
- [x] Guardar los tokens en `flutter_secure_storage` en lugar de `SharedPreferences`
- [x] Agregar `<uses-permission android:name="android.permission.INTERNET"/>` al `AndroidManifest.xml` principal
- [x] Pruebas unitarias del `ApiClient` con `MockClient`
- [x] Validado contra el servidor real desde el dispositivo en debug (Android)
- [ ] Validado contra el servidor real en un build de release

**Criterio de cierre:** una petición de prueba al servidor real responde correctamente desde el dispositivo en debug y en release.

---

## Fase 2 — Autenticación y sesión

**Objetivo:** iniciar y cerrar sesión con usuarios reales.

- [x] Implementar `login` real (`POST /login` con `userName` y `password`); acepta `token`/`accessToken`/`access_token` y `refreshToken`/`refresh_token`, en la raíz o en `data`
- [x] Encadenar `GET /login/me` después del login; el login solo se completa si `/me` responde bien
- [x] Leer el usuario de `/login/me` con nombres de campo flexibles (id, nombre, correo, teléfono, rol, estatus, avatar, permisos)
- [x] Ajustar `UserModel.fromJson` a los nombres exactos de la respuesta real de `/login/me` (`nombre` + `apellidoPaterno` + `apellidoMaterno`, `userName`, `telefono`, `fotoPerfil`, `rol.descripcion`, `idCliente`/`nombreCliente`, `permisos[].idPermiso`)
- [x] Guardar el token real y el refresh token en lugar de `mock_token_{id}`
- [x] Guardar los IDs de permisos del usuario
- [x] Mostrar en el login los errores del API (credenciales inválidas, mensaje del backend, sin conexión)
- [x] Al abrir la app, validar la sesión guardada con `GET /login/me` (una vez por arranque)
- [x] Descartar sesiones de la versión simulada anterior (usuario guardado sin tokens)
- [x] Cerrar sesión en el servidor (`POST /login/logout`) y limpiar los datos locales aunque el API falle
- [x] Sesión expirada: volver al login desde cualquier pantalla con el aviso "Tu sesión expiró"
- [x] Conectar "¿Olvidaste tu contraseña?" (`POST /login/usuario/recuperar/acceso`)
- [x] Restablecer con el enlace del correo: se hace en el portal web y después se inicia sesión en la app con la nueva contraseña (decisión, no requiere deep link)
- [x] Conectar la pantalla de cambio de contraseña (`PATCH /usuarios/actualizar/contrasena`); un 401 por contraseña incorrecta no cierra la sesión
- [x] Reglas de contraseña del API: 7 a 15 caracteres, mayúscula, minúscula, número y carácter especial
- [x] Mostrar el nombre y el rol reales en la bienvenida, el menú lateral y el perfil
- [x] Pruebas: login correcto, credenciales incorrectas, `/me` fallido, token vencido, refresh rechazado, sin conexión, logout
- [x] Validado en dispositivo: inicio de sesión (`POST /login` → `GET /login/me`, ambos 200)
- [x] Validado en dispositivo: cierre de sesión (`POST /login/logout`, 200)
- [x] Validado en dispositivo: cerrar por completo la app, volver a abrirla y seguir con la sesión iniciada
- [ ] Validado en dispositivo: renovación automática del token al vencer el access token
- [x] Validado en dispositivo: solicitar la recuperación, restablecer en la web e iniciar sesión en la app con la nueva contraseña
- [x] Validado en dispositivo: credenciales incorrectas muestran "Correo o contraseña incorrectos."

**Criterio de cierre:** un técnico real inicia sesión, cierra la app, la vuelve a abrir sin perder la sesión y puede cerrar sesión.

---

## Fase 3 — Perfil de usuario

**Objetivo:** mostrar los datos reales del técnico y permitirle cambiar su contraseña.

- [x] Consultar el perfil (`GET /login/me`) al entrar a la pantalla y al deslizar hacia abajo
- [x] Indicador de carga y aviso de error con "Reintentar" (conserva los datos ya mostrados)
- [x] Quitar el teléfono fijo y usar el del API
- [x] Mostrar las etiquetas de estatus ("Activo"/"Inactivo") y rol con los datos reales
- [x] (Opcional) Mostrar foto de perfil desde `avatarUrl`
- [x] Según backend, el perfil es de solo lectura: nombre, correo, rol, teléfono, cliente y último acceso ("Sin registro" si falta); la edición vive en el módulo de usuarios (`PATCH /usuarios/{id}`)
- [x] Validado en dispositivo: el perfil muestra los datos reales de `GET /login/me`
- [x] Validado en dispositivo: cambio de contraseña (`PATCH /usuarios/actualizar/contrasena`)

**Criterio de cierre:** el perfil muestra los datos reales y el técnico puede cambiar su contraseña.

---

## Fase 4 — Catálogos

**Objetivo:** que todos los dropdowns y listas de opciones vengan del API.

- [x] Crear `CatalogRepository` con caché en memoria (una sola consulta aunque se pida varias veces a la vez)
- [x] Leer listas en la raíz o dentro de `data`, con claves en camelCase o PascalCase; descartar elementos sin id o sin nombre; ordenar por nombre
- [x] Clientes (`/clientes/list`)
- [x] Marcas y modelos (`/cat-marcas/list`, `/cat-modelos/list`); los modelos se filtran por la marca elegida
- [x] Combustibles (`/cat-tipo-combustible/list`)
- [ ] Confirmar en el dispositivo los nombres de campo de cada catálogo (la consola muestra las claves recibidas)
- [x] Tipos de servicio (Instalación, Revisión, C/SIM, C/Equipo, Desinstalación)
- [x] "Vehículo cuenta con" (accesorios) — `GET /ordenes-servicio/catalogo`
- [x] Funcionamiento del vehículo — `GET /ordenes-servicio/catalogo`
- [x] Fallas encontradas del equipo — `GET /ordenes-servicio/catalogo`
- [x] Tipo de producto (¿Qué se instalará?): Vehículo, Activo, Inmueble, Persona — catálogo fijo de la documentación
- [x] Productos filtrados por tipo y cliente (`/productos/list`)
- [x] Dispositivos por tipo de producto (`/dispositivos/list`, una llamada por tipo de dispositivo y fusión sin duplicados)
- [x] SIMs del cliente (`/sims/list`)
- [ ] Confirmar en el dispositivo los nombres de campo de productos, dispositivos y SIMs (la consola muestra las claves)
- [x] Monitoristas — `GET /ordenes-servicio/catalogo`
- [x] Pruebas generadas — `GET /ordenes-servicio/catalogo`
- [ ] Estatus de instalación (validar contra `InstallationStatus` en `lib/domain/entities/installation_status.dart`)
- [x] Mover las listas fijas de `service_details_page.dart` y `service_review_page.dart` al repositorio de órdenes de servicio
- [x] Usar IDs del API (no textos) en los valores seleccionados — Datos del vehículo
- [x] Estados de carga y error con "Reintentar" en los dropdowns — Datos del vehículo
- [x] Eliminar `ServiceOrderCatalogs` (ya no lo usaba ninguna pantalla)

**Criterio de cierre:** no queda ninguna lista fija en el código del flujo de orden de servicio.

---

## Fase 5 — Orden de servicio: captura y registro

**Objetivo:** registrar órdenes reales con todos sus datos, fotos y firmas.

### 5.0 Datos del vehículo
- [x] Marcar en la interfaz los campos obligatorios (`*` en Cliente, Placa y Fotografías obligatorias, con leyenda)
- [x] Validar Cliente, Placa y las 6 fotografías antes de llamar al API, con mensaje en cada sección
- [x] Placa en mayúsculas, máximo 10 caracteres; VIN hasta 17; año de 4 dígitos; km y capacidad aceptan decimales con coma o punto
- [x] "Siguiente" da de alta el vehículo (`POST /productos/vehiculos`, multipart) y guarda el id en el borrador
- [x] Al regresar y volver a tocar "Siguiente": `PATCH` solo si hubo cambios, sin `idCliente` y solo con fotos nuevas
- [x] El cliente queda bloqueado después del alta
- [x] Enviar las 9 fotos/documentos con su nombre de campo (`foto`, `fotoFrente`… `permisoCarga`)
- [x] Validar formato (PNG, JPG, WEBP, PDF) y tamaño máximo de 3 MB por archivo
- [x] Indicador "Guardando..." y errores del servidor en pantalla
- [x] Limpiar el formulario cuando la orden se registra
- [x] Confirmar qué campo de la respuesta del `POST` trae el id del vehículo (la orden se registra con el vehículo correcto)
- [x] Definir si las 6 "Fotografías obligatorias" deben bloquear el avance → **sí**: la sección lleva `*`, "Siguiente" no avanza hasta tomarlas y muestra cuántas faltan (el API las acepta como opcionales)
- [x] Validado en dispositivo contra el servidor real

### 5.0a Contrato de órdenes de servicio
- [x] Repositorio `ServiceOrderRepository`: catálogo (con caché), iniciar, guardado parcial, subir archivos, cerrar, cancelar
- [x] `claveApp` (UUID v4) por orden para idempotencia; se renueva al cancelar o registrar
- [x] Fotos y firmas como multipart `file`; PNG/JPG tal cual, otros formatos (WEBP, BMP…) se convierten a JPG; máximo 10 MB
- [x] Cierre incompleto (400 con `faltantes`) se muestra como lista al usuario
- [x] Datos del vehículo busca por placa (`GET /productos/vehiculos/placa/:placa`) antes de crear; si existe con el mismo cliente se actualiza, si es de otro cliente se avisa
- [ ] Backend: filtros `idCliente`, `estatusInstalacion` e `idProducto` en `/instalaciones/paginado` (solicitado el 28 oct 2026, ver `docs/SOLICITUD_API_EDICION_INSTALACION.md`)
- [ ] Backend: reemplazo de producto, dispositivo y SIM en la orden con el estatus de cada recurso que sale (`estatusProductoAnterior`, `estatusDispositivoAnterior`, `estatusSimAnterior`) — misma solicitud
- [ ] Backend: marcar `fotos.tablero_final` como no obligatoria en `CatOrdenServicioOpciones` (`Obligatorio = 0`). La app ya la trata como opcional; mientras no cambie, el cierre sin esa foto responde 400 con el faltante
- [ ] App: en "Edición de la instalación", el dropdown lista las instalaciones vigentes del cliente en lugar de sus productos (depende del filtro de backend)
- [x] Validado en dispositivo contra el servidor real

### Flujo de la orden (cambio del 28 oct 2026)
- Instalación: Tipo de servicio → Datos del vehículo → Instalación → Pruebas generadas → Resumen
- Revisión, C/SIM, C/Equipo y Desinstalación: Tipo de servicio → Edición de la instalación → Pruebas generadas → Resumen
- [x] Tipo de servicio es el primer paso (pestaña "Orden de servicio") y solo guarda en el borrador
- [x] Datos del vehículo pasa a ser una pantalla propia y recupera lo guardado al volver a abrirla
- [x] La orden se inicia al continuar en Instalación / Edición de la instalación: ahí ya se conocen el cliente y, si aplica, la instalación
- [x] Edición de la instalación: cliente, tipo de producto y producto (con búsqueda por placa o nombre) → instalación vigente
- [x] Elegir otra instalación con la orden iniciada pide confirmación, la cancela y se inicia otra
- [x] Validado en dispositivo contra el servidor real

### 5.0b Tipo de servicio
- [x] Un solo tipo de servicio, obligatorio, sin valor por omisión
- [x] Opciones de "Vehículo cuenta con", "Funcionamiento" y "Fallas" desde el catálogo del servidor; se envían todas como sí/no
- [x] Fotos del catálogo; las obligatorias (`tablero_inicio`, `tablero_final`) bloquean el avance
- [x] Respuestas y fotos se envían al iniciar la orden; solo se suben fotos nuevas
- [x] Cambiar el tipo con la orden iniciada pide confirmación, la cancela y se inicia otra
- [x] ~~Revisión salta la pantalla de Instalación~~ (ahora pasa por Edición de la instalación)

### 5.0c Instalación
- [x] Se quita la sección 04 "Comentario" (el comentario de la instalación lo arma el servidor con las observaciones)
- [x] Ya no se llama a `POST`/`PATCH /instalaciones`: lo hace el servidor al cerrar la orden
- [x] Alta: tipo de producto, cliente fijo de la orden, producto, dispositivo y SIM → `idProducto`, `idDispositivoNuevo`, `idSimNuevo`
- [x] C/Equipo: dispositivo nuevo + estatus del que sale → `idDispositivoNuevo`, `estatusSalienteAnterior`
- [x] C/SIM: SIM nueva + estatus de la que sale → `idSimNuevo`, `estatusSalienteAnterior`
- [x] Desinstalación: estatus de baja Inactiva (0) o Inservible (5) → `estatusInstalacionBaja`
- [x] Recursos nuevos del cliente y disponibles (estatus 1); distintos al instalado en los cambios
- [ ] Validar permisos del usuario antes de mostrar la pantalla

### 5.0d Pruebas generadas
- [x] Pruebas y monitoristas desde el catálogo; monitorista por id
- [x] Al menos una prueba correcta (salvo desinstalación)
- [x] Observaciones obligatorias si se marcó la falla "Otro"
- [x] Firmas obligatorias, subidas como `firma_cliente` y `firma_tecnico`; al volver a la pantalla se muestran las ya guardadas
- [x] Envía `fechaCaptura` con zona horaria, `lat` y `lng` del celular
- [x] Folio del servidor en lugar de `0001`

### 5.1 Datos y validaciones
- [x] Validar formato de placa, año, VIN (17 caracteres), kilometraje y capacidad
- [x] Un solo tipo de servicio obligatorio
- [x] Fotografías y firmas obligatorias según el catálogo
- [x] ~~Comentario de instalación obligatorio~~ (sección eliminada)

### 5.2 Borrador
- [ ] Guardar el borrador (`ServiceOrderDraft`) en almacenamiento local para no perder datos si se cierra la app (la orden ya queda en el servidor como borrador)
- [x] Restaurar los datos al volver a Tipo de servicio, Instalación y Pruebas generadas
- [x] Limpiar el borrador al registrar con éxito o al cancelar

### 5.3 Evidencias
- [x] Comprimir fotos antes de subir (calidad 70 %, ancho máximo 1600 px)
- [x] Subir las fotos del vehículo (9), las de la orden (5) y las 2 firmas
- [ ] Mostrar progreso de subida
- [x] No repetir fotos ya subidas al volver a una pantalla

### 5.4 Registro
- [x] Crear el repositorio de órdenes de servicio
- [x] Enviar coordenadas GPS
- [x] Obtener el folio del servidor
- [x] Reemplazar el `Future.delayed` del Resumen por `POST /ordenes-servicio/:id/cerrar`
- [x] Mostrar los faltantes del servidor y permitir corregir sin perder la captura
- [x] Evitar órdenes duplicadas (`claveApp`)

**Criterio de cierre:** una orden completa se registra desde el dispositivo y aparece en el sistema con todas sus fotos y firmas. ✅ Cumplido el 28 oct 2026.

> Mejoras pendientes que no bloquean el cierre: borrador local si se cierra la app (la orden ya queda en el servidor), progreso de subida, validar permisos del usuario y el filtro `idProducto` de backend.

---

## Fase 6 — Órdenes realizadas (historial)

**Objetivo:** listar las órdenes reales del técnico.

- [x] Consultar el listado (`GET /ordenes-servicio/paginado/:page/:limit`) con paginación (scroll infinito)
- [x] Búsqueda por folio, cliente, tipo y estatus — sobre las órdenes ya cargadas
- [ ] Búsqueda en el servidor (requiere que backend agregue el filtro al paginado)
- [x] Filtro por fecha — sobre las órdenes ya cargadas
- [ ] Filtro por fecha enviado al servidor (requiere filtro en backend)
- [x] Mostrar el estatus de cada orden
- [x] Deslizar hacia abajo para actualizar (pull to refresh)
- [x] Estados de carga, error con "Reintentar" y vacío
- [x] Leer las órdenes como entidad del dominio (`ServiceOrderRecord`) en lugar de `OrderItem`
- [x] La orden recién registrada aparece al llegar a esta pantalla (se consulta al abrirla)
- [x] Eliminar las órdenes de ejemplo
- [ ] Validado en dispositivo contra el servidor real

**Criterio de cierre:** el historial muestra las órdenes reales del técnico, con búsqueda y filtro por fecha funcionando.

---

## Fase 7 — Detalle de instalación y estatus

**Objetivo:** mostrar el detalle real de cada orden.

- [x] Consultar el detalle (`GET /ordenes-servicio/:id`) al abrir la pantalla
- [x] Respuestas por sección con el nombre del catálogo (`/ordenes-servicio/catalogo`), en el orden del catálogo
- [x] Cliente y monitorista por nombre (catálogos ya cargados); técnico por nombre cuando es el usuario de la sesión
- [x] Fotos y firmas desde la URL firmada de S3 (caduca a los 5 min; se renueva al deslizar para actualizar)
- [x] "Pendiente para cerrar" con `faltantesParaCerrar` en órdenes en borrador
- [x] Ubicación con "Ver mapa" (Google Maps) a partir de `lat`/`lng`
- [x] Estados de carga y error con "Reintentar"
- [x] Eliminar `OrderDetail.mock()`
- [ ] Backend: incluir nombres en el listado y el detalle (placa o producto, dispositivo, SIM, técnico); hoy solo vienen IDs
- [ ] (Opcional) Caché de imágenes en disco (`cached_network_image`)
- [ ] (Si aplica) Acciones de cambio de estatus con `PATCH /instalaciones/{id}/estatus` según las transiciones permitidas
- [ ] Validado en dispositivo contra el servidor real

**Criterio de cierre:** el detalle de cualquier orden real muestra todos sus datos, fotos y firmas.

---

## Fase 8 — Compartir (correo y WhatsApp)

**Objetivo:** que el cliente reciba el PDF por correo y el resumen por WhatsApp.

- [ ] Backend: implementar la plantilla del PDF con el diseño aprobado
- [ ] Conectar `sendOrderByEmail` (`POST /ordenes/{id}/compartir/correo`) en `order_share_remote_datasource.dart`
- [ ] Mostrar los errores del API en el diálogo de correo
- [ ] (Opcional) Permitir varios destinatarios o copia al técnico
- [ ] (Opcional) Incluir en el mensaje de WhatsApp un enlace seguro al PDF
- [ ] Probar WhatsApp en Android y iOS con y sin la app instalada

**Criterio de cierre:** el correo con el PDF llega al destinatario y el mensaje de WhatsApp se abre con el resumen correcto.

---

## Fase 9 — Calidad, seguridad y publicación

**Objetivo:** dejar la app lista para producción.

- [ ] Pruebas unitarias de datasources y repositorios
- [ ] Pruebas de widgets de los flujos principales (login, registro de orden, historial)
- [x] Actualizar `test/widget_test.dart` (busca el texto anterior del login)
- [ ] Manejo sin conexión: aviso claro y reintento
- [ ] Revisar permisos y textos en Android e iOS (cámara, galería, ubicación, internet)
- [ ] No registrar tokens ni datos sensibles en consola en release
- [ ] Buscar y eliminar todos los `TODO` y mocks restantes
- [ ] Prueba completa en dispositivo físico Android y iOS contra el entorno de pruebas
- [ ] Generar builds de release (Android App Bundle e iOS)
- [ ] Actualizar versión en `pubspec.yaml`

**Criterio de cierre:** un técnico completa el flujo de punta a punta en un build de release contra producción.

---

## Bitácora

| Fecha | Fase | Avance / decisión | Responsable |
|---|---|---|---|
| 27 oct 2026 | 0 | Se recibe la documentación de Auth (login, me, refresh, logout). URL de producción: `https://springtelecom.mx/nextAPI/api`. | — |
| 27 oct 2026 | 0 | La documentación es para web (`sessionStorage`). En móvil los tokens se guardan cifrados (Keychain/Keystore) y la sesión persiste al reabrir la app. | — |
| 27 oct 2026 | 0 | No se guarda la contraseña en el dispositivo hasta confirmar si algún servicio de la app la necesita. | — |
| 27 oct 2026 | 1–3 | Implementados cliente HTTP con renovación automática, login + me, refresh, logout y perfil con `GET /login/me`. 20 pruebas automáticas pasan. Falta validar con un usuario real. | — |
| 27 oct 2026 | 1 | Consulta sin token a `/login/me`: responde 401 en texto plano `Unauthorized` (Express) y límite de 100 solicitudes por minuto. | — |
| 27 oct 2026 | 2–3 | Se recibe la respuesta real de `/login/me` y se ajusta el modelo. El rol se muestra con `rol.descripcion` (el `nombre` es un código, p. ej. "SA"). La respuesta no trae estatus del usuario, así que el perfil muestra "Activo" por defecto. Se guarda el cliente del usuario (`idCliente`, `nombreCliente`) para fases siguientes. | — |
| 27 oct 2026 | 1–3 | Validado en dispositivo Android (debug) con usuario real: login, `/login/me`, perfil y logout responden 200. | Andrea |
| 27 oct 2026 | 2 | Validado en dispositivo: la sesión persiste al cerrar y reabrir la app, y las credenciales incorrectas muestran el mensaje en español. Se cumple el criterio de cierre de la fase; quedan abiertos los servicios de contraseña (sin documentación) y ver la renovación del token en el dispositivo. | Andrea |
| 27 oct 2026 | 4–5 | Se recibe la documentación de Agregar/Editar vehículo. Implementados los 4 catálogos del formulario, el alta y la edición con multipart y los campos obligatorios en pantalla. 38 pruebas automáticas pasan. Falta validar en el dispositivo. | — |
| 27 oct 2026 | 5 | Decisión: las 6 fotografías del vehículo son obligatorias en la app aunque el API las acepte como opcionales. | Andrea |
| 27 oct 2026 | 4–5 | Se recibe la documentación de Instalaciones. Implementados los catálogos (productos, dispositivos, SIMs), el alta y la edición dentro del registro. El listado, cambio de estatus e histórico quedan para las Fases 6 y 7. 56 pruebas automáticas pasan. | — |
| 28 oct 2026 | 2–3 | Se recibe la documentación de contraseñas y perfil. Implementados: solicitud de recuperación, restablecer con el token del correo, cambio de contraseña desde Perfil (reglas 7–15 con mayúscula, minúscula, número y especial) y perfil de solo lectura. 72 pruebas automáticas pasan. Falta validar en dispositivo y configurar el deep link del correo. | — |
| 28 oct 2026 | 3 | Validado en dispositivo: el cambio de contraseña desde Perfil funciona contra el servidor real. Se cumple el criterio de cierre; la Fase 3 queda terminada. | Andrea |
| 28 oct 2026 | 2 | Decisión: el restablecimiento de contraseña desde el enlace del correo se hace en el portal web, porque los usuarios pertenecen al sistema web y comparten el acceso con la app. Se retira de la app la pantalla de restablecer y ya no se necesita deep link. | Andrea |
| 28 oct 2026 | 2 | Validado en dispositivo el flujo completo de recuperación: solicitud desde la app, correo recibido, contraseña restablecida en la web e inicio de sesión en la app con la nueva contraseña. | Andrea |
| 28 oct 2026 | 0 | Backend confirma que el access token dura 6 horas. Falta confirmar la duración del refresh token. | Andrea |
| 28 oct 2026 | 5 | Se implementa el contrato de órdenes de servicio (`/ordenes-servicio`). Tipo de servicio de una sola opción que inicia la orden; Instalación sin sección de comentario y sin llamar a `/instalaciones` (el servidor aplica el movimiento al cerrar); Pruebas generadas con catálogo, GPS y firmas; cierre real con faltantes. Backend agregará el filtro `idProducto` en `/instalaciones/paginado`. 91 pruebas automáticas pasan. | — |
| 28 oct 2026 | 5 | Cambio de flujo: la orden empieza en Tipo de servicio. Instalación sigue con Datos del vehículo e Instalación; los demás tipos van a Edición de la instalación, donde se elige cliente y producto para cargar la instalación vigente. La orden se inicia al continuar en esa pantalla. 101 pruebas automáticas pasan. | Andrea |
| 28 oct 2026 | 0, 4, 6 | Revisión del plan contra el código: catálogos de la orden (tipos, accesorios, funcionamiento, fallas, pruebas y monitoristas) vienen de `/ordenes-servicio/catalogo`; se elimina `ServiceOrderCatalogs` (sin uso); el historial ya consulta el paginado real. Se confirman en Fase 0 la paginación, la subida de archivos, el límite de imágenes y el folio del servidor. | — |
| 28 oct 2026 | 5 | Validado en dispositivo: la orden de servicio funciona de punta a punta contra el servidor real (vehículo, instalación, pruebas, fotos, firmas y registro). Se cumple el criterio de cierre; la Fase 5 queda terminada. | Andrea |
| 28 oct 2026 | 6–7 | Servicios y su detalle conectados a `GET /ordenes-servicio/paginado/:page/:limit` y `GET /ordenes-servicio/:id`. El API solo devuelve IDs: cliente, monitorista y opciones se resuelven con los catálogos; producto, dispositivo y SIM se muestran por ID. Las fechas llegan en hora de la Ciudad de México con sufijo `Z` y se leen como tal (`MexicoCityTime.parseApi`). Compartir por WhatsApp usa los datos reales. 112 pruebas automáticas pasan. | — |
| 28 oct 2026 | 0, 5 | Decisión: "Edición de la instalación" mostrará en el dropdown las instalaciones vigentes del cliente. Ningún contrato lo permite hoy (`/instalaciones/paginado` solo filtra por `idTipoProducto`), así que se solicita a backend el filtro por `idCliente`, `estatusInstalacion` e `idProducto` en lugar de recorrer todo el paginado en la app. | Andrea |
| 28 oct 2026 | 5 | Decisión: en Tipo de servicio, la foto "Tablero al iniciar" es obligatoria; "Tablero al finalizar" es opcional y solo se habilita al activar el switch "Tablero correcto al final" (si se apaga, la foto no se envía). Se pide a backend quitar la obligatoriedad de `tablero_final` en el catálogo. 114 pruebas automáticas pasan. | Andrea |
| 3 nov 2026 | 3–9 | Se recibe el contrato de la App de instaladores (NextAPI `docs/app-instaladores.md`). La App pasa a trabajar solo con la agenda + `POST /:id/iniciar` (ya no crea órdenes con `POST /ordenes-servicio` ni las cancela). Implementados: acceso solo para rol 8, catálogo y motivos al iniciar sesión, agenda (programadas y en curso), iniciar con `claveApp` guardada por orden, vehículo del alta con autorización para desinstalar equipo existente, código de verificación en mantenimientos, equipo y SIM del almacén o reservados, estatus saliente 3/4/5, pruebas validadas por el operador con consulta periódica, cierre solo con `faltantesParaCerrar` vacío, no cumplida con motivos del técnico, historial cerradas/no cumplidas, PDF y compartir por WhatsApp o correo. 112 pruebas automáticas pasan. Falta validar contra el servidor real. | — |
