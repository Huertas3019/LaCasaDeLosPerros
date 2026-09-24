import '../core/database/database_helper.dart';
import '../models/turno.dart';

class ResumenTurno {
  final int turnoId;
  final double montoInicialEfectivo;
  final double ventasEfectivo;
  final double ventasTransferencia;
  final double gastosEfectivoCaja;
  final double gastosTransferenciaCaja;
  final double retirosEfectivoCaja;
  final double efectivoTeoricoEnCaja;
  final double transferenciasNetasBanco;
  final double totalRecaudadoTurno;

  ResumenTurno({
    required this.turnoId,
    required this.montoInicialEfectivo,
    required this.ventasEfectivo,
    required this.ventasTransferencia,
    required this.gastosEfectivoCaja,
    required this.gastosTransferenciaCaja,
    required this.retirosEfectivoCaja,
    required this.efectivoTeoricoEnCaja,
    required this.transferenciasNetasBanco,
    required this.totalRecaudadoTurno,
  });
}

class TurnosRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Turno?> getTurnoActivo() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'turnos',
      where: 'estado = ?',
      whereArgs: ['ABIERTO'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Turno.fromMap(maps.first);
    }
    return null;
  }

  Future<Turno> abrirTurno(double montoInicialEfectivo, {String? observaciones}) async {
    final db = await _dbHelper.database;
    
    // Verificar que no haya un turno abierto
    final activo = await getTurnoActivo();
    if (activo != null) {
      throw Exception('Ya existe un turno ABIERTO con ID #${activo.id}. Debe cerrarlo antes de abrir uno nuevo.');
    }

    final now = DateTime.now().toIso8601String();
    final nuevoTurno = Turno(
      fechaInicio: now,
      montoInicialEfectivo: montoInicialEfectivo,
      estado: 'ABIERTO',
      observaciones: observaciones,
    );

    final id = await db.insert('turnos', nuevoTurno.toMap());
    return Turno.fromMap({...nuevoTurno.toMap(), 'id': id});
  }

  Future<ResumenTurno> obtenerResumenTurno(int turnoId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT 
        t.id AS turno_id,
        t.monto_inicial_efectivo,
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_efectivo ELSE 0 END), 0) AS ventas_efectivo,
        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_transferencia ELSE 0 END), 0) AS ventas_transferencia,
        
        COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'EFECTIVO'), 0) AS gastos_efectivo_caja,
        COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'TRANSFERENCIA'), 0) AS gastos_transferencia_caja,
        
        COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'RETIRO_CAJA' AND g.medio_pago = 'EFECTIVO'), 0) AS retiros_efectivo_caja,

        (
          t.monto_inicial_efectivo + 
          COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_efectivo ELSE 0 END), 0) - 
          (
            COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'EFECTIVO'), 0) +
            COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'RETIRO_CAJA' AND g.medio_pago = 'EFECTIVO'), 0)
          )
        ) AS efectivo_teorico_en_caja,

        (
          COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.monto_transferencia ELSE 0 END), 0) - 
          COALESCE((SELECT SUM(g.monto) FROM gastos g WHERE g.turno_id = t.id AND g.tipo_transaccion = 'CAJA_TURNO' AND g.medio_pago = 'TRANSFERENCIA'), 0)
        ) AS transferencias_netas_banco,

        COALESCE(SUM(CASE WHEN v.estado = 'COMPLETADA' THEN v.total_venta ELSE 0 END), 0) AS total_recaudado_turno

      FROM turnos t
      LEFT JOIN ventas v ON v.turno_id = t.id
      WHERE t.id = ?
      GROUP BY t.id, t.monto_inicial_efectivo;
    ''', [turnoId]);

    if (maps.isEmpty) {
      throw Exception('No se encontró el turno ID #$turnoId');
    }

    final m = maps.first;
    return ResumenTurno(
      turnoId: m['turno_id'] as int,
      montoInicialEfectivo: (m['monto_inicial_efectivo'] as num).toDouble(),
      ventasEfectivo: (m['ventas_efectivo'] as num).toDouble(),
      ventasTransferencia: (m['ventas_transferencia'] as num).toDouble(),
      gastosEfectivoCaja: (m['gastos_efectivo_caja'] as num).toDouble(),
      gastosTransferenciaCaja: (m['gastos_transferencia_caja'] as num).toDouble(),
      retirosEfectivoCaja: (m['retiros_efectivo_caja'] as num).toDouble(),
      efectivoTeoricoEnCaja: (m['efectivo_teorico_en_caja'] as num).toDouble(),
      transferenciasNetasBanco: (m['transferencias_netas_banco'] as num).toDouble(),
      totalRecaudadoTurno: (m['total_recaudado_turno'] as num).toDouble(),
    );
  }

  Future<void> cerrarTurno({
    required int turnoId,
    required double efectivoRealCierre,
    required double transferenciaRealCierre,
    String? observaciones,
  }) async {
    final db = await _dbHelper.database;
    final resumen = await obtenerResumenTurno(turnoId);

    double difEfectivo = efectivoRealCierre - resumen.efectivoTeoricoEnCaja;
    double difTransferencia = transferenciaRealCierre - resumen.transferenciasNetasBanco;

    final now = DateTime.now().toIso8601String();

    await db.update(
      'turnos',
      {
        'fecha_fin': now,
        'efectivo_real_cierre': efectivoRealCierre,
        'transferencia_real_cierre': transferenciaRealCierre,
        'efectivo_esperado_cierre': resumen.efectivoTeoricoEnCaja,
        'transferencia_esperada_cierre': resumen.transferenciasNetasBanco,
        'diferencia_efectivo': difEfectivo,
        'diferencia_transferencia': difTransferencia,
        'estado': 'CERRADO',
        'observaciones': observaciones,
      },
      where: 'id = ?',
      whereArgs: [turnoId],
    );
  }

  Future<List<Turno>> getHistorialTurnos({int limit = 50}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'turnos',
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map((m) => Turno.fromMap(m)).toList();
  }
}
