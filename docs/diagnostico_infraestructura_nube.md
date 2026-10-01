# Diagnóstico de infraestructura — ConectaMarket

Consolidado para la arquitectura en la nube propuesta: CSV semanal de bodegas →
forecasting entrenado en la nube → chatbot que responde en lenguaje simple.

**Método:** secciones 1-4 y 6 vienen de lectura directa del código fuente
(rama `claude/exciting-brahmagupta-gv1me9`). La sección 5 combina esa lectura
con consultas en vivo al proyecto real de Firebase/GCP, ejecutadas con
`firebase` CLI (ya autenticado como `micaelchang29@gmail.com`) y, a partir de
este documento, con `gcloud` CLI recién instalado y autenticado con la misma
cuenta. Donde un dato de la auditoría anterior era una inferencia y ahora está
confirmado (o corregido) con una consulta real, se marca explícitamente.

No se modificó ni se creó ningún recurso en la nube para este diagnóstico: en
los dos prompts de `gcloud` que ofrecían habilitar una API (`functions.list`,
`run.services.list`) se respondió que no.

---

## 1. Almacenamiento local (SQLite)

Esquema completo en [database_helper.dart](../lib/repositories/database_helper.dart), base `conecta_market.db`, **versión 5**.

**`providers`** ([líneas 53-57](../lib/repositories/database_helper.dart#L53-L57))

| Columna | Tipo |
|---|---|
| `id` | TEXT PRIMARY KEY |
| `nombre` | TEXT NOT NULL |
| `ruc` | TEXT |
| `telefono` | TEXT |

**`products`** ([líneas 63-68](../lib/repositories/database_helper.dart#L63-L68))

| Columna | Tipo |
|---|---|
| `id` | TEXT PRIMARY KEY (SKU escrito a mano por el usuario, ej. `P001`) |
| `nombre` | TEXT NOT NULL |
| `stock` | REAL DEFAULT 0 |
| `umbralAlerta` | INTEGER DEFAULT 5 |
| `precio` | REAL DEFAULT 0 (precio de venta, agregado en v5) |

**`receipts`** — cabecera de **ventas y compras en la misma tabla** ([líneas 74-82](../lib/repositories/database_helper.dart#L74-L82))

| Columna | Tipo | Nota |
|---|---|---|
| `id` | TEXT PRIMARY KEY | generado en el cliente |
| `provider_id` | TEXT NULL | NULL en ventas |
| `fecha` | TEXT | ISO `yyyy-MM-dd`, sin hora |
| `total` | REAL | |
| `tipomovimiento` | INTEGER DEFAULT 0 | **0 = venta, 1 = compra** |
| `synced` | INTEGER DEFAULT 0 | flag de backup |
| `serie` | TEXT DEFAULT 'B001' | serie SUNAT |

**`receipt_items`** ([líneas 88-95](../lib/repositories/database_helper.dart#L88-L95))

| Columna | Tipo |
|---|---|
| `id` | TEXT PRIMARY KEY |
| `receipt_id` | TEXT |
| `product_id` | TEXT |
| `cantidad` | REAL |
| `costoUnitario` | REAL |

**Relaciones declaradas:** `receipts.provider_id → providers.id`;
`receipt_items.receipt_id → receipts.id ON DELETE CASCADE`;
`receipt_items.product_id → products.id`.

⚠️ Las FK están declaradas pero **no se aplican**: `PRAGMA foreign_keys` nunca
se ejecuta, así que en SQLite quedan apagadas por defecto. El comentario de
`ON DELETE CASCADE` en [receipt_repository.dart:96](../lib/repositories/receipt_repository.dart#L96)
es engañoso.

### Campo que identifique la bodega: **no existe**

Ninguna de las 4 tablas tiene columna de pertenencia (`bodega_id`, `tenant_id`,
`uid`, etc.). El único tenant en todo el proyecto es `user.uid`, usado solo
como segmento de ruta en Firestore, nunca como dato en SQLite. Implicancia
directa para la nube: los `product_id` son SKU libres y van a colisionar entre
bodegas (`P001` de una bodega ≠ `P001` de otra) en cuanto se centralicen.

---

## 2. Estado de Firestore

### Confirmado por consulta en vivo (`gcloud firestore databases describe`)

| Campo | Valor |
|---|---|
| Base de datos | `(default)` |
| Edición | STANDARD, `FIRESTORE_NATIVE` |
| **Región real** | **`southamerica-west1`** (Santiago de Chile) |
| Creada | 2026-05-24 |
| `freeTier` | **true** (confirma nivel gratuito de Firestore, consistente con Spark) |
| Protección contra borrado | **deshabilitada** |
| Point-in-time recovery | **deshabilitado** |

La región ya está fijada y **no se puede cambiar sin recrear la base**. Está
razonablemente cerca de Perú; no es ideal pero no amerita migración solo por
latencia.

### Único código que lee/escribe Firestore

Todo vive en [sync_service.dart](../lib/services/sync_service.dart), ruta
`users/{uid}/backups/{autoId}`.

**Escritura** ([líneas 71-81](../lib/services/sync_service.dart#L71-L81)): documento único por backup con
`inventory_snapshot` (array con TODAS las filas de `products`) y `movements`
(array con TODOS los recibos del periodo, ítems embebidos).

**Lectura** ([líneas 103-109](../lib/services/sync_service.dart#L103-L109)): el backup más reciente,
reemplaza toda la base local.

⚠️ Documento único con dataset completo embebido contra el límite de **1 MiB
por documento** de Firestore. No hay colección de ventas consultable por un
modelo — hoy Firestore es un blob de respaldo, no una base de datos operable.

### Reglas de seguridad — **confirmado por API, corrige la auditoría anterior**

La vez pasada no pude leer `firestore.rules` (no está en el repo, sin
`.firebaserc`) y asumí "probablemente modo test o bloqueado". Con `gcloud auth
print-access-token` + la API REST `firebaserules.googleapis.com` se obtuvo el
contenido real de la ruleset activa (`projects/.../rulesets/765c873c-...`,
desplegada el 2026-05-24):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Corrección:** no está en modo test abierto. Es una regla razonable: solo el
dueño autenticado puede leer/escribir su propio subárbol `users/{uid}/**`.
Coincide exactamente con lo que usa `sync_service.dart` hoy.

**Lo que sí falta:** la regla solo cubre `/users/**`. Cualquier colección
nueva que se cree para la arquitectura en la nube (`sales`, `bodegas`,
`forecasts`, `training_jobs`) **queda denegada por defecto** hasta que se
agregue una regla explícita — Firestore deniega lo no matcheado. Es trabajo
pendiente, no una vulnerabilidad actual.

---

## 3. Flujo de CSV / importación

Sin cambios respecto a la lectura de código; se mantiene lo auditado:

- El CSV va **solo a SQLite**, nunca a Firestore. [csvimportservice.dart](../lib/services/csvimportservice.dart)
  no importa `cloud_firestore` en ningún punto.
- Tres formatos por pestaña en la UI — **productos** (`id, nombre, stock,
  umbralAlerta, precio`, la 5ª opcional), **comprobantes** (`comprobante,
  proveedor, fecha, total, tipomovimiento, producto_id, cantidad,
  costoUnitario, serie`, mínimo 8 columnas) y **proveedores** (`id, nombre,
  ruc, telefono`, mínimo 2).
- ⚠️ La importación de proveedores llama directo al repositorio
  ([líneas 34-51](../lib/services/csvimportservice.dart#L34-L51)), saltándose
  la validación de RUC del servicio.
- `file_picker` solo filtra `.csv` local ([csvimportscreen.dart:24-27](../lib/screens/csvimportscreen.dart#L24-L27)); no sube nada.
- `excel` + `share_plus` son para el Registro de Ventas SUNAT
  ([sunat_service.dart](../lib/services/sunat_service.dart)), sin relación con
  el pipeline de forecasting. No existe ninguna exportación a CSV.

### Nuevo hallazgo relevante para el pipeline: no hay dónde subir el CSV en la nube

`gcloud storage buckets list --project=device-streaming-3b2e9e07` devolvió
**0 buckets**. El bucket que figura en [firebase_options.dart:60](../lib/firebase_options.dart#L60)
(`device-streaming-3b2e9e07.firebasestorage.app`) **no existe de verdad**:

```
gcloud storage buckets describe gs://device-streaming-3b2e9e07.firebasestorage.app
ERROR: ... not found: 404.
```

Cloud Storage for Firebase nunca se activó. El nombre quedó reservado en la
config de FlutterFire pero no hay bucket real detrás. Antes de diseñar "las
bodegas suben un CSV a Storage", ese bucket hay que crearlo.

---

## 4. Identidad y autenticación

[auth_service.dart](../lib/services/auth_service.dart): solo email/password
(`register`, `login`, `logout`, `currentUser`, `userStream`).

### Confirmado por API (`identitytoolkit.googleapis.com/admin/v2/.../config`)

| Proveedor de login | Estado |
|---|---|
| Email/password | **habilitado**, contraseña requerida |
| Google, teléfono, anónimo, etc. | no configurados |
| MFA | **DISABLED** |
| Dominios autorizados | solo los dominios por defecto de Firebase (`localhost`, `*.firebaseapp.com`, `*.web.app`) — sin dominio propio |

Es una cuenta por bodega **por omisión de diseño**, no por control: cualquiera
se registra libremente desde [login_dialog.dart](../lib/widgets_global/login_dialog.dart),
sin roles ni perfil de negocio.

### Vínculo usuario ↔ datos: solo en la ruta de Firestore

`user.uid` aparece únicamente como segmento de path
([sync_service.dart:73](../lib/services/sync_service.dart#L73) y
[:105](../lib/services/sync_service.dart#L105)). Ninguna fila de SQLite sabe
de qué usuario es. Sigue siendo el segundo blocker de diseño: hace falta un
`bodega_id` real, desacoplado del `uid` de Firebase Auth.

---

## 5. Configuración de Firebase / GCP

### [firebase.json](../firebase.json) — sin cambios, solo config de FlutterFire

```json
{"flutter":{"platforms":{"android":{"default":{"projectId":"device-streaming-3b2e9e07",
"appId":"1:506258400957:android:145cf5d00fc4573556b9d4","fileOutput":"android/app/google-services.json"}},
"dart":{"lib/firebase_options.dart":{"projectId":"device-streaming-3b2e9e07",
"configurations":{"android":"1:506258400957:android:145cf5d00fc4573556b9d4"}}}}}}
```

No hay `.firebaserc`, `firestore.rules`, `firestore.indexes.json` ni
`storage.rules` en el repo: lo que está activo en la nube se configuró a mano
desde la consola, nunca desde este repositorio.

### Proyecto — ahora con datos confirmados por `gcloud projects describe`

| Dato | Valor |
|---|---|
| Project ID | `device-streaming-3b2e9e07` |
| Project Number | `506258400957` |
| **Creado** | **2026-03-28** |
| Estado | `ACTIVE` |
| Labels | `firebase: enabled`, `firebase-core: disabled` |
| Apps | 1 sola, `conectamarket (android)` |

El nombre autogenerado (`device-streaming-*`) y el label `firebase-core:
disabled` confirman que el proyecto nació de un flujo automático (tipo
Firebase Studio / device streaming), no de una creación intencional desde la
consola — como ya se sospechaba en la auditoría anterior.

### Plan: **Spark, confirmado sin ambigüedad**

Antes esto era una inferencia indirecta (fallo de `functions:list`). Ahora es
un hecho verificado con `gcloud billing projects describe`:

```
billingAccountName: ''
billingEnabled: false
```

**No hay ninguna cuenta de facturación vinculada.** Pasar a Blaze exige que
vos (como dueño) la vincules desde la consola con una tarjeta — ningún CLI
evita ese paso manual.

### APIs habilitadas vs. las que hacen falta

`gcloud services list --enabled` devolvió 40 APIs. Lo relevante:

**Ya habilitadas** (en su mayoría activadas automáticamente al crear el
proyecto de Firebase, no por uso real): Firestore, Firebase Rules, Identity
Toolkit, FCM, Firebase Hosting/Remote Config/Extensions/Installations,
BigQuery (las 7 variantes del API, sin uso real detectado en el código),
Pub/Sub, Cloud SQL (componente), Cloud Storage (API, sin bucket creado — ver
§3), Cloud Logging/Monitoring/Trace.

**NO habilitadas — confirmado al intentar usarlas:**
```
gcloud functions list   → "Cloud Functions API has not been used ... or it is disabled"
gcloud run services list → "Cloud Run Admin API has not been used ... or it is disabled"
```
Esto es consistente con Spark y con que nunca se desplegó nada de backend.
Son las dos APIs que vas a necesitar habilitar (y eso sí requiere Blaze) para
el job de entrenamiento.

### Identidad y accesos (`gcloud iam service-accounts list` / `get-iam-policy`)

| Cuenta | Rol | Origen |
|---|---|---|
| `micaelchang29@gmail.com` | `roles/owner` | humano, única persona con acceso |
| `firebase-adminsdk-fbsvc@...iam.gserviceaccount.com` | `firebase.sdkAdminServiceAgent`, `firebaseauth.admin`, `iam.serviceAccountTokenCreator` | Admin SDK, creada automáticamente por Firebase |
| `...@cloudservices.gserviceaccount.com`, `...@gcp-sa-firebase...`, `...@gcp-sa-firestore...` | roles de sistema | agentes internos de Google, no gestionables |

**No hay ninguna service account propia creada todavía.** Cuando se diseñe el
job de entrenamiento o la Cloud Function que procese el CSV, va a necesitar
una cuenta de servicio nueva con permisos acotados (lectura de Storage,
lectura/escritura de la colección de resultados) — hoy no existe ninguna.

### Región de Firestore

Ya cubierta en §2: `southamerica-west1`, fijada al crear la base.

### `firebase login` y `gcloud auth login`

Ambos CLI autenticados con la misma cuenta, `micaelchang29@gmail.com`,
confirmado con `firebase login:list` y `gcloud auth list`.

### 🔴 Hallazgo de seguridad (sin cambios, sigue vigente)

`.vscode/launch.json` tiene dos API keys reales en texto plano (Groq, Gemini).
Está en `.gitignore`, no se filtró al repo, pero: (1) rotarlas si el entorno
no es exclusivamente tuyo, y (2) de fondo, `String.fromEnvironment` +
`--dart-define` las **compila dentro del APK** — cualquiera que lo
descompile las extrae. En la arquitectura nueva la llamada al LLM tiene que
salir del servidor, no del teléfono.

---

## 6. Pantallas relevantes

Sin cambios respecto a la auditoría anterior — esta sección es puramente de
código, no de infraestructura:

- **Chat/chatbot: ya existe.** [stock_chat_screen.dart](../lib/screens/stock_chat_screen.dart),
  ruta `/stock-chat`. Arma el contexto en texto plano desde SQLite local
  (`_buildContext()`, [líneas 27-64](../lib/screens/stock_chat_screen.dart#L27-L64):
  solo alertas de stock + top 5 proveedores) y llama al LLM **directo desde el
  teléfono** ([línea 84](../lib/screens/stock_chat_screen.dart#L84)). La
  interfaz `AiChatService` ([ai_chat_interface.dart](../lib/services/ai_chat/ai_chat_interface.dart))
  es reutilizable; lo que cambia es el origen del contexto (nube, con
  forecast) y quién llama al LLM (servidor).
- **Reportes/predicciones: ya existen, todo local.** Dashboard con 6
  secciones (balance financiero, destacados, movimientos, alertas de stock,
  ranking de proveedores, riesgo de inventario), todas sobre SQLite. El
  forecasting es **Holt con tendencia amortiguada implementado a mano**
  ([dashboard_service.dart:242-263](../lib/services/dashboard_service.dart#L242-L263)),
  con validación MAPE propia (`validateForecastAccuracy()`). Exige mínimo 17
  días de historial por producto.
- ⚠️ `DemandForecastSection` ([demand_forecast_section.dart](../lib/widgets_global/dashboard/demand_forecast_section.dart))
  es código muerto: nada la instancia, y su fallback devuelve datos
  inventados (`[2.0, 2.0, 3.0, 2.0, 4.0, 3.0, 5.0]`) si la predicción falla.

---

## Blockers, actualizados con los datos confirmados

1. **Plan Spark, confirmado (`billingEnabled: false`).** Sin Blaze no hay
   Functions ni Cloud Run. Es el primer paso, y es 100% manual tuyo (tarjeta +
   consola).
2. **No existe `bodega_id`** en ninguna tabla; los `product_id` son SKU libres
   que van a colisionar entre bodegas.
3. **No hay bucket de Storage real** (confirmado con 404) ni colección de
   ventas consultable en Firestore — solo un blob de backup contra el límite
   de 1 MiB.
4. **Reglas de Firestore confirmadas y razonables para el uso actual**, pero
   cualquier colección nueva necesita su propia regla explícita antes de
   usarse (Firestore deniega por defecto).
5. **API keys del LLM embebidas en el APK** — insostenible con múltiples
   bodegas; hay que mover la llamada al servidor.
6. **Ninguna service account propia creada todavía** para el futuro pipeline
   (hoy solo existen las de sistema/Admin SDK).

Nada de esto se modificó durante este diagnóstico: todas las consultas fueron
de lectura (`describe`, `list`, `get-iam-policy`, lectura de reglas vía API).
Los dos prompts interactivos de `gcloud` para habilitar APIs quedaron sin
confirmar.
