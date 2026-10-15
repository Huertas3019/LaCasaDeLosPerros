import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lacasa_perros_pos/core/database/database_helper.dart';
import 'package:lacasa_perros_pos/models/gasto.dart';
import 'package:lacasa_perros_pos/models/producto.dart';
import 'package:lacasa_perros_pos/models/receta.dart';
import 'package:lacasa_perros_pos/models/ajuste_inventario.dart';
import 'package:lacasa_perros_pos/models/venta_detalle.dart';
import 'package:lacasa_perros_pos/repositories/productos_repository.dart';
import 'package:lacasa_perros_pos/repositories/recetas_repository.dart';
import 'package:lacasa_perros_pos/repositories/ajustes_inventario_repository.dart';
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
    test('Inicialización de Base de Datos y Creación de Insumos', () async {
      final prodRepo = ProductosRepository();
      final panId = await prodRepo.insertProducto(Producto(
        nombre: 'Pan de Pancho',
        precioCosto: 150.0,
        stockActual: 100.0,
        tipo: 'INSUMO',
      ));

      expect(panId, greaterThan(0));
      final productos = await prodRepo.getProductos();
      expect(productos.isNotEmpty, isTrue);
    });

    test('Ciclo completo de Turno, Venta con Descuento de Receta y Arqueo', () async {
      final turnosRepo = TurnosRepository();
      final prodRepo = ProductosRepository();
      final ventasRepo = VentasRepository();
      final gastosRepo = GastosRepository();
      final recetasRepo = RecetasRepository();

      // Insertar productos e insumos de prueba
      final panId = await prodRepo.insertProducto(Producto(
        nombre: 'Pan de Pancho (Unidad)',
        precioCosto: 150.0,
        stockActual: 100.0,
        tipo: 'INSUMO',
      ));
      final salchichaId = await prodRepo.insertProducto(Producto(
        nombre: 'Salchicha (Unidad)',
        precioCosto: 300.0,
        stockActual: 100.0,
        tipo: 'INSUMO',
      ));
      final superPanchoId = await prodRepo.insertProducto(Producto(
        nombre: 'Super Pancho Especial',
        precioCosto: 450.0,
        precioVentaUnitario: 2500.0,
        esVendibleSolo: true,
        tipo: 'PRODUCTO',
      ));

      await recetasRepo.guardarRecetaCompleta(superPanchoId, [
        Receta(productoPadreId: superPanchoId, insumoId: panId, cantidadRequerida: 1),
        Receta(productoPadreId: superPanchoId, insumoId: salchichaId, cantidadRequerida: 1),
      ]);

      // 1. Abrir Turno con $5.000 de fondo de caja
      final turno = await turnosRepo.abrirTurno(5000.0, observaciones: 'Turno de prueba');
      expect(turno.id, isNotNull);
      expect(turno.isAbierto, isTrue);

      // 2. Obtener stock inicial de insumos Pan (100) y Salchicha (100)
      final panAntes = await prodRepo.getProductoPorId(panId);
      final salchichaAntes = await prodRepo.getProductoPorId(salchichaId);
      final superPancho = await prodRepo.getProductoPorId(superPanchoId);

      double stockPanInicial = panAntes!.stockActual;
      double stockSalchichaInicial = salchichaAntes!.stockActual;

      // 3. Registrar venta de 2 Super Panchos ($5.000 total en efectivo)
      int ventaId = await ventasRepo.registrarVenta(
        turnoId: turno.id!,
        montoEfectivo: 5000.0,
        montoTransferencia: 0.0,
        items: [
          VentaDetalle(
            productoId: superPancho!.id!,
            cantidad: 2,
            precioUnitario: superPancho.precioVentaUnitario!,
            subtotal: superPancho.precioVentaUnitario! * 2,
          ),
        ],
      );
      expect(ventaId, greaterThan(0));

      // 4. Verificar que se hayan descontado 2 panes y 2 salchichas del stock
      final panDespues = await prodRepo.getProductoPorId(panId);
      final salchichaDespues = await prodRepo.getProductoPorId(salchichaId);

      expect(panDespues!.stockActual, equals(stockPanInicial - 2.0));
      expect(salchichaDespues!.stockActual, equals(stockSalchichaInicial - 2.0));

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

      final panRevertido = await prodRepo.getProductoPorId(panId);
      final salchichaRevertida = await prodRepo.getProductoPorId(salchichaId);

      expect(panRevertido!.stockActual, equals(stockPanInicial));
      expect(salchichaRevertida!.stockActual, equals(stockSalchichaInicial));
    });

    test('Ajustes de inventario con conversión de unidades (Docena -> Unidades)', () async {
      final prodRepo = ProductosRepository();
      final ajustesRepo = AjustesInventarioRepository();

      // Crear un insumo con conversión (ej. Tequeños por Docena)
      final tequenosId = await prodRepo.insertProducto(Producto(
        nombre: 'Tequeños de Queso',
        precioCosto: 150.0,
        stockActual: 0.0,
        unidadMedida: 'Unidad',
        unidadCompra: 'Docena',
        factorConversion: 12.0,
        tipo: 'INSUMO',
      ));

      // Registrar un ajuste por 2 Docenas
      await ajustesRepo.registrarAjuste(AjusteInventario(
        insumoId: tequenosId,
        cantidad: 2 * 12.0, // 24 Unidades base
        cantidadIngresada: 2.0,
        unidadIngreso: 'Docena',
        factorConversionUsado: 12.0,
        tipoAjuste: 'INGRESO_MANUAL',
        costoUnitarioHistorico: 150.0,
        motivo: 'Compra de 2 docenas',
      ));

      final tequenosPost = await prodRepo.getProductoPorId(tequenosId);
      expect(tequenosPost!.stockActual, equals(24.0));

      final historial = await ajustesRepo.getAjustesPorInsumo(tequenosId);
      expect(historial.length, equals(1));
      expect(historial.first.cantidadIngresada, equals(2.0));
      expect(historial.first.unidadIngreso, equals('Docena'));
    });

    test('Validación de ciclos en Recetas (DFS)', () async {
      final recetasRepo = RecetasRepository();
      final prodRepo = ProductosRepository();

      final prodA = await prodRepo.insertProducto(Producto(nombre: 'Prod A', tipo: 'PRODUCTO'));
      final prodB = await prodRepo.insertProducto(Producto(nombre: 'Prod B', tipo: 'PRODUCTO'));

      // A contiene B
      await recetasRepo.guardarRecetaCompleta(prodA, [
        Receta(productoPadreId: prodA, insumoId: prodB, cantidadRequerida: 1),
      ]);

      // Intentar hacer que B contenga A (debe detectar ciclo)
      final hayCiclo = await recetasRepo.detectaCiclo(prodB, prodA);
      expect(hayCiclo, isTrue);

      expect(
        () async => await recetasRepo.guardarRecetaCompleta(prodB, [
          Receta(productoPadreId: prodB, insumoId: prodA, cantidadRequerida: 1),
        ]),
        throwsA(isA<Exception>()),
      );
    });
  });
}
