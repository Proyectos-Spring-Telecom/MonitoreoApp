# Solicitud al Backend: error 500 al volver a solicitar una prueba

**Para:** Equipo de Backend
**De:** Equipo de App Móvil (MonitoreoApp)
**Fecha:** 10 de noviembre de 2026
**Servicio:** `POST /ordenes-servicio/:id/pruebas/:clave/solicitar`

---

## 1. Resumen

Cuando el operador marca una prueba como **fallida** y el técnico la vuelve a solicitar desde la app, el servidor responde **500 Internal server error**. El técnico no puede pedir una nueva validación de esa prueba.

La primera solicitud de la prueba funciona. El error aparece solo al **reintentar**.

## 2. Caso observado

| Dato | Valor |
|---|---|
| Orden (`id`) | `4` |
| Prueba (`clave`) | `boton_panico` (Botón de pánico) |
| Estatus de la prueba antes del reintento | `fallida` |
| Fecha | 10 de noviembre de 2026 |
| Ambiente | `https://springtelecom.mx/nextAPI/api` |

Registro de la app:

```
[API] POST /nextAPI/api/ordenes-servicio/4/pruebas/boton_panico/solicitar → 500
[API] Error 500: {"statusCode":500,"message":"Internal server error"}
```

## 3. Pasos para reproducir

1. Abrir una orden de la agenda en estatus `borrador`.
2. En «Pruebas y firmas», tocar **Solicitar prueba** en «Botón de pánico». El servidor responde bien y la prueba queda en `solicitada`.
3. Desde el portal, el operador marca la prueba como **fallida**.
4. En la app aparece el botón **Volver a solicitar**. Al tocarlo se envía de nuevo la misma petición.
5. El servidor responde **500**.

La app solo ofrece «Volver a solicitar» cuando el estatus de la prueba es `fallida`.

## 4. Petición que envía la app

```http
POST /nextAPI/api/ordenes-servicio/4/pruebas/boton_panico/solicitar
Authorization: Bearer <token del técnico>
Content-Type: application/json
```

Cuerpo:

- Si el técnico escribe una nota para el operador:

  ```json
  { "observaciones": "Presioné el botón de pánico a las 10:42" }
  ```

- Si no escribe nota, la petición se envía **sin cuerpo**.

Es la misma petición del primer intento; la app no manda ningún dato distinto en el reintento.

Ejemplo para reproducirlo:

```bash
curl -i -X POST \
  'https://springtelecom.mx/nextAPI/api/ordenes-servicio/4/pruebas/boton_panico/solicitar' \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{"observaciones":"reintento"}'
```

## 5. Comportamiento esperado

Según el contrato de la App de instaladores, una prueba fallida se puede volver a solicitar. Al reintentar esperamos:

1. Respuesta **200** o **201**, igual que en el primer intento.
2. En `GET /ordenes-servicio/:id`, la prueba regresa a `estatus: "solicitada"` con:
   - `fechaSolicitud` nueva.
   - `notaTecnico` con la nota nueva (o vacía si no se envió).
   - `fechaValidacion`, `nombreValido` y `notaOperador` en `null`, porque son de la validación anterior.
3. El operador vuelve a ver la prueba pendiente para validarla.

Mientras la prueba esté en `solicitada`, la app consulta `GET /ordenes-servicio/:id` cada 12 segundos para mostrar el resultado.

## 6. Posibles causas a revisar

No tenemos acceso al registro del servidor; estas son las causas más probables por lo que vemos desde la app:

- **Registro duplicado:** si el reintento inserta una fila nueva y existe una restricción única por orden y clave de prueba, la base de datos rechaza la inserción y el error no se controla.
- **Transición no contemplada:** que el servicio solo espere pasar de «sin solicitar» a `solicitada` y falle al partir de `fallida`.
- **Cuerpo vacío:** que el servicio falle cuando la petición llega sin `observaciones`.

## 7. Si el reintento no debe permitirse

Si por regla de negocio una prueba fallida no se puede volver a solicitar, pedimos responder con un error controlado en lugar de 500. Por ejemplo, **409** con un mensaje que podamos mostrarle al técnico:

```json
{ "statusCode": 409, "message": "La prueba ya fue validada y no se puede volver a solicitar." }
```

Con eso ocultamos el botón «Volver a solicitar» y mostramos el mensaje.

---

Quedamos atentos a sus comentarios y a una fecha estimada para la corrección.

¡Gracias!
