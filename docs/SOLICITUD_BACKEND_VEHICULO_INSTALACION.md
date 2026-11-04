# Solicitud al Backend: información de "Vehículo e instalación" en el detalle de la orden

**Para:** Equipo de Backend
**De:** Equipo de App Móvil (MonitoreoApp)
**Fecha:** 4 de noviembre de 2026
**Servicio:** `GET /ordenes-servicio/:id`

---

## 1. Objetivo

Mostrar correctamente la información de la sección **"Vehículo e instalación"** en el **detalle de la orden de servicio** de la app.

## 2. Situación actual

Actualmente el servicio solo regresa IDs, que no le dicen nada al técnico:

- `idInstalacion` o `idInstalacionProgramada`
- `idInstalacionResultado`
- `idDispositivoNuevo` e `idSimNuevo`

Además, **no llegan** las fotografías ni los documentos del vehículo.

## 3. Información que necesitamos

En lugar de los IDs, necesitamos recibir la **información descriptiva**, tal como ya se muestra en el PDF de la orden.

### 3.1 Instalación atendida (en lugar de `idInstalacion` o `idInstalacionProgramada`)

- Tipo de equipo
- Dispositivo: marca, modelo, IMEI y número de serie
- SIM: compañía, ICCID y teléfono

### 3.2 Instalación resultante (en lugar de `idInstalacionResultado`)

- Tipo de equipo
- Dispositivo: marca, modelo, IMEI y número de serie
- SIM: compañía, ICCID y teléfono

### 3.3 Dispositivo nuevo y SIM nueva (en lugar de `idDispositivoNuevo` e `idSimNuevo`)

- Dispositivo: tipo de equipo, marca, modelo, IMEI y número de serie
- SIM: compañía, ICCID y teléfono

### 3.4 Fotografías del vehículo

Las fotos registradas del vehículo (principal, frontal, trasera, lateral derecha, lateral izquierda y extra), con su URL para visualizarlas.

### 3.5 Documentos del vehículo

Los documentos registrados del vehículo (tarjeta de circulación, póliza de seguro y permiso de carga), con su URL para visualizarlos.

## 4. Ejemplo de cómo debe verse

Así se visualiza la información en el PDF, y así la necesitamos mostrar en la app:

> **Tipo de equipo:** AVL
> **Dispositivo:** Suntech ST210 - IMEI 3333 - Serie: 0000009
> **SIM:** Telcel - ICCID 000002 - Tel: 7775642667

## 5. Ejemplo de respuesta esperada

Es solo una referencia; si prefieren otros nombres de campos, nos adaptamos.

```json
{
  "instalacion": {
    "tipoEquipo": "AVL",
    "dispositivo": "Suntech ST210 - IMEI 3333 - Serie: 0000009",
    "sim": "Telcel - ICCID 000002 - Tel: 7775642667"
  },
  "instalacionResultado": {
    "tipoEquipo": "AVL",
    "dispositivo": "Suntech ST210 - IMEI 4444 - Serie: 0000010",
    "sim": "Telcel - ICCID 000003 - Tel: 7775640000"
  },
  "dispositivoNuevo": "AVL - Suntech ST210 - IMEI 4444 - Serie: 0000010",
  "simNuevo": "Telcel - ICCID 000003 - Tel: 7775640000",
  "fotosVehiculo": [
    { "nombre": "Principal", "url": "https://..." },
    { "nombre": "Frontal", "url": "https://..." }
  ],
  "documentosVehiculo": [
    { "nombre": "Tarjeta de circulación", "url": "https://..." },
    { "nombre": "Póliza de seguro", "url": "https://..." }
  ]
}
```

Si algún dato no aplica al tipo de servicio (por ejemplo, no hay dispositivo nuevo en una desinstalación), puede venir vacío o en `null`.

## 6. Ajustes en el diseño del PDF

En el PDF de la orden (`GET /ordenes-servicio/:id/pdf`) se verá lo siguiente:

- Agregar **iconos en cada apartado**.
- Usar **títulos de sección** con el estilo de la **última propuesta de diseño** realizada.

---

Quedamos atentos a sus comentarios y a una fecha estimada para este cambio.

¡Gracias!
