# Casos de prueba corregidos — ConectaMarket

Versión corregida de los casos observados en la revisión de QA, lista para
reemplazar el texto correspondiente en el Excel de casos de prueba.

Los mensajes entre comillas son los textos exactos que muestra la aplicación,
tal como quedaron tras las correcciones de esta entrega.

---

## CP001 — Registrar un producto nuevo

**Corrección:** faltaba el precio de venta en los datos de prueba; ahora es un
campo obligatorio del formulario.

| Campo | Contenido |
|---|---|
| **Precondición** | La aplicación está abierta en la pestaña **Inventario**. No existe un producto con el SKU P001. |
| **Datos de prueba** | SKU o Código (ID): `P001`<br>Nombre del Producto: `Arroz Costeño 1kg`<br>**Precio de venta (S/): `3.50`**<br>Stock Actual: `24`<br>Umbral de Alerta: `5` |
| **Pasos** | 1. Presionar el botón **+**.<br>2. Completar los cinco campos con los datos de prueba.<br>3. Presionar **Guardar**. |
| **Resultado esperado** | El formulario se cierra y vuelve al listado. El producto aparece en el inventario como `Arroz Costeño 1kg`, con la línea `S/ 3.50 · Stock: 24.0 un.` y la etiqueta `DISPONIBLE`. |

**Variante negativa (misma pantalla):** dejar el precio vacío y presionar
**Guardar** → el campo muestra `Campo obligatorio` y no se guarda nada.
Ingresar `0` o un valor negativo → el campo muestra
`Ingrese un precio mayor a 0`.

---

## CP004 — Venta con stock insuficiente

**Corrección:** el caso mezclaba varios datos inválidos a la vez (serie, fecha y
tipo de movimiento), así que no aislaba la regla que se quiere probar. Ahora el
único dato inválido es la cantidad vendida.

| Campo | Contenido |
|---|---|
| **Precondición** | Existe el producto `P001 — Arroz Costeño 1kg` con **stock 10**. |
| **Datos de prueba** | Tipo de movimiento: **Venta**<br>Producto: `P001`<br>Cantidad: `15` (mayor al stock disponible)<br>Fecha y serie: valores válidos por defecto |
| **Pasos** | 1. Ir a la pestaña **Comprobantes**.<br>2. Presionar el botón **+** y seleccionar **Venta**.<br>3. Agregar el producto `P001` con cantidad `15`.<br>4. Presionar **Guardar**. |
| **Resultado esperado** | El comprobante **no** se registra y se muestra el mensaje `Stock insuficiente para 'Arroz Costeño 1kg'. Disponible: 10.0, solicitado: 15.0.`<br>El stock de `P001` sigue siendo **10** y el comprobante no aparece en el listado de ventas. |

---

## CP006 — Registrar un proveedor con RUC inválido

**Corrección:** el caso invalidaba varios campos a la vez; el nombre y el
teléfono ahora son válidos, de modo que el único motivo de rechazo posible es el
RUC.

| Campo | Contenido |
|---|---|
| **Precondición** | La aplicación está abierta en la pantalla **Proveedores**. |
| **Datos de prueba** | Nombre: `Distribuidora Lima` (válido)<br>Teléfono: `987654321` (válido)<br>RUC: `12345` (inválido: solo 5 dígitos) |
| **Pasos** | 1. Presionar el botón **+** para agregar un proveedor.<br>2. Completar los tres campos con los datos de prueba.<br>3. Presionar **Guardar**. |
| **Resultado esperado** | El proveedor **no** se guarda y se muestra el mensaje `El RUC debe tener exactamente 11 dígitos numéricos`. El proveedor no aparece en el listado. |

**Variantes equivalentes:** `2012345678A` (11 caracteres con una letra) y
`201234567890` (12 dígitos) producen el mismo mensaje. Un RUC de 11 dígitos como
`20123456789` se guarda correctamente.

---

## CP008 — Intentar eliminar un registro con movimientos asociados

**Corrección:** el paso 3 no indicaba que hay un diálogo de confirmación, y el
resultado esperado no reflejaba la restricción de integridad.

| Campo | Contenido |
|---|---|
| **Precondición** | Existe el producto `P001 — Arroz Costeño 1kg` con al menos un movimiento registrado (una compra o una venta). |
| **Pasos** | 1. Ir a la pestaña **Inventario**.<br>2. Abrir el producto `P001`.<br>3. Presionar el ícono **Eliminar** (tacho) del encabezado y **confirmar en el diálogo** presionando **Eliminar**. |
| **Resultado esperado** | El producto **no** se elimina y se muestra el mensaje `No se puede eliminar el producto: tiene N movimientos asociados.` (donde N es la cantidad real de movimientos).<br>La pantalla de detalle permanece abierta y el producto sigue existiendo en el inventario. |

**Caso equivalente para proveedores:** en **Proveedores**, presionar **Eliminar**
sobre un proveedor con compras registradas y confirmar → mensaje
`No se puede eliminar el proveedor: tiene N movimientos asociados.` y el
proveedor sigue en el listado.

**Caso de control (debe permitir el borrado):** un producto o proveedor **sin**
movimientos se elimina normalmente y desaparece del listado.

---

## CP014 — Cancelar el registro de un producto

**Corrección:** el paso «Presionar Catálogo tab» no corresponde: desde el
formulario no hay pestañas visibles. Se reemplaza por la acción real de salida.

| Campo | Contenido |
|---|---|
| **Precondición** | La aplicación está abierta en la pestaña **Inventario**. |
| **Pasos** | 1. Presionar el botón **+** para abrir el formulario de producto.<br>2. Completar algunos campos (por ejemplo SKU `P099` y nombre `Producto de prueba`).<br>3. **Presionar la flecha atrás del encabezado** (o el botón atrás del sistema). |
| **Resultado esperado** | La aplicación vuelve a la pantalla anterior (el listado de inventario) **sin guardar el registro**: el producto `P099` no aparece en el inventario. |

> El botón **Cancelar** del pie del formulario tiene el mismo efecto.

---

## CP017 — Visualizar la clasificación de riesgo de inventario

**Corrección:** el caso incluía «Presionar Guardar», acción que no existe en el
dashboard. Es un caso de solo lectura.

| Campo | Contenido |
|---|---|
| **Precondición** | Hay al menos un producto con historial de ventas de **17 días o más** (por debajo de ese mínimo el producto no es predecible y no se lista). |
| **Pasos** | 1. Ir al **Dashboard**.<br>2. Desplazarse hasta la sección de **riesgo de inventario**. |
| **Resultado esperado** | Por cada producto clasificable se muestra:<br>• el **nombre** del producto;<br>• el **stock** actual;<br>• la **cobertura en días** (`Stock: X / Cobertura: N días`);<br>• el **nivel de riesgo** (`BAJO`, `MEDIO`, `ALTO` o `CRÍTICO`);<br>• la **cantidad sugerida de compra** cuando el nivel no es `BAJO`.<br>El listado está ordenado por nivel de riesgo, del más crítico al más bajo. No se guarda ni se modifica ningún dato. |

---

## CP018 — Recálculo del nivel de riesgo al registrar una venta

**Corrección:** faltaba definir el stock inicial y la demanda diaria, sin los
cuales el nivel esperado no es verificable. Se agrega además la condición clave:
el cambio ocurre **sin salir del dashboard**.

| Campo | Contenido |
|---|---|
| **Precondición** | El producto `P001 — Arroz Costeño 1kg` tiene una demanda estable de **5 unidades/día** durante los últimos 20 días y un **stock de 200 unidades** (cobertura ≈ 40 días). |
| **Pasos** | 1. Abrir el **Dashboard** y verificar el nivel de riesgo inicial de `P001`.<br>2. Sin cerrar el dashboard, registrar una **venta de 175 unidades** de `P001` (deja el stock en 25, cobertura ≈ 5 días).<br>3. Volver a observar la sección de riesgo de inventario. |
| **Resultado esperado** | Nivel inicial: **BAJO** (cobertura 40 días, sin cantidad sugerida).<br>Tras la venta, el nivel cambia a **ALTO** (cobertura 5 días) y se muestra una compra sugerida de **125 u.**, **sin necesidad de salir del dashboard ni recargar la aplicación**. |

**Reglas de clasificación por cobertura:** más de 15 días → `BAJO`;
de 8 a 15 días → `MEDIO`; de 4 a 7 días → `ALTO`; menos de 4 días → `CRÍTICO`.

---

## CP040 — Restaurar un backup en la nube

**Corrección:** el paso 3 no nombraba la acción real ni el diálogo de
confirmación, y faltaba precisar la precondición.

| Campo | Contenido |
|---|---|
| **Precondición** | Sesión iniciada en un **dispositivo nuevo** (o con la base local vacía) y existe un **backup previo** en la nube para esa cuenta. |
| **Pasos** | 1. Ir al **Dashboard**.<br>2. Presionar el ícono **Restaurar backup** del encabezado (si no hay sesión activa, iniciar sesión en el diálogo que aparece).<br>3. **Confirmar presionando _Restaurar_** en el diálogo de advertencia. |
| **Resultado esperado** | Se muestra el diálogo **`Restauración completa`** con la fecha del backup y el detalle de `N producto(s)` y `N movimiento(s)` restaurados.<br>El inventario y los comprobantes recuperados aparecen en sus respectivas pantallas con el stock tal como estaba al momento del backup. |

> Los backups creados antes de esta entrega no incluyen el precio de venta: esos
> productos se restauran con precio `0` y hay que completarlo manualmente.

---

## Fuera del alcance de esta entrega

- **QA 0001827 / CP044 (cuestionario SUS):** es documentación y encuesta a
  usuarios, no una corrección de software.
- **QA 0002123 (ortografía «HISTRIAS»):** corresponde al archivo Excel, que no
  forma parte del repositorio.
