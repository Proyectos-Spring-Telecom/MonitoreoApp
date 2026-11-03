# Atributos de las interfaces "Tipo de servicio" y "Pruebas generadas"

Atributos que captura cada pantalla de la orden de servicio, tal como están implementados en la app.

| Momento | Pantalla | Archivo |
|---|---|---|
| Antes de la instalación | Tipo de servicio | `lib/presentation/service_order/service_details_page.dart` |
| Después de la instalación | Pruebas generadas | `lib/presentation/service_order/service_review_page.dart` |

Flujo: Datos del vehículo → **Tipo de servicio** → Instalación → **Pruebas generadas** → Resumen.

> "Obligatorio" se refiere a la validación de la app, que se activa con `AppConstants.enforceServiceOrderValidation = true` (hoy está en `false`).

---

## 1. Tipo de servicio (antes de la instalación)

Mensaje de la pantalla: *"Indique el tipo de servicio y el estado actual del vehículo y del equipo."*

Se guarda en `ServiceDetailsData` (`lib/presentation/service_order/service_order_draft.dart`).

### 1.1 Tipo de servicio

| Propiedad | Valor |
|---|---|
| Control | Chips de selección múltiple |
| Texto de ayuda | "Selecciona uno o más tipos de servicio." |
| Tipo de dato | Lista de opciones |
| Obligatorio | Sí, al menos 1 |
| Valor por defecto | Instalación |
| Campo en la app | `serviceTypes` |

| Id | Opción |
|---|---|
| `instalacion` | Instalación |
| `revision` | Revisión |
| `c_sim` | C/SIM (cambio de SIM) |
| `c_equipo` | C/Equipo (cambio de equipo) |
| `desinstalacion` | Desinstalación |

### 1.2 Vehículo cuenta con

| Propiedad | Valor |
|---|---|
| Control | Interruptores (sí/no por opción) |
| Texto de ayuda | "Activa los accesorios con los que cuenta el vehículo." |
| Tipo de dato | Lista de opciones activadas |
| Obligatorio | Sí, al menos 1 |
| Valor por defecto | Ninguna activada |
| Campo en la app | `vehicleFeatures` |

| Id | Opción |
|---|---|
| `boton_panico` | Botón de pánico |
| `inmovilizador` | Inmovilizador |
| `regulador` | Regulador |
| `estereo` | Estéreo |
| `alarma` | Alarma |

### 1.3 Funcionamiento del vehículo

| Propiedad | Valor |
|---|---|
| Control | Interruptores (sí/no por opción) |
| Texto de ayuda | "Activa las revisiones que resultaron correctas." |
| Significado | Activado = correcto; apagado = no correcto |
| Tipo de dato | Lista de opciones activadas |
| Obligatorio | Sí, al menos 1 |
| Valor por defecto | Ninguna activada |
| Campo en la app | `vehicleOperation` |

| Id | Opción |
|---|---|
| `tablero_iniciar` | Tablero correcto al iniciar |
| `tablero_final` | Tablero correcto al final |
| `unidad_iniciar` | Unidad correcta al iniciar |
| `unidad_final` | Unidad correcta al final |

#### Fotografías del tablero

| Id | Etiqueta | Obligatoria |
|---|---|---|
| `tablero_inicio` | Tablero al iniciar | Sí |
| `tablero_final` | Tablero al finalizar | Sí |

Campo en la app: `dashboardPhotos`.

### 1.4 Fallas encontradas del equipo

| Propiedad | Valor |
|---|---|
| Control | Interruptores (sí/no por opción) |
| Texto de ayuda | "Activa las fallas que presenta el equipo." |
| Tipo de dato | Lista de opciones activadas |
| Obligatorio | Sí, al menos 1 |
| Valor por defecto | Ninguna activada |
| Campo en la app | `equipmentFailures` |

| Id | Opción |
|---|---|
| `mojado` | Mojado |
| `golpeado` | Golpeado |
| `cables_cortados` | Cables cortados |
| `cables_desconectados` | Cables desconectados |
| `otro` | Otro (Especificar en observaciones) |

La descripción de **Otro** se escribe en *Observaciones*, en la pantalla Pruebas generadas (sección 2.3).

#### Imágenes extras (opcional)

| Id | Etiqueta | Obligatoria |
|---|---|---|
| `falla_extra_1` | Imagen extra 1 | No |
| `falla_extra_2` | Imagen extra 2 | No |
| `falla_extra_3` | Imagen extra 3 | No |

Campo en la app: `failurePhotos`.

### 1.5 Resumen de atributos

| Atributo | Tipo | Opciones | Obligatorio |
|---|---|---|---|
| Tipo de servicio | Lista | 5 | Sí (mín. 1) |
| Vehículo cuenta con | Lista | 5 | Sí (mín. 1) |
| Funcionamiento del vehículo | Lista | 4 | Sí (mín. 1) |
| Fallas encontradas del equipo | Lista | 5 | Sí (mín. 1) |
| Fotografías del tablero | Imágenes | 2 | Sí (las 2) |
| Imágenes extras de fallas | Imágenes | 3 | No |

---

## 2. Pruebas generadas (después de la instalación)

Mensaje de la pantalla: *"Registre el resultado de las pruebas, la información adicional y las firmas."*

Se guarda en `TestsData` (`lib/presentation/service_order/service_order_draft.dart`).

### 2.1 Datos del registro

Solo lectura; la app los llena automáticamente.

| Atributo | Tipo de dato | Origen | Ejemplo | Campo en la app |
|---|---|---|---|---|
| Folio | Texto | Fijo en la app (`0001`) | `0001` | `folio` |
| Fecha y hora | Fecha y hora | Reloj del dispositivo al abrir la pantalla | `mar 27 de oct 2026, 20:50` | `fechaHora` |
| Lugar | Texto (latitud, longitud) | GPS del dispositivo, alta precisión | `18.9242, -99.2216` | `lugar` |

- Si se niega el permiso de ubicación, *Lugar* muestra "Ubicación no disponible".
- Hoy la fecha y el lugar se guardan solo como texto para mostrar.

### 2.2 Pruebas generadas

| Propiedad | Valor |
|---|---|
| Control | Interruptores (sí/no por prueba) |
| Texto de ayuda | "Activa las pruebas que resultaron correctas." |
| Significado | Activado = correcta; apagado = no correcta / no realizada |
| Tipo de dato | Lista de pruebas, cada una con su resultado (`label`, `passed`) |
| Obligatorio | Sí, al menos 1 correcta |
| Valor por defecto | Transmisión correcta activada |
| Campo en la app | `tests` (lista de `TestResult`) |

| Id | Prueba |
|---|---|
| `transmision` | Transmisión correcta |
| `boton_panico` | Botón de pánico |
| `paro_motor` | Paro de motor y movilización |

A diferencia de la pantalla anterior, aquí se guardan **las 3 pruebas** con su resultado (verdadero o falso), no solo las activadas.

### 2.3 Información adicional

| Atributo | Control | Tipo de dato | Obligatorio | Valor por defecto | Campo en la app |
|---|---|---|---|---|---|
| Monitorista | Lista desplegable | Texto (nombre) | Sí | Ninguno | `monitorista` |
| Técnico | Solo lectura (usuario en sesión) | Nombre y correo | Sí (debe haber sesión) | Usuario en sesión | `tecnicoNombre`, `tecnicoEmail` |
| Observaciones | Texto libre, de 3 a 6 líneas | Texto | No | Vacío | `observaciones` |

Opciones de **Monitorista** (lista fija en `service_order_catalogs.dart`):

- Ana López
- Carlos Méndez
- Daniela Ruiz
- Jorge Hernández

**Técnico:** se toma del usuario en sesión (`GET /login/me`); el usuario no puede cambiarlo. El id del usuario está disponible en la sesión, aunque hoy solo se guardan el nombre y el correo.

**Observaciones:** texto de ayuda "Agrega observaciones de la instalación (opcional)". Es donde se describe la falla **Otro** de la pantalla anterior.

### 2.4 Firmas

| Atributo | Control | Formato | Obligatorio | Campo en la app |
|---|---|---|---|---|
| Firma del cliente | Lienzo de firma (alto 180 px), con botón "Limpiar" | Imagen PNG | Sí | `firmaCliente` |
| Firma del técnico | Lienzo de firma (alto 180 px), con botón "Limpiar" | Imagen PNG | Sí | `firmaTecnico` |

En pantalla el trazo es blanco sobre fondo oscuro, pero el PNG se exporta con **trazo negro sobre fondo blanco**. Si no hay firma, el valor es nulo.

### 2.5 Resumen de atributos

| Atributo | Tipo | Obligatorio |
|---|---|---|
| Folio | Texto | Automático |
| Fecha y hora | Fecha y hora | Automático |
| Lugar | Coordenadas | Automático (puede no estar disponible) |
| Transmisión correcta | Sí/No | Al menos 1 de las 3 pruebas en Sí |
| Botón de pánico | Sí/No | Al menos 1 de las 3 pruebas en Sí |
| Paro de motor y movilización | Sí/No | Al menos 1 de las 3 pruebas en Sí |
| Monitorista | Texto (de lista) | Sí |
| Técnico | Nombre y correo | Sí |
| Observaciones | Texto | No |
| Firma del cliente | Imagen PNG | Sí |
| Firma del técnico | Imagen PNG | Sí |

---

## 3. Imágenes

Datos comunes a todas las fotografías de ambas pantallas (`lib/presentation/service_order/widgets/service_order_photos.dart`).

| Propiedad | Valor |
|---|---|
| Origen | Cámara o galería |
| Acciones | Tomar foto, elegir de la galería, volver a tomar, eliminar |
| Compresión | Calidad 70 %, ancho máximo 1600 px |
| Formato | JPG desde la cámara; desde la galería, el formato original (JPG, PNG o WEBP) |
| Datos de cada foto | `id`, `label` (etiqueta) y `bytes` (clase `DraftPhoto`) |

Total por orden en estas dos pantallas: **5 fotografías** (2 obligatorias y 3 opcionales) y **2 firmas** (obligatorias).
