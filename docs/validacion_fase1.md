# Validacion de la Fase 1 (bodega_id + backfill + firestore.rules)

Fecha: 2026-10-01
Rama auditada: `claude/bodega-id-firestore-schema` (commits `1c04bc8`, `4ef94ab`, `c1b033a`)
Alcance: auditoria de cobertura. **No se corrigio ningun hallazgo.** El unico
archivo nuevo agregado al repo es la suite de tests de reglas
(`test/firestore_rules/`), que antes no existia.

---

## 1. Resumen

| Area | Estado |
|---|---|
| Suite Dart completa | 49/49 pasan |
| Tests de la Fase 1 (stamping + backfill + migracion) | 21/21 pasan |
| `firestore.rules` contra el emulador | 31/31 pasan (antes: 0 ejecuciones) |
| Hallazgos abiertos | 3 importantes, 2 menores, 3 observaciones |

Lo mas relevante: las reglas de Firestore quedaron **validadas y se comportan
como se diseno**. En cambio, el estampado de `bodega_id` tiene dos vias por las
que una fila puede quedar sin dueno de forma permanente, y ninguna de las dos
tiene test; ademas, el caso central de la fase (un alta nueva queda estampada)
no esta verificado automaticamente en ningun lado.

---

## 2. Matriz de cobertura de los casos pedidos

| Caso | Cubierto | Donde |
|---|---|---|
| Alta nueva -> se estampa el uid actual | **NO** | ver H5 |
| Edicion de fila que ya tiene `bodega_id` -> se preserva | SI | `bodega_id_stamping_test.dart`, 3 tests (products/providers/receipts) |
| Edicion de fila con `bodega_id = NULL` | **NO** | respuesta abajo + H1 |
| Backfill: caso `completed` | SI | test (a), parametrizado x3 tablas |
| Backfill: caso `ambiguous` | SI | test (b), parametrizado x3 tablas |
| Backfill: caso `error` | SI | "un error inesperado en una tabla no bloquea a las demas" |
| Backfill: no-op en segunda corrida (idempotencia) | SI | test (c), parametrizado x3 tablas |
| Backfill: aislamiento por tabla | SI | "las 3 tablas se evaluan de forma independiente" |
| Backfill: `bodegaId` vacio -> no hace nada | SI | ultimo test del archivo |
| **Multiples `bodega_id` distintas entre si** | **NO** | ver H3 |
| `firestore.rules` | SI (nuevo) | `test/firestore_rules/rules.test.js` |

### Respuesta a la pregunta abierta: que hace hoy una edicion sobre una fila con `bodega_id = NULL`

**La deja en NULL. No la estampa.** No es inferencia: es lo que dice la rama en
[product_repository.dart:24-26](lib/repositories/product_repository.dart#L24-L26)
(identico en provider y receipt):

```dart
final String? bodegaId = existing.isNotEmpty
    ? existing.first['bodega_id'] as String?
    : AuthService.instance.currentUid;
```

Una fila preexistente con `bodega_id = NULL` **si** satisface
`existing.isNotEmpty`, con lo cual se toma la rama del `?`, que devuelve
`null`. El `currentUid` se consulta unicamente cuando la fila **no existe**
(alta real). Consecuencia concreta: editar un producto viejo mil veces, con
sesion activa, no le asigna dueno nunca. La unica via por la que una fila
legacy obtiene `bodega_id` es el backfill.

Esto tiene una lectura defendible (no reclamar como propia una fila cuyo dueno
no se conoce), pero no esta documentado como decision y su consecuencia no esta
manejada en ningun lado: ver H1.

---

## 3. Hallazgos

### H1 (importante) — Si el backfill marca una tabla como `ambiguous`, sus filas NULL quedan sin dueno para siempre

Encadenando el comportamiento de arriba con el del backfill:

1. El backfill, al detectar una `bodega_id` ajena en una tabla, no toca **nada**
   de esa tabla, incluidas las filas NULL
   ([bodega_backfill_service.dart](lib/services/bodega_backfill_service.dart)).
2. Las ediciones posteriores tampoco las estampan (seccion 2).
3. No hay ninguna otra via de asignacion.

Resultado: en un dispositivo que tuvo dos cuentas, las filas huerfanas quedan
en NULL de forma permanente, y el log pide una "REVISION MANUAL" para la que no
existe hoy herramienta ni procedimiento. El comentario del servicio dice que el
diseno "se autocura solo si alguien resuelve a mano la ambiguedad", lo cual es
exacto, pero ese "alguien" no tiene por donde hacerlo.

No es un crash: es una fila que nunca va a poder migrarse a la Fase 2. **Sin
test.**

### H2 (importante) — `insertReceiptForRestore` escribe en `receipts` sin pasar por el estampado

[receipt_repository.dart:82](lib/repositories/receipt_repository.dart#L82)
inserta el map crudo del backup, sin la logica de `bodega_id`. Lo usa
[sync_service.dart:153](lib/services/sync_service.dart#L153) dentro de
`restore()`, que antes borra **todos** los recibos locales. Dos escenarios:

- **Backup tomado en v6 o posterior:** el map crudo viene de
  `db.query('receipts')`, asi que **incluye** `bodega_id`. Si se restaura un
  backup de la cuenta B estando logueado como A, los recibos entran estampados
  con el uid de B. A partir de ahi el backfill marca `receipts` como
  `ambiguous` de forma permanente y, por H1, ninguna edicion lo arregla.
- **Backup anterior a v6:** el map no trae la clave `bodega_id`, los recibos
  entran en NULL y (por H1) no se estampan nunca; solo los rescata un backfill
  en el proximo arranque, porque el listener de `main.dart` reacciona a
  emisiones de sesion, no al final de un restore.

Asimetria a notar: en el mismo `restore()` los **productos** si quedan bien
estampados, porque pasan por `upsertProduct` sobre una tabla recien vaciada (la
fila no existe -> toma `currentUid`). Productos y recibos se comportan distinto
en la misma operacion.

**Sin test.**

### H3 (menor) — La ambiguedad se reporta con una sola `bodega_id` ajena, elegida de forma no determinista

La deteccion usa `limit: 1` sin `ORDER BY`
([bodega_backfill_service.dart:91](lib/services/bodega_backfill_service.dart#L91)).
Con dos o mas uids ajenos distintos entre si, `bodegaIdAjenaDetectada` es
cualquiera de ellos (lo que devuelva SQLite primero) y el log afirma que la
tabla "tiene filas con bodega_id='X'", dando a entender que hay un unico dueno
ajeno. Para una revision manual —que es justamente lo que el mensaje pide— ese
dato incompleto desorienta.

**Este es el edge case que quedo sin cubrir.** El test (b) inserta un solo
`uid-B`, con lo cual el caso de multiples uids ajenos entre si no se ejercita.
El `outcome` seria igualmente `ambiguous` (correcto); el diagnostico, no.

### H4 (menor) — Se reporta `ambiguous` incluso cuando no hay ninguna fila NULL que backfillear

El chequeo de ambiguedad corre antes de preguntar si hay trabajo por hacer. Una
tabla con filas de `uid-B` y **cero** NULLs devuelve `ambiguous` y loguea
"PENDIENTE DE REVISION MANUAL", aunque no haya nada pendiente. Es ruido en el
log, no un riesgo de datos. (Se puede defender como alerta legitima de que el
dispositivo tiene datos de otra bodega; en ese caso conviene que el mensaje lo
diga asi.)

### H5 (importante) — No hay test de que un alta estampe el uid actual

Los tres tests de alta de `bodega_id_stamping_test.dart` afirman que `bodega_id`
queda **null**:

```
test('un alta sin sesion activa (como en los tests) deja bodega_id en null', ...)
```

Son correctos y estan honestamente nombrados, pero verifican el **fallback**, no
el estampado. La rama `: AuthService.instance.currentUid` no se ejercita con un
uid real en ningun test de la suite. O sea: el caso central de la Fase 1 —"un
alta nueva queda estampada con la bodega actual"— no esta verificado
automaticamente.

La causa es estructural: `AuthService` es un singleton que resuelve
`FirebaseAuth.instance` adentro, no inyectable, asi que no se puede falsear sin
tocar el servicio. Cambiar eso excede una tarea de validacion, pero hay que
saber que ese caso hoy solo se puede verificar a mano en el dispositivo (paso 8
de la seccion 6).

### H6 (observacion) — `bodega_id` todavia no se consume en ninguna lectura

`grep` sobre `lib/` confirma cero filtros por `bodega_id`: ni los repositorios
ni el dashboard lo usan en un `WHERE`. Es coherente con el alcance de la Fase 1
(columna + estampado + esquema), pero conviene dejarlo escrito: **la Fase 1 no
entrega aislamiento local**. En un dispositivo compartido, la cuenta A sigue
viendo el inventario de la cuenta B. El aislamiento real llega cuando las
lecturas filtren, o del lado de la nube con las reglas ya validadas.

### H7 (observacion, preexistente) — `restore()` no restaura proveedores

`backup()` no incluye `providers` y `restore()` no los borra ni los reinserta.
No es un problema de la Fase 1, pero importa para la verificacion manual: tras
un restore los proveedores quedan intactos, con su `bodega_id` previo.

### H8 (observacion) — El backfill se dispara sin `await` en cada emision de sesion

[main.dart:23](lib/main.dart#L23) hace `userStream.listen(...)` y llama a
`runForBodega` sin esperarlo. Si el stream emite dos veces seguidas, pueden
solaparse dos corridas. El riesgo practico es bajo (la operacion es idempotente
y `UPDATE ... WHERE bodega_id IS NULL` es convergente), y no esperar es
deliberado y esta comentado. Se deja anotado, no como bug.

---

## 4. Diff real vs. lo reportado

`git diff main...claude/bodega-id-firestore-schema --stat` devuelve **39
archivos**, bastante mas que lo reportado. La razon no es un archivo
inesperado: `main` esta 8 commits atras, y 5 de esos commits son trabajo previo
(precio de venta, restriccion de borrado, riesgo de inventario, tests de QA,
docs de infraestructura). Nada fuera de lugar ahi.

El diff que corresponde a la Fase 1 es `git diff 65ee97f...HEAD --stat`, y son
**12 archivos**:

| Archivo | En la lista reportada |
|---|---|
| `lib/repositories/product_repository.dart` | si |
| `lib/repositories/provider_repository.dart` | si |
| `lib/repositories/receipt_repository.dart` | si |
| `lib/services/auth_service.dart` | si |
| `lib/services/bodega_backfill_service.dart` | si (nuevo) |
| `lib/main.dart` | si |
| `firestore.rules` | si (nuevo) |
| `docs/esquema_fase1_multi_bodega.md` | si (nuevo) |
| `test/bodega_id_stamping_test.dart` | si (nuevo) |
| `test/bodega_backfill_service_test.dart` | si (nuevo) |
| `lib/repositories/database_helper.dart` | **no mencionado explicitamente** |
| `test/database_migration_test.dart` | **no mencionado: es modificado, no nuevo** |

Las dos discrepancias son menores y ambas legitimas:

- `database_helper.dart` es donde vive la migracion a v6 y el `CREATE TABLE`
  con `bodega_id`. Queda cubierto por "los 3 repositorios" solo si se lee de
  forma laxa, pero es el archivo mas importante del commit de esquema.
- `database_migration_test.dart` se **extendio** (v5 -> v6, mas un test nuevo de
  columnas), no se creo. La lista decia "los archivos de test nuevos", lo que
  omite esta modificacion.

**Ningun archivo de la app fue tocado sin estar reportado.** No hay hallazgo de
alcance.

---

## 5. firestore.rules contra el Emulator Suite

Estado previo: escrito, nunca ejecutado. Ahora: **31/31 aserciones pasan**.

Suite nueva en `test/firestore_rules/` (`@firebase/rules-unit-testing` + mocha +
Firestore Emulator). Corre con projectId `demo-conectamarket`, que el CLI
reconoce como demo y aisla por completo: **no se desplego nada a ningun proyecto
real**. El test lee el `firestore.rules` real del repo, no una copia.

### Resultado por caso pedido

| # | Caso | Aserciones | Resultado |
|---|---|---|---|
| 1 | El dueno lee/escribe `bodegas/{suUid}/{productos,ventas,compras}` | 9 (get + list + write x3) | **PASA** |
| 2 | Ese usuario NO accede a `bodegas/{otroUid}/...` en las 3 colecciones | 9 (get + list + write x3) | **PASA** |
| 2b | Ese usuario NO lee `forecasts` de otra bodega | 1 | **PASA** |
| 3 | Nadie escribe en `bodegas/{uid}/forecasts`, ni el dueno | 2 (create + sobrescritura) | **PASA** |
| 4 | El dueno SI lee `bodegas/{suUid}/forecasts` | 2 (get + list) | **PASA** |
| 5 | No autenticado no lee ni escribe nada bajo `/bodegas/**` | 8 (4 colecciones x read/write) | **PASA** |

Las denegaciones llegan como `PERMISSION_DENIED` del emulador citando la linea
exacta de la regla que las produjo (p. ej. `false for 'create' @ L40` para
`forecasts`), lo que confirma que lo que deniega es la regla esperada y no otra.

### Control negativo

Para descartar que la suite pase de forma vacia, se corrio la misma suite contra
unas reglas `deny-all`: **20 pasan, 11 fallan** — exactamente las 11 aserciones
de "permitido". La suite es sensible en las dos direcciones: no pasa porque las
reglas "se vean razonables", pasa porque permite lo que debe permitir y deniega
lo que debe denegar.

### Como reproducirlo

```sh
cd test/firestore_rules
npm install
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"   # Windows: alcanza el JDK de Android Studio
npm test
```

Dos detalles de entorno que vale documentar: el emulador de Firestore
**necesita un JDK** (no habia `java` en el PATH; se uso el que trae Android
Studio) y se configuro el **puerto 8085** porque el 8080 estaba ocupado.

El `emulator-bootstrap.rules` del directorio es un placeholder deny-all que solo
existe porque el CLI exige una ruta de reglas dentro del directorio del config;
las reglas que realmente se prueban las carga `rules.test.js` desde
`../../firestore.rules`.

### Lo que esta suite NO cubre

- El bloque `match /users/{userId}/{document=**}` de la Fase 0, que es el que
  usa hoy `sync_service.dart`. Se validaron las rutas nuevas de la Fase 1.
- Reglas de validacion de **contenido** de los documentos (forma, tipos, campos
  obligatorios). Las reglas actuales solo deciden por ruta y uid, asi que un
  dueno puede escribir cualquier payload en su propio subarbol.
- `bodegas/{bodegaId}` como documento en si, y cualquier subcoleccion futura
  distinta de las cuatro declaradas. Por como estan escritas las reglas (rutas
  una por una, sin `{document=**}`), **una subcoleccion nueva queda denegada por
  defecto** — que es el comportamiento deseado, pero significa que agregar una
  coleccion en la Fase 2 obliga a agregar su regla.

---

## 6. Migracion sobre una base real: pasos para hacer a mano

No se ejecuto: requiere el dispositivo y datos reales. Lo que conviene hacer, en
este orden.

**Antes de abrir la app (imprescindible):**

1. Sacar una copia del `.db` del dispositivo antes de que corra la migracion a
   v6. Es la unica forma de volver atras: `_onUpgrade` no tiene downgrade, y la
   app migra sola en el primer arranque.
2. Si la cuenta tiene backup en la nube, correr un `backup()` desde la version
   actual, antes de actualizar.

**Primer arranque con la version nueva, ya logueado:**

3. Verificar a simple vista que **nada se perdio**: el conteo de productos,
   proveedores y recibos tiene que ser el mismo que antes, y el stock y los
   precios iguales. La migracion solo agrega columnas, pero es la verificacion
   que importa.
4. Mirar el log de arranque. Lo esperable es que **no** aparezca ningun mensaje
   de `[BodegaBackfillService]`: el silencio significa `completed`. Si aparece
   `PENDIENTE DE REVISION MANUAL`, pararse ahi y avisar: ese dispositivo tuvo
   otra cuenta y, por H1, esas filas no se arreglan solas.
5. Confirmar que el backfill efectivamente estampo: en el `.db`,
   `SELECT COUNT(*) FROM products WHERE bodega_id IS NULL` (y lo mismo en
   `providers` y `receipts`) tiene que dar **0**.
6. Confirmar que estampo con el uid correcto:
   `SELECT DISTINCT bodega_id FROM products` debe devolver exactamente un valor,
   y tiene que ser el uid de la sesion.

**Segunda corrida (idempotencia):**

7. Cerrar y volver a abrir la app. Repetir el paso 5: debe seguir dando 0, y el
   paso 6 debe seguir devolviendo el mismo uid unico. El backfill no tiene flag
   de "ya corrio", asi que corre de nuevo en cada arranque; lo que hay que
   confirmar es que la segunda corrida **no cambia nada** (es un
   `UPDATE ... WHERE bodega_id IS NULL` sobre cero filas).

**Caso del alta nueva (H5, el que no tiene test automatico):**

8. Dar de alta un producto nuevo y verificar en el `.db` que su `bodega_id`
   quedo con el uid de la sesion. Este es el unico chequeo de la lista que cubre
   un caso que la suite automatizada **no** verifica: no conviene saltearlo.
9. Editar ese mismo producto (cambiarle el stock) y confirmar que `bodega_id`
   **no** cambio ni quedo en NULL.

**Si se va a probar un restore (H2):**

10. Hacerlo solo con un backup de la **misma** cuenta. Despues del restore,
    revisar `SELECT COUNT(*) FROM receipts WHERE bodega_id IS NULL`: si el
    backup era anterior a v6 va a dar > 0, y recien se corrige en el siguiente
    arranque de la app. Tener en cuenta tambien (H7) que los proveedores no se
    restauran.

---

## 7. Que quedaria por decidir

En orden de lo que parece mas urgente, para hablarlo:

1. **H2** — que debe hacer `insertReceiptForRestore` con `bodega_id`: descartar
   el del backup y estampar la sesion actual, o respetarlo. Hoy lo respeta por
   accidente, no por decision.
2. **H1** — si una edicion sobre una fila NULL deberia estamparla, y que
   herramienta se le da a quien tiene que resolver una tabla `ambiguous`.
3. **H5** — si vale hacer `AuthService` inyectable para poder testear el
   estampado de verdad, o si alcanza con la verificacion manual del paso 8.
4. **H3/H4** — mejorar el diagnostico de ambiguedad (listar todos los uids
   ajenos, y distinguir "hay datos ajenos" de "hay NULLs que no puedo migrar").
