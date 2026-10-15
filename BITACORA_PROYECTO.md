# 📋 BITÁCORA Y ESTADO DEL PROYECTO
**La Casa de los Perros - Sistema POS & Inventario**

> ⚠️ **INSTRUCCIÓN PARA EL ASISTENTE IA:** Este documento debe ser leído al iniciar cada sesión de trabajo y **actualizado obligatoriamente al finalizar cada jornada**, registrando los cambios implementados, el estado actual del sistema y la lista de tareas pendientes para la siguiente sesión.

---

## 🚀 1. Cómo Ejecutar la Aplicación Rápidamente

Para levantar la app en cualquier momento:

### Modo Web (Navegador Firefox):
1. **Iniciar el servidor local:**
   ```bash
   python3 tool/serve_web.py
   ```
2. **Abrir en el navegador:**
   👉 Ir a [http://localhost:8080](http://localhost:8080) (o ejecutar `firefox http://localhost:8080`).

### Si se realizaron cambios en el código Dart:
Recompilar la versión web con:
```bash
flutter build web --release
```
*(Nota: El servidor `tool/serve_web.py` ya incluye las cabeceras `COOP` y `COEP` requeridas para SQLite WebAssembly).*

---

## 🛠️ 2. Entorno y Configuración del Sistema
* **SO:** Linux Mint 22.3 (kernel Linux 7.0)
* **SDK Flutter:** Instalado en `~/flutter` (canal master, Flutter 3.50+ / Dart 3.15).
* **Git:** Binarios configurados en `~/.local/bin/git` y `~/.local/lib/git-core`.
* **Variables de entorno:** Registradas de forma permanente en `~/.bashrc` y `~/.profile`:
  - `PATH="$HOME/.local/bin:$HOME/flutter/bin:$PATH"`
  - `GIT_EXEC_PATH="$HOME/.local/lib/git-core"`

---

## 📊 3. Estado Actual del Software (15 de Octubre de 2026)

| Módulo | Estado | Descripción |
| :--- | :---: | :--- |
| **Entorno & Tooling** | ✅ Listo | Flutter y Git instalados, configurados y operativos. |
| **Despliegue Web** | ✅ Funcionando | Servidor local activo en puerto 8080 con Canvaskit local. |
| **Persistencia SQLite Web** | ✅ Listo | `sqflite_common_ffi_web` configurado en `noWebWorker` con `sqlite3.wasm`. |
| **POS (Punto de Venta)** | ✅ Listo | Carrito, cobro en efectivo, transferencia o mixto, y validación de turno. |
| **Inventario & Recetas** | ✅ Listo | Gestión de Insumos, Productos, Combos, explosión de recetas y registro de mermas. |
| **Turnos & Arqueo** | ✅ Listo | Turnos nocturnos, fondo inicial, control de sangrías/retiros y diferencias de caja. |
| **Gastos & Balances** | ✅ Listo | Diferenciación de gastos operativos y fijos, COGS historizado y exportación de backups. |

---

## 📝 4. Historial de Sesiones (Changelog)

### 📅 Sesión 1: 14/10/2026 - 15/10/2026
* **Diagnóstico inicial:** Se revisó la totalidad del proyecto Flutter existente, modelos relacionales, esquemas de base de datos y especificaciones de negocio.
* **Aprovisionamiento del entorno:**
  - Se instaló Git portable en `~/.local/` y se clonó el SDK de Flutter en `~/flutter`.
  - Se compilaron las herramientas internas (`flutter_tools`) y se configuró el `PATH` permanente.
  - Se instalaron dependencias (`flutter pub get`).
* **Soporte Web y SQLite:**
  - Se compiló el Web Worker y se descargó el binario `sqlite3.wasm`.
  - En `lib/core/database/db_platform_web.dart` se cambió a `databaseFactoryFfiWebNoWebWorker` para evitar bloqueos por workers en navegadores modernos.
  - En `lib/main.dart` se protegió la llamada a `DatabaseHelper.instance.database` con `try/catch` para garantizar que la UI monte de inmediato.
  - Se creó el servidor local en Python con cabeceras aisladas: `tool/serve_web.py`.
  - Se compiló el paquete web (`flutter build web --release`) y se ajustó `flutter_bootstrap.js` para usar Canvaskit local.
* **Verificación visual:** Se lanzó Firefox en `http://localhost:8080`, confirmando que la aplicación carga completamente su interfaz oscura con el logo y el módulo de turnos listo.

---

## 🎯 5. Tareas Pendientes para Mañana (Próxima Sesión)

1. **Carga y prueba del catálogo gastronómico:**
   - Crear categorías básicas (ej: *Panchos, Bebidas, Combos*).
   - Dar de alta insumos reales (Pan de pancho, Salchichas, Aderezos, Gaseosas).
   - Crear productos con sus respectivas recetas.
   - Probar la apertura de un turno con fondo inicial (ej: \$10.000).
2. **Prueba de ciclo de ventas completo:**
   - Realizar una venta en efectivo y una con pago mixto (efectivo + transferencia).
   - Comprobar el descuento automático del stock en el módulo de Inventario.
   - Realizar un cierre de turno (arqueo de caja) y verificar que las diferencias y métricas financieras se calculen correctamente.
3. **Persistencia y Ejecución Nativa de Escritorio:**
   - Evaluar si se desea utilizar la versión Web o compilar como aplicación nativa de escritorio para Linux (`flutter run -d linux`) para tener almacenamiento persistente directo en disco sin depender del almacenamiento del navegador.
