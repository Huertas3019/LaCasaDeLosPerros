import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lacasa_perros_pos/core/database/database_helper.dart';
import 'package:lacasa_perros_pos/models/gasto.dart';
import 'package:lacasa_perros_pos/models/venta_detalle.dart';
import 'package:lacasa_perros_pos/repositories/productos_repository.dart';
import 'package:lacasa_perros_pos/repositories/turnos_repository.dart';
import 'package:lacasa_perros_pos/repositories/gastos_repository.dart';
import 'package:lacasa_perros_pos/repositories/ventas_repository.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  group('Pruebas del Backend POS (SQLite & Repositorios)', () {
    test('Inicialización de Base de Datos y Datos Semilla', () async {
      final prodRepo = ProductosRepository();
      final productos = await prodRepo.getProductos();

      expect(productos.isNotEmpty, isTrue);
      // Verificar que existan insumos e ítems semilla
      final superPancho = productos.firstWhere((p) => p.nombre.contains('Super Pancho'));
      expect(superPancho, isNotNull);
    });

    test('Ciclo completo de Turno, Venta con Descuento de Receta y Arqueo', () async {
      final turnosRepo = TurnosRepository();
      final prodRepo = ProductosRepository();
      final ventasRepo = VentasRepository();
      final gastosRepo = GastosRepository();

      // 1. Abrir Turno con $5.000 de fondo de caja
      final turno = await turnosRepo.abrirTurno(5000.0, observaciones: 'Turno de prueba');
      expect(turno.id, isNotNull);
      expect(turno.isAbierto, isTrue);

      // 2. Obtener stock inicial de insumos Pan (100) y Salchicha (100)
      final productosAntes = await prodRepo.getProductos();
      final panAntes = productosAntes.firstWhere((p) => p.nombre.contains('Pan de Pancho'));
      final salchichaAntes = productosAntes.firstWhere((p) => p.nombre.contains('Salchicha'));
      double stockPanInicial = panAntes.stockActual;
      double stockSalchichaInicial = salchichaAntes.stockActual;

      // Buscar el producto Super Pancho Especial
      final superPancho = productosAntes.firstWhere((p) => p.nombre.contains('Super Pancho Especial'));

      // 3. Registrar venta de 2 Super Panchos ($5.000 total en efectivo)
      int ventaId = await ventasRepo.registrarVenta(
        turnoId: turno.id!,
        montoEfectivo: 5000.0,
        montoTransferencia: 0.0,
        items: [
          VentaDetalle(
            productoId: superPancho.id!,
            cantidad: 2,
            precioUnitario: superPancho.precioVentaUnitario!,
            subtotal: superPancho.precioVentaUnitario! * 2,
          ),
        ],
      );
      expect(ventaId, greaterThan(0));

      // 4. Verificar que se hayan descontado 2 panes y 2 salchichas del stock
      final productosDespues = await prodRepo.getProductos();
      final panDespues = productosDespues.firstWhere((p) => p.nombre.contains('Pan de Pancho'));
      final salchichaDespues = productosDespues.firstWhere((p) => p.nombre.contains('Salchicha'));

      expect(panDespues.stockActual, equals(stockPanInicial - 2.0));
      expect(salchichaDespues.stockActual, equals(stockSalchichaInicial - 2.0));

      // 5. Registrar un Gasto de Turno ($1.000) y una Sangría de Caja ($2.000)
      await gastosRepo.registrarGasto(Gasto(
        turnoId: turno.id,
        descripcion: 'Compra hielo',
        monto: 1000.0,
        tipoTransaccion: 'CAJA_TURNO',
        medioPago: 'EFECTIVO',
        fecha: DateTime.now().toIso8601String(),
      ));

      await gastosRepo.registrarGasto(Gasto(
        turnoId: turno.id,
        descripcion: 'Retiro caja fuerte',
        monto: 2000.0,
        tipoTransaccion: 'RETIRO_CAJA',
        medioPago: 'EFECTIVO',
        fecha: DateTime.now().toIso8601String(),
      ));

      // 6. Verificar Arqueo de Cierre
      // Efectivo Esperado = 5000 (Inicial) + 5000 (Ventas) - 1000 (Gasto) - 2000 (Sangria) = $7.000
      final resumen = await turnosRepo.obtenerResumenTurno(turno.id!);
      expect(resumen.efectivoTeoricoEnCaja, equals(7000.0));
      expect(resumen.totalRecaudadoTurno, equals(5000.0));

      // 7. Cerrar Turno
      await turnosRepo.cerrarTurno(
        turnoId: turno.id!,
        efectivoRealCierre: 7000.0,
        transferenciaRealCierre: 0.0,
      );

      final turnoCerrado = await turnosRepo.getTurnoActivo();
      expect(turnoCerrado, isNull); // Ya no hay turno abierto

      // 8. Probamos anular la venta y verificar la reversión automática de stock (+2 panes, +2 salchichas)
      await ventasRepo.anularVenta(ventaId);

      final productosRevertidos = await prodRepo.getProductos();
      final panRevertido = productosRevertidos.firstWhere((p) => p.nombre.contains('Pan de Pancho'));
      final salchichaRevertida = productosRevertidos.firstWhere((p) => p.nombre.contains('Salchicha'));

      expect(panRevertido.stockActual, equals(stockPanInicial));
      expect(salchichaRevertida.stockActual, equals(stockSalchichaInicial));
    });
  });
}
