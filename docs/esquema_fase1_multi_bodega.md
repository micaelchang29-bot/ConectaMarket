# Fase 1 — Modelo de datos multi-bodega

Resuelve los dos blockers confirmados en
[diagnostico_infraestructura_nube.md](diagnostico_infraestructura_nube.md):
SQLite sin `bodega_id` y Firestore sin colecciones normalizadas consultables.

**Alcance de este documento:** cambios de esquema SQLite (código real, ya
aplicado en esta rama) + diseño de colecciones Firestore + `firestore.rules`
(archivo real, escrito, **no desplegado**). No se tocó `sync_service.dart`,
`csvimportservice.dart` ni ningún flujo de escritura a Firestore — eso es
Fase 2, después de revisar este diseño.

---

## 1. Cambios en SQLite

[database_helper.dart](../lib/repositories/database_helper.dart): versión
**5 → 6**. Columna `bodega_id TEXT` (nullable, sin default) agregada a:

| Tabla | ¿Lleva `bodega_id`? | Por qué |
|---|---|---|
| `products` | Sí | catálogo de cada bodega; hoy el `id` (SKU) es libre y colisiona entre bodegas |
| `providers` | Sí | mismo problema: un proveedor creado por una bodega no debe mezclarse con el de otra si se centraliza |
| `receipts` | Sí | cabecera de ventas y compras; `provider_id` puede ser NULL (ventas), así que necesita su propio dueño |
| `receipt_items` | **No** | se deriva siempre vía `JOIN receipts ON receipt_items.receipt_id = receipts.id`. Duplicar el campo acá no agrega información — nunca se consulta un ítem sin su recibo — y evita que quede desincronizado si algún día cambiara el dueño de un recibo. |

En [`_createDB`](../lib/repositories/database_helper.dart#L50-L104) (bases
nuevas) y en [`_onUpgrade`](../lib/repositories/database_helper.dart#L106-L125)
(bases existentes, rama `oldVersion < 6`), siguiendo exactamente el patrón ya
usado para `precio` en la migración 4→5.

Se agregó un test ([database_migration_test.dart](../test/database_migration_test.dart))
que abre una base v4 real y confirma: llega a versión 6, `providers`/`products`/`receipts`
tienen `bodega_id`, y `receipt_items` **no** lo tiene. Suite completa:
**31/31 verde** (`flutter test`).

### Por qué `bodega_id` es `TEXT` nullable sin valor por defecto

El valor semántico es el `uid` de Firebase Auth (`auth_service.dart`), pero
ese dato no existe en el momento de la migración — correr `ALTER TABLE` pasa
durante la apertura de la base, antes o independientemente de que haya una
sesión activa. Ponerle un default inventado sería peor que dejarlo en NULL.

### Cómo se estampa `bodega_id` en cada escritura nueva — implementado (Opción A)

`product_repository.dart` (`upsertProduct`), `provider_repository.dart`
(`upsertProvider`) y `receipt_repository.dart` (`saveFullReceipt`) ahora leen
`AuthService.instance.currentUid` antes de insertar. No se tocó
`csvimportservice.dart`: la importación CSV escribe a través de estos mismos
repositorios, así que queda cubierta gratis.

**Invariante aplicada en los tres:** `bodega_id` se estampa **solo en el
alta**, nunca se pisa en una edición. `REPLACE INTO` (el `ConflictAlgorithm.replace`
que ya usaba el código) reemplaza la fila completa — cualquier columna no
incluida en el mapa vuelve a su default. Sin cuidarlo, editar un producto
estando deslogueado habría borrado el `bodega_id` ya asignado. Por eso cada
repositorio consulta primero si la fila ya existe: si existe, conserva su
`bodega_id` tal cual estaba; si es nueva, recién ahí toma el uid de la sesión
activa (o `null` si no hay sesión, igual que hoy). Cubierto por
[bodega_id_stamping_test.dart](../test/bodega_id_stamping_test.dart) (6 casos:
alta sin sesión → NULL, edición con dueño ya asignado → se preserva, para
`products`, `providers` y `receipts`).

`receipt_items` sigue sin columna propia, como ya estaba decidido: se deriva
siempre vía `receipt_id → receipts.bodega_id`.

**`auth_service.dart`** recibió el único cambio fuera de los repositorios:
`FirebaseAuth.instance` pasó de capturarse en un campo (evaluado al construir
el singleton) a un getter (evaluado en cada uso), y se agregó
`currentUid` — una versión de `currentUser?.uid` que nunca lanza, aunque
Firebase no esté inicializado. Era necesario: los 37 tests de este repo no
llaman a `Firebase.initializeApp()`, y sin este cambio cualquier `upsert`
en un test habría reventado al intentar leer la sesión activa.

### Deliberadamente no implementado: backfill del historial existente

Estampar hacia adelante no llena `bodega_id` en las filas que ya existían
antes de este cambio en un dispositivo instalado — esas quedan en NULL hasta
que algo las etiquete retroactivamente con el uid de quien use ese
dispositivo. Es una decisión de diseño separada (dónde se dispara esa pasada,
si al detectar sesión en `main.dart` o en otro punto) que no fue parte de lo
aprobado en esta entrega — queda abierta para cuando se decida encarar.

---

## 2. Esquema de Firestore propuesto

```
bodegas/{bodegaId}/productos/{productoId}
bodegas/{bodegaId}/ventas/{ventaId}
bodegas/{bodegaId}/compras/{compraId}
bodegas/{bodegaId}/forecasts/{forecastId}
```

`{bodegaId}` es literalmente el `uid` de Firebase Auth — **no existe un
documento `bodegas/{bodegaId}` en sí mismo** (sin tabla de bodegas, tal como
pediste). Firestore permite perfectamente que un segmento de ruta sea solo
contenedor de subcolecciones sin tener un documento propio; nadie en el
código necesita leer/escribir ese nivel, así que no hace falta.

**Esto resuelve el blocker de colisión de SKU sin renombrar nada:** dos
bodegas pueden tener cada una `productos/P001` porque son documentos
distintos bajo padres distintos. El aislamiento lo da la ruta, no el ID.

### `productos/{productoId}` — espejo de `products`

| Campo | Tipo | Viene de | Nota |
|---|---|---|---|
| `nombre` | string | `products.nombre` | |
| `stock` | number | `products.stock` | snapshot al momento de sync |
| `umbral_alerta` | number | `products.umbralAlerta` | renombrado a snake_case, como ya usa `sync_service.dart` (`created_at`, `movements_count`) |
| `precio` | number | `products.precio` | |
| `actualizado_en` | timestamp | — | `serverTimestamp()` en cada sync |

**Doc ID = el SKU tal cual** (`products.id`). Como vive bajo
`bodegas/{bodegaId}/`, no colisiona entre bodegas y de paso hace que el
`set()` de sincronización sea naturalmente idempotente (reintentar un sync no
duplica).

### `ventas/{ventaId}` y `compras/{ventaId}` — **a nivel de ítem, no de recibo**

Decisión de diseño clave: en vez de un documento por `receipt` con los
`receipt_items` embebidos en un array (que es exactamente el patrón que hoy
revienta el límite de 1 MiB en `users/{uid}/backups`), **cada `receipt_item`
es su propio documento**. Esto es lo que hace que la colección sea
consultable por un training job: `where('fecha', >=, hace_7_dias)` funciona
directo, sin tener que desempacar arrays.

**Doc ID = `receipt_items.id`** (ya es un ID único generado localmente) — de
nuevo, para que el `set()` del sync sea idempotente.

| Campo | Tipo | Viene de | Nota |
|---|---|---|---|
| `producto_id` | string | `receipt_items.product_id` | el SKU; se resuelve contra `productos/{producto_id}` en la misma bodega |
| `cantidad` | number | `receipt_items.cantidad` | |
| `precio_unitario` (ventas) / `costo_unitario` (compras) | number | `receipt_items.costoUnitario` | **renombrado a propósito.** La columna local `costoUnitario` se reutiliza hoy para dos sentidos distintos (precio cobrado en una venta, costo pagado en una compra) según `tipomovimiento`. Separar las colecciones permite nombrar cada campo por lo que realmente es. |
| `subtotal` | number | `cantidad * precio_unitario` | precalculado: evita que cada lectura del training job tenga que recomputarlo |
| `fecha` | timestamp | `receipts.fecha` | se convierte de `'yyyy-MM-dd'` a `Timestamp` real en Fase 2, para que los rangos de fecha sean eficientes en Firestore |
| `receipt_id` | string | `receipt_items.receipt_id` | trazabilidad hacia el comprobante original |
| `serie` | string | `receipts.serie` | relevante para ventas (SUNAT); en compras suele ser el default, se mantiene por paridad |
| `proveedor_id` | string? | `receipts.provider_id` | **solo en `compras`**; nullable porque el dato local también puede serlo |
| `proveedor_nombre` | string? | `providers.nombre` | **solo en `compras`**, denormalizado a propósito: Firestore no tiene joins, y así el training job o el chatbot no necesitan una segunda lectura a `/proveedores` solo para mostrar un nombre. Si el proveedor se renombra después, los documentos viejos conservan el nombre de al momento de la compra — es el comportamiento correcto para un historial, no un bug. |

**No se duplica `bodega_id` como campo.** Ya es el segmento padre de la ruta.
Incluso para una consulta `collectionGroup('ventas')` que cruce todas las
bodegas (el caso de uso natural del training job semanal: "traeme las ventas
de los últimos 7 días de **todas** las bodegas en una sola consulta"), cada
resultado trae su `DocumentReference` completo — `doc.ref.parent.parent.id`
da el `bodegaId` sin leer ni duplicar nada.

### `forecasts/{forecastId}` — único output cloud-only, sin tabla local equivalente

No existe una tabla SQLite que mapear acá; es resultado generado en la nube.
Doc ID propuesto = `producto_id` (un forecast vigente por producto, se
sobrescribe en cada entrenamiento — igual semántica que hoy tiene el dashboard
local). Campos sugeridos, en paralelo a lo que ya calcula
`dashboard_service.dart` localmente (`getInventoryRiskClassification`,
`validateForecastAccuracy`):

| Campo | Tipo | Nota |
|---|---|---|
| `producto_id` | string | |
| `demanda_diaria_proyectada` | number | equivalente cloud de `avg_daily_qty` |
| `cobertura_dias` | number | equivalente de `rotation_days` |
| `nivel_riesgo` | string | `BAJO` / `MEDIO` / `ALTO` / `CRÍTICO`, mismas reglas ya validadas localmente |
| `cantidad_sugerida` | number | |
| `mape` | number? | métrica de error del modelo, si se quiere exponer confianza al chatbot |
| `modelo_version` | string | para que el chatbot pueda citar qué versión del modelo generó la respuesta |
| `generado_en` | timestamp | `serverTimestamp()` |

No diseñé un historial de forecasts pasados (`forecasts/{id}/historico/...`)
porque no fue pedido y agregaría una subcolección especulativa sin una
necesidad concreta todavía — queda anotado como extensión futura si hace
falta ver tendencia del modelo en el tiempo.

### Lo que decidí no hacer todavía

- **`firestore.indexes.json`**: una consulta tipo `collectionGroup('ventas')`
  con `where(fecha >=) + where(producto_id ==)` va a necesitar un índice
  compuesto, pero escribirlo ahora sería adivinar la forma exacta de la
  query del training job (que es Fase 2). Mejor esperar a esa query real.
- **Colección `proveedores`**: no la propusiste y no hay nada en Firestore
  hoy que la necesite; si en Fase 2 el chatbot necesita mostrar ranking de
  proveedores con datos de la nube, se agrega entonces con el mismo patrón.

---

## 3. `firestore.rules`

Archivo escrito en la raíz del repo: [firestore.rules](../firestore.rules).
**No desplegado** — nadie corrió `firebase deploy --only firestore:rules`.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /bodegas/{bodegaId}/productos/{productoId} {
      allow read, write: if request.auth != null && request.auth.uid == bodegaId;
    }

    match /bodegas/{bodegaId}/ventas/{ventaId} {
      allow read, write: if request.auth != null && request.auth.uid == bodegaId;
    }

    match /bodegas/{bodegaId}/compras/{compraId} {
      allow read, write: if request.auth != null && request.auth.uid == bodegaId;
    }

    match /bodegas/{bodegaId}/forecasts/{forecastId} {
      allow read: if request.auth != null && request.auth.uid == bodegaId;
      allow write: if false;
    }
  }
}
```

### Por qué son 4 bloques `match` y no uno solo recursivo

El patrón que ya usa `/users/{userId}/{document=**}` sería más corto de
replicar como `/bodegas/{bodegaId}/{document=**}`. **No lo hice así a
propósito:** las reglas de Firestore son aditivas (se evalúan con OR). Si
una regla amplia ya otorga `write: true` sobre todo el subárbol, ninguna
regla más específica puede "restarle" ese permiso para una subcolección en
particular. Con un único `{document=**}` sería imposible declarar que
`forecasts` es de solo lectura — la regla amplia seguiría ganando. Por eso
cada colección es su propio `match`, lo que además dejó un lugar natural para
la restricción de `forecasts`.

### `forecasts` es de solo lectura para el cliente — ajuste sobre lo pedido

Pediste "mismo patrón de ownership... solo el dueño autenticado lee/escribe
su bodega". Para `productos`, `ventas` y `compras` es exactamente eso. Para
`forecasts` me aparté a propósito: esos documentos los va a escribir
**solamente** la Cloud Function de entrenamiento vía Admin SDK, que **ignora
estas reglas por completo** (el Admin SDK nunca pasa por `firestore.rules`).
Dejar `write: true` para el cliente ahí no sumaría ninguna función real —
solo abriría la puerta a que un teléfono comprometido escriba una predicción
falsa. `allow write: if false` cierra esa puerta sin afectar en nada a la
Cloud Function.

---

## Resumen: qué se resolvió y qué sigue abierto

| Blocker original | Estado |
|---|---|
| SQLite sin `bodega_id` | ✅ Columna agregada a `products`/`providers`/`receipts`, migración probada |
| Firestore sin colecciones normalizadas | ✅ Diseñado: `productos`/`ventas`/`compras` a nivel de ítem, consultable por rango de fecha y por `collectionGroup` |
| Reglas para las colecciones nuevas | ✅ Escritas en `firestore.rules`, no desplegadas |
| Quién estampa `bodega_id` en cada escritura nueva | ✅ Opción A implementada: los 3 repositorios lo estampan en el alta y lo preservan en cada edición (37/37 tests) |
| Backfill del historial existente en cada dispositivo | ⬜ Abierto — deliberadamente no incluido en esta entrega |
| Sync real hacia las colecciones nuevas (`sync_service.dart`) | ⬜ Fase 2, fuera de este alcance a propósito |
| `firestore.indexes.json` | ⬜ Diferido hasta conocer la query real del training job |
