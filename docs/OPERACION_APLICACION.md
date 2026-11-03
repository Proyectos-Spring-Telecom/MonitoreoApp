# Cómo opera Monitoreo

Aplicación Flutter para los técnicos instaladores de Spring Telecom (rol 8). El técnico atiende en campo las órdenes que operación le programa: instalación (alta), revisión, cambio de SIM, cambio de equipo y desinstalación.

La implementación sigue el contrato de NextAPI para la App de instaladores (`docs/app-instaladores.md` en el repositorio de NextAPI, rama `dev-isra`). Los números **§** de este documento son sus secciones. Si el contrato y el código del API no coinciden, manda el código del API.

La URL base del API es `https://springtelecom.mx/nextAPI/api`. Se puede cambiar al compilar con `--dart-define=API_BASE_URL=https://...`.

La orden vive en el servidor: cada paso se guarda con `PATCH` y las fotos se suben al momento. Si se cierra la app a mitad del flujo, al volver a abrir la orden desde la Agenda («En curso») se retoma con lo que ya está en el servidor.

---

## Arquitectura

Tres capas. Las pantallas no llaman al HTTP directamente.

```
Pantalla (solo muestra y captura)
  → ServiceOrderFlowController (único que habla con el API durante una orden)
    → ServiceOrderRepository (contrato en domain)
      → ServiceOrderRepositoryImpl + ServiceOrderModel (data)
        → ApiClient
```

| Capa | Qué contiene |
|---|---|
| `presentation` | Pantallas, `AuthController`, `ServiceOrderFlowController`, pasos del flujo |
| `domain` | Entidades (`ServiceOrderRecord`, `ServiceType`, estatus), contratos de repositorio, casos de uso de autenticación |
| `data` | Modelos JSON, datasources, repositorios y `OrderKeyStorage` (claveApp por orden) |
| `core` | Rutas, cliente HTTP, tema, ubicación, errores |

Los errores llegan a la interfaz como `Failure` con un mensaje en español. `FailureStatus` agrega `isNotFound` (404) e `isConflict` (409).

---

## Arranque

```mermaid
flowchart TD
  A[main] --> B[Armar ApiClient, repositorios y AuthController]
  B --> C[Leer usuario y tokens guardados]
  C --> D{Hay sesión local de un técnico rol 8?}
  D -->|Sí| E[Abrir Inicio]
  D -->|No| F[Abrir Login]
  E --> G[GET /login/me y catálogos en segundo plano]
```

- El permiso de ubicación ya no se pide al arrancar: se pide al iniciar una orden, que es cuando se registra la ubicación.
- Al entrar a Inicio se cargan y guardan en memoria `GET /ordenes-servicio/catalogo` y `GET /ordenes-servicio/motivos` (§2).

### Sesión en cada petición

Toda llamada autenticada lleva `Authorization: Bearer`. Con un 401 se intenta `POST /login/refresh` una sola vez (aunque varias peticiones fallen a la vez) y se reintenta. Si el refresh se rechaza, se borra la sesión y se vuelve a Login. Un fallo de red o un 5xx no cierra la sesión.

---

## Autenticación (§1)

- `POST /login` → `GET /login/me`. **Si el usuario no es rol 8 no entra**: se cierra su sesión en el servidor, se borra lo local y se muestra «Esta aplicación es solo para técnicos instaladores». La misma regla aplica a la sesión guardada y a cada `GET /login/me` posterior.
- Credenciales malas → 401; límite de intentos → 429. Los dos con mensaje en español.
- Al cerrar sesión o expirar se limpian también los catálogos en memoria y las `claveApp` guardadas.
- Recuperar y cambiar contraseña siguen igual (`POST /login/usuario/recuperar/acceso`, `PATCH /usuarios/actualizar/contrasena`).

---

## Navegación

| Pestaña | Pantalla | Qué hace |
|---|---|---|
| Inicio | Bienvenida | Saludo, «Ver mi agenda» y «Ver mi historial» |
| Agenda | Agenda | Órdenes **en curso** (`borrador`) y **programadas** (`programada`, por cita) |
| Servicios | Historial | Órdenes **cerradas** y **no cumplidas** |
| Perfil | Perfil | Datos de `GET /login/me` |

| Ruta | Pantalla |
|---|---|
| `/service-order` | Una orden de la agenda, de principio a fin (argumento: la orden o su id) |
| `/order-detail` | Detalle de una orden, PDF y compartir |

---

## Orden de servicio

```mermaid
flowchart TD
  A[Agenda] --> B[Datos de la visita]
  B -->|Mantenimiento| C[Confirmar servicio: ¿el dispositivo funciona? y vehículo]
  B --> D[POST /:id/iniciar con claveApp]
  C --> D
  D --> E{Tipo}
  E -->|Alta| F[Vehículo: buscar por placa o registrar]
  F --> G{¿Ya tiene equipo?}
  G -->|Sí| H[Foto + pedir autorización y esperar]
  H -->|Rechazada| X[No cumplida]
  H -->|Autorizada| I
  G -->|No| I[Instalación: equipo y SIM]
  E -->|Mantenimiento| J[Código de verificación]
  J --> K[Edición de la instalación según el tipo]
  I --> L[Checklist: accesorios, funcionamiento, fallas y fotos]
  K --> L
  L --> M[Pruebas, monitorista, observaciones y firmas]
  M --> N[Resumen con faltantesParaCerrar]
  N -->|Faltan datos| O[Editar sección]
  O --> N
  N -->|Vacío| P[POST /:id/cerrar]
  P --> Q[PDF y compartir]
```

| Tipo | Clave | Pasos | Quién contesta las pruebas |
|---|---|---|---|
| Alta | `instalacion` | Vehículo → Instalación → Checklist → Pruebas → Resumen | Operador |
| Revisión | `revision` | Código → Instalación → Checklist → Pruebas → Resumen | Operador |
| Cambio de SIM | `c_sim` | Igual que revisión | Operador |
| Cambio de equipo | `c_equipo` | Igual que revisión | Operador |
| Desinstalación | `desinstalacion` | Igual que revisión | Técnico (en el `PATCH`) |

El indicador de pasos no deja saltar un paso que bloquea: el vehículo del alta (fijado y, si tenía equipo, autorizado) y el código de un mantenimiento.

### 1. Iniciar en campo (§4)

La pantalla muestra servicio programado, cliente, cita, vehículo, quién programó, observaciones de operación, «Unidad x de y» y referencia CRM.

- **Alta:** no se cambia el tipo (alta ↔ mantenimiento lo programa operación).
- **Mantenimiento:** se confirma el servicio entre los cuatro mantenimientos. Para revisión y cambio de equipo se pregunta «¿El dispositivo funciona?» (sí → revisión, no → cambio de equipo). `tipoServicio` solo se envía si difiere del programado.
- «Atender otro vehículo» busca por placa la instalación vigente y la manda como `idInstalacion`; el API valida que sea vigente y del cliente.
- `POST /:id/iniciar { claveApp, tipoServicio?, idInstalacion? }`. La `claveApp` es un UUID v4 generado **una sola vez por orden** y guardado en el teléfono (`OrderKeyStorage`); un reintento usa la misma.
- Después se registran `fechaCaptura`, `lat` y `lng` con `PATCH`. Si se niega la ubicación, `lat` y `lng` van en `null`.

### 2. Vehículo del alta (§6, §7)

1. `GET /productos/vehiculos/placa/:placa`. Si existe y es del cliente, se usa **sin modificar sus datos**. Si hay más de uno con esa placa el API responde 400 y se muestra el mensaje.
2. Si no existe: `POST /productos/vehiculos` con `idCliente` de la orden y `placa`; número económico, marca, modelo, año, color, VIN, combustible y fotos son opcionales.
3. `PATCH { idProducto }`.
4. Si `faltantesParaCerrar` dice que el vehículo ya tiene equipo: foto `equipo_existente` y observaciones (las dos se piden en la App), `POST /:id/autorizacion`, y se consulta `GET /:id` cada 12 s hasta que `autorizacion` sea:
   - `autorizada`: se continúa con el alta (Next da de baja la instalación anterior al cerrar);
   - `rechazada`: la orden queda `no_cumplida` y se muestra.
5. Una vez pedida la autorización el vehículo ya no se puede cambiar.

### 3. Código de verificación (§8)

Solo mantenimientos de la agenda. `POST /:id/codigo` (el código no llega a la App: lo dicta el operador) y `POST /:id/codigo/validar { codigo }`.

- Incorrecto → se muestra el mensaje con los intentos que quedan.
- 409 al validar («se emitió otro código») → se limpia el campo para capturar el nuevo.
- 409 al pedir el sexto código → «Comunícate con operación para que reinicie los códigos» y ya no se ofrece pedir otro.

### 4. Instalación (§5)

El equipo y la SIM que entran salen de `GET /dispositivos/list?idCliente=` y `GET /sims/list?idCliente=` (almacén y reservado al cliente). Lo que no se puede instalar se marca «No disponible».

| Tipo | Se envía |
|---|---|
| Alta | `idDispositivoNuevo` y `idSimNuevo` (opcional) |
| Cambio de equipo | `idDispositivoNuevo` y `estatusSalienteAnterior` |
| Cambio de SIM | `idSimNuevo` y `estatusSalienteAnterior` |
| Desinstalación | `estatusInstalacionBaja`: 0 inactiva o 5 inservible |
| Revisión | Nada |

`estatusSalienteAnterior`: 3 por revisar, 4 laboratorio o 5 inservible (0 y 1 ya no se aceptan). En mantenimientos se muestra el equipo y la SIM actuales (`GET /instalaciones/:id`).

### 5. Checklist (§5)

Opciones sí/no de `vehiculo_cuenta_con`, `funcionamiento_vehiculo` y `fallas_equipo`; se envían **todas** porque el servidor las exige para cerrar. En el alta las fallas no se muestran y van en «no». Fotos del catálogo (`tablero_inicio`, `tablero_final` obligatorias; `falla_extra_1..3` opcionales, no en el alta). Las fotos ya subidas se ven desde el servidor y se pueden reemplazar.

### 6. Pruebas y firmas (§9)

- Pruebas del catálogo; `paro_motor` solo si `vehiculo_cuenta_con.inmovilizador` = sí.
- Órdenes de la agenda: «Solicitar prueba» (`POST /:id/pruebas/:clave/solicitar`, nota opcional). Se consulta `GET /:id` cada 12 s mientras haya una prueba `solicitada`. Si falla se puede volver a solicitar. Una `anulada` se ve en gris.
- Desinstalación y borradores sin origen (§14): el técnico contesta las pruebas en el `PATCH`.
- Monitorista (obligatorio), observaciones (obligatorias si `fallas_equipo.otro` = sí), firmas del catálogo. Las firmas guardadas se muestran y se pueden repetir.

### 7. Resumen y cierre (§10)

El resumen se recarga del servidor y muestra `faltantesParaCerrar` tal cual. «Registrar orden» solo se habilita con la lista vacía. Cada sección tiene «Editar» (el vehículo solo antes de pedir la autorización). `POST /:id/cerrar`; si responde 400 con `faltantes` se muestra la lista. Cerrar es seguro de reintentar.

### No se pudo realizar (§11)

Desde el menú de la orden. Motivos de `/motivos` con `no_cumplida` en `resultado` y `tecnico` en `quien`; si el motivo lo pide, observaciones. Si la orden no estaba iniciada se inicia primero. El técnico no cancela órdenes: eso lo hace operación.

### Errores (§13)

| HTTP | Qué hace la App |
|---|---|
| 400 | Muestra el mensaje |
| 401 | Renueva el token y reintenta |
| 403 | Muestra el mensaje, no reintenta |
| 404 | La orden ya no es del técnico: avisa y regresa a la agenda, que se recarga |
| 409 | Recarga la orden y muestra el mensaje |
| 5xx / red | Muestra el mensaje; iniciar, guardar, archivos y cerrar son seguros de repetir |

---

## Historial, detalle y PDF (§3, §12)

- Historial: `GET /ordenes-servicio/paginado/:page/:limit?estatus=cerrada` o `no_cumplida`, con búsqueda y filtro de fecha en el teléfono.
- Detalle: `GET /ordenes-servicio/:id`. Las URL de fotos y firmas duran 5 minutos; al deslizar hacia abajo se renuevan.
- **Ver PDF** (cualquier estado): `GET /:id/pdf`, se guarda en temporales y se abre con el visor del teléfono.
- **Compartir** (solo `cerrada` o `no_cumplida`):
  - WhatsApp: `POST /:id/compartir { telefono? }` y se abre el enlace `whatsapp` que devuelve (vigente 168 h).
  - Correo: `POST /:id/enviar-correo { correos: [...] }`, de 1 a 5.

---

## Qué guarda cada paso

| Momento | En el teléfono | En el servidor |
|---|---|---|
| Iniciar | `claveApp` de la orden | `iniciar` y `PATCH` con fecha y ubicación |
| Vehículo (alta) | Nada | Alta del vehículo si no existía, `PATCH idProducto`, autorización |
| Código | Nada | Código pedido y validado |
| Instalación | Nada | `PATCH` del equipo, SIM o estatus |
| Checklist | Fotos subidas en esta sesión (para no reenviarlas) | `PATCH respuestas` y archivos |
| Pruebas y firmas | Igual | Solicitudes de prueba, `PATCH` y firmas |
| Cerrar o no cumplida | Se borra la `claveApp` | Orden cerrada o no cumplida |

---

## Permisos y red

- Ubicación: al iniciar una orden y, si no se pudo, al guardar las pruebas.
- Cámara y galería: fotos del vehículo, del checklist, del equipo encontrado y firmas.
- Tiempo de espera: 30 segundos en JSON y 120 segundos al subir archivos.
- Las respuestas JSON se leen en la raíz o dentro de `data`, sin distinguir mayúsculas en las claves. Los errores en texto o en JSON se leen igual (`message`).
