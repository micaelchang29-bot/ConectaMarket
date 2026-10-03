import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/services/bodega_backfill_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// Backfill de bodega_id sobre el historial que quedó en NULL antes del
/// estampado en el alta. No depende de Firebase/AuthService: se le pasa el
/// uid ya resuelto directamente.
void main() {
  late BodegaBackfillService service;

  setUp(() async {
    await setUpTestDatabase();
    service = BodegaBackfillService();
  });

  tearDown(tearDownTestDatabase);

  const tablas = ['providers', 'products', 'receipts'];

  /// Inserta una fila mínima en [tabla] con el [bodegaId] dado (o NULL).
  Future<void> insertarFila(String tabla, String id, String? bodegaId) async {
    final db = await DatabaseHelper.instance.database;
    switch (tabla) {
      case 'providers':
        await db.insert('providers', {'id': id, 'nombre': 'Proveedor $id', 'bodega_id': bodegaId});
      case 'products':
        await db.insert('products', {'id': id, 'nombre': 'Producto $id', 'bodega_id': bodegaId});
      case 'receipts':
        await db.insert('receipts', {
          'id': id,
          'provider_id': null,
          'fecha': '2026-09-28',
          'total': 10.0,
          'tipomovimiento': 0,
          'bodega_id': bodegaId,
        });
    }
  }

  Future<String?> bodegaIdDe(String tabla, String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(tabla, columns: ['bodega_id'], where: 'id = ?', whereArgs: [id]);
    return rows.first['bodega_id'] as String?;
  }

  for (final tabla in tablas) {
    group(tabla, () {
      test('(a) filas NULL sin ninguna otra bodega_id previa -> backfillea correctamente', () async {
        await insertarFila(tabla, '${tabla}_1', null);
        await insertarFila(tabla, '${tabla}_2', null);

        final resultados = await service.runForBodega('uid-A');
        final propio = resultados.firstWhere((r) => r.tabla == tabla);

        expect(propio.outcome, BodegaBackfillOutcome.completed);
        expect(propio.filasActualizadas, 2);
        expect(await bodegaIdDe(tabla, '${tabla}_1'), 'uid-A');
        expect(await bodegaIdDe(tabla, '${tabla}_2'), 'uid-A');
      });

      test('(b) ya existe una bodega_id distinta de currentUid -> aborta esa tabla sin modificar nada', () async {
        await insertarFila(tabla, '${tabla}_viejo', 'uid-B'); // de otra cuenta
        await insertarFila(tabla, '${tabla}_huerfano', null); // huérfana, sin dueño

        final resultados = await service.runForBodega('uid-A');
        final propio = resultados.firstWhere((r) => r.tabla == tabla);

        expect(propio.outcome, BodegaBackfillOutcome.ambiguous);
        expect(propio.bodegaIdAjenaDetectada, 'uid-B');
        // No se tocó nada: ni la fila ajena ni la huérfana.
        expect(await bodegaIdDe(tabla, '${tabla}_viejo'), 'uid-B');
        expect(await bodegaIdDe(tabla, '${tabla}_huerfano'), isNull);
      });

      test('(c) tabla ya sin filas NULL -> no-op en una segunda corrida', () async {
        await insertarFila(tabla, '${tabla}_1', null);
        await service.runForBodega('uid-A');

        // Segunda corrida: ya no quedan NULL, no hay flag de "ya corrió".
        final resultados = await service.runForBodega('uid-A');
        final propio = resultados.firstWhere((r) => r.tabla == tabla);

        expect(propio.outcome, BodegaBackfillOutcome.completed);
        expect(propio.filasActualizadas, 0);
        expect(await bodegaIdDe(tabla, '${tabla}_1'), 'uid-A'); // sigue como quedó
      });
    });
  }

  test('las 3 tablas se evalúan de forma independiente: una tabla ambigua no bloquea a las demás', () async {
    // products queda ambigua; providers y receipts tienen huérfanas limpias.
    await insertarFila('products', 'p_viejo', 'uid-B');
    await insertarFila('products', 'p_huerfano', null);
    await insertarFila('providers', 'prov_huerfano', null);
    await insertarFila('receipts', 'rec_huerfano', null);

    final resultados = await service.runForBodega('uid-A');
    final porTabla = {for (final r in resultados) r.tabla: r};

    expect(porTabla['products']!.outcome, BodegaBackfillOutcome.ambiguous);
    expect(porTabla['providers']!.outcome, BodegaBackfillOutcome.completed);
    expect(porTabla['receipts']!.outcome, BodegaBackfillOutcome.completed);

    expect(await bodegaIdDe('products', 'p_huerfano'), isNull); // products quedó intacta
    expect(await bodegaIdDe('providers', 'prov_huerfano'), 'uid-A');
    expect(await bodegaIdDe('receipts', 'rec_huerfano'), 'uid-A');
  });

  test('un error inesperado en una tabla no bloquea a las demás (aislamiento por tabla)', () async {
    await insertarFila('providers', 'prov_huerfano', null);
    await insertarFila('products', 'p_huerfano', null);
    await insertarFila('receipts', 'rec_huerfano', null);

    // Se corrompe 'providers' a propósito para forzar un error real de
    // SQLite (no el caso de ambigüedad) y verificar que no frena el loop.
    final db = await DatabaseHelper.instance.database;
    await db.execute('DROP TABLE providers');

    final resultados = await service.runForBodega('uid-A');
    final porTabla = {for (final r in resultados) r.tabla: r};

    expect(porTabla['providers']!.outcome, BodegaBackfillOutcome.error);
    expect(porTabla['providers']!.error, isNotNull);
    // Las otras dos tablas se procesaron igual, sin verse afectadas.
    expect(porTabla['products']!.outcome, BodegaBackfillOutcome.completed);
    expect(porTabla['receipts']!.outcome, BodegaBackfillOutcome.completed);
    expect(await bodegaIdDe('products', 'p_huerfano'), 'uid-A');
    expect(await bodegaIdDe('receipts', 'rec_huerfano'), 'uid-A');
  });

  test('un bodegaId vacío no hace nada (sin sesión real a la que asignar)', () async {
    await insertarFila('products', 'p1', null);

    final resultados = await service.runForBodega('');

    expect(resultados, isEmpty);
    expect(await bodegaIdDe('products', 'p1'), isNull);
  });

  group('H1 - inspeccionarTabla (diagnostico de solo lectura de un caso ambiguous)', () {
    test('refleja correctamente un caso ambiguous fabricado: NULLs y los dueños en conflicto', () async {
      // Fabrica exactamente el escenario que deja a una tabla en estado
      // ambiguous: dos bodega_id ajenas entre si, mas filas huerfanas (NULL).
      await insertarFila('products', 'p_uidA_1', 'uid-A');
      await insertarFila('products', 'p_uidA_2', 'uid-A');
      await insertarFila('products', 'p_uidB_1', 'uid-B');
      await insertarFila('products', 'p_uidB_2', 'uid-B');
      await insertarFila('products', 'p_uidB_3', 'uid-B');
      await insertarFila('products', 'p_huerfano_1', null);

      final reporte = await service.inspeccionarTabla('products');

      expect(reporte.tabla, 'products');
      expect(reporte.filasNull, 1);
      expect(reporte.conteoPorBodegaId, {'uid-A': 2, 'uid-B': 3});
      expect(reporte.cantidadBodegaIdsDistintas, 2);
    });

    test('una tabla sin conflicto (una sola bodega_id, sin NULLs) lo refleja también', () async {
      await insertarFila('providers', 'prov1', 'uid-A');
      await insertarFila('providers', 'prov2', 'uid-A');

      final reporte = await service.inspeccionarTabla('providers');

      expect(reporte.filasNull, 0);
      expect(reporte.conteoPorBodegaId, {'uid-A': 2});
      expect(reporte.cantidadBodegaIdsDistintas, 1);
    });

    test('una tabla desconocida lanza ArgumentError en vez de ejecutar SQL con un nombre arbitrario', () async {
      expect(() => service.inspeccionarTabla('DROP TABLE products; --'), throwsArgumentError);
    });
  });
}
