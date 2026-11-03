# Solicitud a backend — Edición de la instalación desde la orden de servicio

**Proyecto:** App móvil Monitoreo (Spring Telecom)
**Fecha:** 28 oct 2026
**Solicita:** Equipo de la app Flutter
**Servicios involucrados:** `POST /instalaciones/paginado` y `/ordenes-servicio` (NextAPI)

---

## 1. Contexto

En la app, cuando el tipo de servicio **no** es `instalacion` (revisión, cambio de SIM, cambio de equipo o desinstalación), el técnico pasa por la pantalla **"Edición de la instalación"**:

1. Elige el **cliente**.
2. Elige la **instalación vigente** del cliente que va a atender.
3. Si el servicio es un cambio, elige el **producto, dispositivo o SIM nuevos** y el **estatus en que queda cada recurso que sale**.

La orden se inicia con `POST /ordenes-servicio` (con `idInstalacion`), se va guardando con `PATCH /ordenes-servicio/:id` y al cerrar (`POST /ordenes-servicio/:id/cerrar`) el servidor aplica el movimiento con `InstalacionesService.update`.

Hoy hay dos limitaciones que impiden replicar en la app lo que ya hace el portal web en **Editar instalación**:

| # | Limitación actual | Efecto en la app |
|---|---|---|
| 1 | `POST /instalaciones/paginado` solo filtra por `idTipoProducto` | No se pueden listar las instalaciones del cliente seleccionado. La app tendría que descargar las instalaciones de **todos** los clientes y filtrarlas localmente |
| 2 | `PATCH /ordenes-servicio/:id` solo acepta **un** recurso nuevo (`idDispositivoNuevo` en `c_equipo` o `idSimNuevo` en `c_sim`) y **un** solo `estatusSalienteAnterior` | No se puede cambiar el **producto**, ni cambiar dispositivo y SIM en la misma orden, ni indicar el estatus de cada recurso que sale por separado |

---

## 2. Cambio 1 — Filtros en `POST /instalaciones/paginado`

Agregar filtros **opcionales** al cuerpo. Se combinan entre sí (AND). Sin ellos, el servicio responde igual que hoy (el portal web no se ve afectado).

| Campo | Tipo | Obligatorio | Uso |
|---|---|---|---|
| `page` | entero ≥ 1 | Sí | Ya existe |
| `limit` | entero 1–200 | Sí | Ya existe |
| `idTipoProducto` | 1–4 | No | Ya existe |
| `idCliente` | número | No | **Nuevo.** Solo instalaciones del cliente |
| `estatusInstalacion` | 0–5 | No | **Nuevo.** La app enviará `1` (Activa / vigente) |
| `idProducto` | número | No | **Nuevo.** Instalación de un producto concreto |

### Ejemplo de solicitud

```json
{ "page": 1, "limit": 200, "idCliente": 33, "estatusInstalacion": 1 }
```

### Respuesta esperada

La misma estructura de hoy:

```json
{
  "data": [ { "...fila plana de instalación..." } ],
  "paginated": { "total": 12, "page": 1, "limit": 200 }
}
```

Cada fila debe traer como mínimo:

| Dato | Campos |
|---|---|
| Instalación | `idInstalacion`, `estatusInstalacion`, `idCliente` |
| Producto | `idProducto`, `idTipoProducto`, placa / nombre del activo / lugar / nombre de la persona según el tipo |
| Dispositivo | `idDispositivo`, `imei` o `numeroSerie`, tipo de dispositivo |
| SIM | `idSim`, `telefono`, `simId` / `iccid` |

Con esto la app arma el dropdown, por ejemplo: `Placa: NAFJFBE248 · AVL 222 · Tel. 7773245676`.

### Permisos

El **rol 8 (Técnico)** debe poder consultar el paginado con estos filtros aunque no tenga los permisos de pantalla del portal (`73`–`76`). Si se prefiere, se puede limitar al técnico para que solo vea instalaciones en estatus `1`.

---

## 3. Cambio 2 — Reemplazo de producto, dispositivo y SIM en la orden

Replicar en la orden de servicio los campos de **Editar instalación** del portal (marcados en rojo en la imagen de referencia):

- **Estatus producto anterior** — junto a *Producto*
- **Estatus dispositivo anterior** — junto a *Dispositivo*
- **Estatus SIM anterior** — junto a *SIM*

Igual que en el portal, cada estatus **solo es obligatorio si ese recurso cambia** respecto a la instalación vigente.

### 3.1 Campos nuevos en `PATCH /ordenes-servicio/:id`

| Campo | Tipo | Descripción |
|---|---|---|
| `idProductoNuevo` | número \| `null` | **Nuevo.** Producto que reemplaza al de la instalación vigente |
| `estatusProductoAnterior` | 0, 1, 3, 4, 5 | **Nuevo.** Estatus en que queda el producto que sale |
| `idDispositivoNuevo` | número \| `null` | Ya existe. Se pide que también aplique combinado con los otros cambios |
| `estatusDispositivoAnterior` | 0, 1, 3, 4, 5 | **Nuevo.** Estatus en que queda el dispositivo que sale |
| `idSimNuevo` | número \| `null` | Ya existe. Ídem |
| `estatusSimAnterior` | 0, 1, 3, 4, 5 | **Nuevo.** Estatus en que queda la SIM que sale |
| `estatusInstalacionAnterior` | 3, 4, 5 | **Nuevo, opcional.** Estatus con que se archiva la instalación vigente. Si no se envía, se mantiene el comportamiento actual (`3` Baja por reemplazo) |

Estatus permitidos para el recurso que sale (mismo catálogo del portal; **Asignado (2) no se permite**):

| ID | Texto en la app |
|---|---|
| 0 | Inactivo |
| 1 | Disponible |
| 3 | Baja por reemplazo |
| 4 | Baja por mantenimiento |
| 5 | Fuera de servicio |

`null` en un campo lo borra (como hoy). Las `respuestas` y demás campos de la orden no cambian.

### 3.2 Tipos de servicio donde aplica

| Tipo | Cambios permitidos | Requisito mínimo para cerrar |
|---|---|---|
| `c_equipo` | Producto, dispositivo y SIM (cualquier combinación) | `idDispositivoNuevo` + `estatusDispositivoAnterior` |
| `c_sim` | Producto, dispositivo y SIM (cualquier combinación) | `idSimNuevo` + `estatusSimAnterior` |
| `revision` | Ninguno (sin cambio, como hoy) | `idInstalacion` |
| `desinstalacion` | Ninguno (baja, como hoy) | `idInstalacion` + `estatusInstalacionBaja` |
| `instalacion` | No aplica (alta) | Sin cambios respecto al contrato actual |

Si se manda un campo que no aplica al tipo, responder 400 como hoy: `"<campo> no aplica a una orden de tipo <tipo>"`.

> **Pregunta para backend:** ¿se prefiere este esquema (los cambios combinados viven en `c_equipo` y `c_sim`) o un tipo nuevo, por ejemplo `edicion`, que permita cualquier combinación sin un recurso obligatorio? La app se adapta a cualquiera de los dos.

### 3.3 Validaciones esperadas (al guardar y al cerrar)

1. Cada recurso **nuevo** debe existir, ser del **mismo cliente** de la orden y estar **Disponible (1)**.
2. El producto nuevo debe ser del **mismo `idTipoProducto`** que el de la instalación vigente (en el portal el tipo está bloqueado al editar).
3. Si llega `idProductoNuevo`, `idDispositivoNuevo` o `idSimNuevo`, su `estatus…Anterior` es **obligatorio** al cerrar; si falta, agregarlo a `faltantesParaCerrar` (ej. `"Indica el estatus del dispositivo que sale"`).
4. Si el recurso "nuevo" es igual al de la instalación vigente, se trata como **sin cambio** (no se exige estatus).
5. La instalación debe seguir vigente al cerrar (regla actual).

### 3.4 Movimiento al cerrar

Al cerrar, llamar a `InstalacionesService.update` con el mismo payload que usa el portal:

| Campo de la orden | Campo en `PATCH /instalaciones/{id}` |
|---|---|
| `estatusInstalacionAnterior` (o `3` por defecto) | `estatusInstalacionAnterior` |
| `idProductoNuevo` + `estatusProductoAnterior` | `idProducto` + `estatusProductoAnterior` |
| `idDispositivoNuevo` + `estatusDispositivoAnterior` | `idDispositivo` + `estatusDispositivoAnterior` |
| `idSimNuevo` + `estatusSimAnterior` | `idSim` + `estatusSimAnterior` |
| `Orden de servicio OS-…(<tipo>): <observaciones>` | `comentario` (regla actual) |

Solo se envían los recursos que cambiaron.

### 3.5 Ejemplo

Cambio de equipo donde además se reemplaza la SIM; el producto no cambia:

```json
PATCH /ordenes-servicio/42
{
  "idDispositivoNuevo": 99,
  "estatusDispositivoAnterior": 3,
  "idSimNuevo": 20,
  "estatusSimAnterior": 1
}
```

Movimiento resultante al cerrar:

```json
PATCH /instalaciones/340
{
  "estatusInstalacionAnterior": 3,
  "comentario": "Orden de servicio OS-000042 (c_equipo): Cable sulfatado",
  "idDispositivo": 99,
  "estatusDispositivoAnterior": 3,
  "idSim": 20,
  "estatusSimAnterior": 1
}
```

### 3.6 Respuestas de consulta

`GET /ordenes-servicio/:id` y `GET /ordenes-servicio/paginado/:page/:limit` deben incluir los campos nuevos (`idProductoNuevo`, `estatusProductoAnterior`, `estatusDispositivoAnterior`, `estatusSimAnterior`, `estatusInstalacionAnterior`) para mostrarlos en el detalle de la orden.

### 3.7 Compatibilidad

- `estatusSalienteAnterior` puede mantenerse como alias temporal: en `c_equipo` equivale a `estatusDispositivoAnterior` y en `c_sim` a `estatusSimAnterior`. La app dejará de enviarlo cuando los campos nuevos estén disponibles.
- No cambia ningún contrato de `/instalaciones`.

---

## 4. Geocercas

Todo `PATCH /instalaciones/{id}` borra las geocercas de la instalación. El portal avisa antes de guardar consultando `GET /geocercas/list?idCliente=` y filtrando por `idInstalacion`.

> **Pregunta para backend:** ¿el rol 8 tiene acceso a `GET /geocercas/list`? Si no, ¿pueden incluir `totalGeocercas` en la fila de `/instalaciones/paginado` o en `GET /ordenes-servicio/:id`? La app mostrará el aviso antes de cerrar la orden.

---

## 5. Resumen de lo solicitado

- [ ] `POST /instalaciones/paginado`: filtros opcionales `idCliente`, `estatusInstalacion` e `idProducto`, accesibles para el rol 8.
- [ ] `PATCH /ordenes-servicio/:id`: campos `idProductoNuevo`, `estatusProductoAnterior`, `estatusDispositivoAnterior`, `estatusSimAnterior` y (opcional) `estatusInstalacionAnterior`; cambios combinados en `c_equipo` y `c_sim`.
- [ ] Validaciones y `faltantesParaCerrar` de la sección 3.3.
- [ ] Cierre que aplica el movimiento con `InstalacionesService.update` según la sección 3.4.
- [ ] Campos nuevos en el detalle y el listado de órdenes.
- [ ] Respuesta sobre geocercas (sección 4) y sobre el esquema de tipos (sección 3.2).

## 6. Qué hará la app cuando esté disponible

1. En "Edición de la instalación", el dropdown mostrará las **instalaciones vigentes del cliente** seleccionado (producto, dispositivo y SIM en una sola línea).
2. Al elegir la instalación se cargan su producto, dispositivo y SIM actuales.
3. Junto a **Producto**, **Dispositivo** y **SIM** aparecerá su **"Estatus … anterior"**, habilitado solo cuando el técnico elige un recurso distinto al actual.
4. Se guarda en la orden con `PATCH /ordenes-servicio/:id` y el servidor aplica el movimiento al cerrar.
