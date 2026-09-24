# Especificación Técnica del Sistema de Comida Rápida (POS, Inventario y Caja)

## 1. Visión General del Sistema

Sistema de gestión de ventas (Punto de Venta - POS), control de inventario dinámico por recetas (Lista de Materiales - BOM), gestión de turnos nocturnos, arqueo de caja con control de sangrías/retiros y balance financiero real para un comercio de comida rápida.

## 2. Definición del Dominio y Lógica de Negocio

### A. Inventario y Combos (Despiece / Recetas)

* **Ingredientes / Insumos:** Todos los ítems físicos con control de stock (ej. Pan de panco, Salchicha común, Salchicha parrillera, Coca-Cola 500ml). Tienen precio de costo y pueden o no venderse individualmente.
* **Productos / Combos de Venta:** Ítems expuestos al cliente (ej. *Super Pancho Combo 1*, *Combo 3*). No tienen stock propio, dependen de su receta.
* **Recetas (Listas de Materiales / BOM):** Relación de 1 a muchos entre un Producto/Combo y los Insumos requeridos.
* **Descuento Dinámico de Stock:** Al registrar la venta de 1 unidad de un combo (en estado `COMPLETADA`), el sistema aplica un descuento automático sobre el stock actual de cada ingrediente/insumo en la cantidad configurada en la receta.
* **Política de Stock Negativo Permisivo:** El sistema permite registrar ventas aun cuando el stock de algún insumo sea insuficiente o llegue a valores negativos (con advertencia en interfaz), evitando bloquear la operación de venta en momentos de alta concurrencia por retrasos en la carga de facturas de compra.
* **Historización de Costos (COGS):** Para evitar distorsiones financieras históricas cuando cambian los precios de costo de los insumos, cada venta desglosa y congela el `costo_total_estimado` en la cabecera y el `costo_unitario_historico` en cada renglón del detalle.

### B. Gestión de Turnos Nocturnos y Cierre de Caja

* **Turno Operativo vs. Fecha Calendario:** Los turnos de trabajo no están atados al cambio estricto de medianoche (ej. Viernes 13:00 hs a Sábado 03:00 hs).
* **ID de Turno Primario:** Las ventas, los arqueos de caja y los gastos/retiros operativos de turno quedan imputados directamente al `turno_id` activo en el momento de la transacción.
* **Unicidad de Turno Activo:** El sistema garantiza que solo pueda existir **1 turno en estado `ABIERTO`** de forma simultánea.
* **Fondo de Caja:** Cada turno inicia con un monto inicial en efectivo (`monto_inicial_efectivo`).
* **Distinción entre Gastos de Turno y Retiros de Caja (Sangrías):**
  * **Gastos de Caja de Turno (`CAJA_TURNO`):** Salidas de dinero de la caja chica para compras imprevistas o pago a proveedores del turno. Afectan la ganancia neta.
  * **Retiros de Caja / Sangrías (`RETIRO_CAJA`):** Extracciones de efectivo por seguridad o guardado en caja fuerte por parte del dueño/encargado. **Disminuyen el efectivo físico en caja pero NO disminuyen la ganancia neta del negocio.**
* **Cierre, Arqueo y Congelamiento Historizado:**
  Al cerrar el turno, se calcula el balance teórico y se guarda en la tabla `turnos` junto con el conteo real y las diferencias (sobrante/faltante), congelando la auditoría:

  * **Efectivo Teórico Esperado en Caja Chica:**
    $$
    \text{Efectivo Esperado} = \text{Monto Inicial} + \text{Ventas en Efectivo} - (\text{Gastos de Turno en Efectivo} + \text{Retiros de Caja en Efectivo})
    $$

  * **Diferencia de Efectivo (Faltante / Sobrante):**
    $$
    \text{Diferencia Efectivo} = \text{Efectivo Real Cierre} - \text{Efectivo Esperado}
    $$

  * **Transferencias Esperadas en Banco:**
    $$
    \text{Transferencias Esperadas} = \text{Ventas en Transferencia} - \text{Gastos de Turno en Transferencia}
    $$

  * **Total Recaudado en el Turno:**
    $$
    \text{Total Recaudado} = \text{Ventas en Efectivo} + \text{Ventas en Transferencia}
    $$

* **Imputación Periódica:** La contabilidad y el margen financiero de un período se determinan tomando como referencia la **`fecha_inicio`** del turno.

### C. Ventas, Medios de Pago y Anulaciones

* **Soporte de Pagos Divididos / Mixtos:** Cada venta registra explícitamente `monto_efectivo` y `monto_transferencia`, permitiendo pagos 100% efectivo, 100% transferencia o divididos (ej. $4.000 efectivo + $6.000 transferencia).
* **Anulación de Ventas con Reversión de Stock:**
  Una venta en estado `ANULADA` no computa en los ingresos ni en la recaudación del turno, y desencadena la reversión (reingreso automático) del stock de los insumos descontados originalmente.

### D. Estructura de Costos y Balance Financiero

* **Costo Directo (COGS):** Suma de los costos históricos congelados de los insumos consumidos en las ventas con estado `COMPLETADA`.
* **Ganancia Bruta del Turno:**
  $$
  \text{Ganancia Bruta} = \text{Ventas Totales Completadas del Turno} - \text{Costo Total de Insumos del Turno}
  $$
* **Gastos Operativos Fijos (`turno_id` IS NULL):** Gastos periódicos (Luz, Alquiler, Sueldos fijos) cargados fuera de la caja diaria.
* **Ganancia Neta del Período:**
  $$
  \text{Ganancia Neta} = \text{Ganancia Bruta de Turnos} - (\text{Gastos de Turno} + \text{Gastos Fijos})
  $$
  *(Nota: Los `RETIRO_CAJA` quedan excluidos de esta resta por ser transferencias de activos y no gastos)*.

### E. Copias de Seguridad (Backup, Compartición y Restauración)

* **Generación de Backup Local:** Exportación manual o programada del archivo de base de datos `.db` nombrado con estampado de fecha y hora (ej. `pos_backup_2026-09-22_0130.db`).
* **Compartición Nativa (WhatsApp / Google Drive / Email):** Utilización del diálogo de compartición nativo del sistema operativo (`share_plus`) para enviar el archivo de respaldo directamente por WhatsApp, guardarlo en Google Drive, enviarlo por Email o copiarlo a un almacenamiento externo/USB.
* **Restauración Segura:** Capacidad de seleccionar un archivo de copia de seguridad externo e importarlo previa validación de integridad del esquema SQL y confirmación del usuario.

## 3. Esquema de Base de Datos (Relacional)

```
 [ categorias ] ───< [ productos ] ───< [ recetas ] ───> [ productos (Combo) ]
                          │                                     │
                          ├───< [ venta_detalles ] >───────────┘
                          │            │
                          │       [ ventas ]
                          │            │
                          │       [ turnos ] ───< [ gastos ]
```

### Definición de Tablas DDL (SQL ANSI / Adaptable a SQLite)

```sql
-- 1. Categorías de Insumos y Productos
CREATE TABLE categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Productos e Insumos Físicos
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    categoria_id INT REFERENCES categorias(id),
    nombre VARCHAR(150) NOT NULL,
    precio_costo DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    precio_venta_unitario DECIMAL(12, 2) NULL, -- NULL si no se vende de forma individual
    stock_actual DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    unidad_medida VARCHAR(20) NOT NULL DEFAULT 'Unidad', -- Unidad, Gramos, Litros, etc.
    es_vendible_solo BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Recetas / Lista de Materiales (BOM)
CREATE TABLE recetas (
    id SERIAL PRIMARY KEY,
    producto_padre_id INT NOT NULL REFERENCES productos(id) ON DELETE CASCADE, -- El Combo o Producto final
    insumo_id INT NOT NULL REFERENCES productos(id), -- El Ingrediente a descontar
    cantidad_requerida DECIMAL(10, 3) NOT NULL,
    CONSTRAINT uq_receta_padre_insumo UNIQUE (producto_padre_id, insumo_id)
);

-- 4. Registro de Turnos de Caja
CREATE TABLE turnos (
    id SERIAL PRIMARY KEY,
    fecha_inicio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_fin TIMESTAMP NULL,
    monto_inicial_efectivo DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    efectivo_real_cierre DECIMAL(12, 2) NULL,
    transferencia_real_cierre DECIMAL(12, 2) NULL,
    efectivo_esperado_cierre DECIMAL(12, 2) NULL,
    transferencia_esperada_cierre DECIMAL(12, 2) NULL,
    diferencia_efectivo DECIMAL(12, 2) NULL,
    diferencia_transferencia DECIMAL(12, 2) NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'ABIERTO' CHECK (estado IN ('ABIERTO', 'CERRADO')),
    observaciones TEXT NULL
);

-- 5. Control de Gastos Operativos, de Turno y Sangrías
CREATE TABLE gastos (
    id SERIAL PRIMARY KEY,
    turno_id INT NULL REFERENCES turnos(id), -- NULL = Gasto Fijo Operativo General, INT = Movimiento del Turno
    descripcion VARCHAR(255) NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    tipo_transaccion VARCHAR(30) NOT NULL CHECK (tipo_transaccion IN ('OPERATIVO_FIJO', 'CAJA_TURNO', 'RETIRO_CAJA')),
    medio_pago VARCHAR(20) NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TRANSFERENCIA')),
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. Cabecera de Ventas
CREATE TABLE ventas (
    id SERIAL PRIMARY KEY,
    turno_id INT NOT NULL REFERENCES turnos(id),
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_efectivo DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    monto_transferencia DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    total_venta DECIMAL(12, 2) NOT NULL,
    costo_total_estimado DECIMAL(12, 2) NOT NULL DEFAULT 0.00, -- COGS congelado al vender
    estado VARCHAR(20) NOT NULL DEFAULT 'COMPLETADA' CHECK (estado IN ('COMPLETADA', 'ANULADA'))
);

-- 7. Detalle de Ítems Vendidos
CREATE TABLE venta_detalles (
    id SERIAL PRIMARY KEY,
    venta_id INT NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
    producto_id INT NOT NULL REFERENCES productos(id),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(12, 2) NOT NULL,
    costo_unitario_historico DECIMAL(12, 2) NOT NULL DEFAULT 0.00, -- Costo congelado al vender
    subtotal DECIMAL(12, 2) NOT NULL
);

## 4. Consultas SQL Clave para la Lógica Financiera

### A. Obtener Cierre y Arqueo del Turno Activo

```sql
SELECT 
    t.id AS turno_id,
    t.monto_inicial_efectivo,
    -- Ventas Efectivas (Solo ventas COMPLETADA)
    COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_efectivo ELSE 0 END), 0) AS ventas_efectivo,
    COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_transferencia ELSE 0 END), 0) AS ventas_transferencia,
    
    -- Gastos de Turno por Medio de Pago (Excluye RETIRO_CAJA de gastos operativos)
    COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'EFECTIVO'), 0) AS gastos_efectivo_caja,
    COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'TRANSFERENCIA'), 0) AS gastos_transferencia_caja,
    
    -- Retiros de Caja / Sangrías (Disminuyen efectivo físico, no ganancia)
    COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'RETIRO_CAJA' AND g.medio_pago = 'EFECTIVO'), 0) AS retiros_efectivo_caja,

    -- Efectivo Teórico Esperado en Caja Chica
    (
        t.monto_inicial_efectivo + 
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_efectivo ELSE 0 END), 0) - 
        (
            COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'EFECTIVO'), 0) +
            COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'RETIRO_CAJA' AND g.medio_pago = 'EFECTIVO'), 0)
        )
    ) AS efectivo_teorico_en_caja,

    -- Transferencias Netas Esperadas en Banco
    (
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_transferencia ELSE 0 END), 0) - 
        COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'TRANSFERENCIA'), 0)
    ) AS transferencias_netas_banco,

    -- Total Recaudado en el Turno
    COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.total_venta ELSE 0 END), 0) AS total_recaudado_turno

FROM turnos t
LEFT JOIN ventas v ON v.turno_id = t.id
WHERE t.id = :ID_TURNO_ACTIVO
GROUP BY t.id, t.monto_inicial_efectivo;
```

### B. Cálculo de Ganancia Neta Periódica (Basado en Inicio de Turnos)

```sql
WITH ResumenTurnosPeriodo AS (
    SELECT 
        t.id AS turno_id,
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.total_venta ELSE 0 END), 0) AS total_ventas_turno,
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.costo_total_estimado ELSE 0 END), 0) AS costo_insumos_turno,
        -- Solo incluye gastos reales de turno (CAJA_TURNO), excluye RETIRO_CAJA
        COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO'), 0) AS gastos_caja_turno
    FROM turnos t
    LEFT JOIN ventas v ON v.turno_id = t.id
    WHERE t.fecha_inicio >= :FECHA_INICIO 
      AND t.fecha_inicio <  :FECHA_FIN
    GROUP BY t.id
),
GastosFijosPeriodo AS (
    SELECT 
        COALESCE(SUM(monto), 0) AS total_gastos_fijos
    FROM gastos
    WHERE turno_id IS NULL 
      AND tipo_transaccion = 'OPERATIVO_FIJO'
      AND fecha >= :FECHA_INICIO 
      AND fecha <  :FECHA_FIN
)
SELECT 
    COALESCE(SUM(rt.total_ventas_turno), 0) AS ingresos_totales,
    COALESCE(SUM(rt.costo_insumos_turno), 0) AS costo_total_insumos,
    (COALESCE(SUM(rt.total_ventas_turno), 0) - COALESCE(SUM(rt.costo_insumos_turno), 0)) AS ganancia_bruta,
    COALESCE(SUM(rt.gastos_caja_turno), 0) AS gastos_de_turno,
    COALESCE(MAX(gf.total_gastos_fijos), 0) AS total_gastos_fijos,
    (
        (COALESCE(SUM(rt.total_ventas_turno), 0) - COALESCE(SUM(rt.costo_insumos_turno), 0)) - 
        (COALESCE(SUM(rt.gastos_caja_turno), 0) + COALESCE(MAX(gf.total_gastos_fijos), 0))
    ) AS ganancia_neta_final
FROM ResumenTurnosPeriodo rt
CROSS JOIN GastosFijosPeriodo gf;
```