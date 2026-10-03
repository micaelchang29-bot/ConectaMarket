import 'package:sqflite/sqflite.dart';
import '../repositories/database_helper.dart';

/// Resultado del backfill de bodega_id para una tabla puntual.
enum BodegaBackfillOutcome {
  /// Se corrió el UPDATE. [BodegaBackfillResult.filasActualizadas] puede ser
  /// 0 si no había filas NULL (caso idempotente / segunda corrida).
  completed,

  /// Se encontró al menos una fila con bodega_id distinto al de la sesión
  /// activa: evidencia de que el dispositivo tuvo otra cuenta antes. No se
  /// tocó nada en esta tabla; requiere revisión manual.
  ambiguous,

  /// Error inesperado (no relacionado a la ambigüedad de dueño) al procesar
  /// esta tabla puntual. Se aisla para que no bloquee a las demás.
  error,
}

class BodegaBackfillResult {
  final String tabla;
  final BodegaBackfillOutcome outcome;
  final int filasActualizadas;
  final String? bodegaIdAjenaDetectada;
  final String? error;

  const BodegaBackfillResult({
    required this.tabla,
    required this.outcome,
    this.filasActualizadas = 0,
    this.bodegaIdAjenaDetectada,
    this.error,
  });

  @override
  String toString() =>
      'BodegaBackfillResult(tabla: $tabla, outcome: $outcome, '
      'filasActualizadas: $filasActualizadas, '
      'bodegaIdAjenaDetectada: $bodegaIdAjenaDetectada, error: $error)';
}

/// Diagnóstico de solo lectura de una tabla, pensado para revisar a mano un
/// estado `ambiguous` (ver [BodegaBackfillService.inspeccionarTabla]).
class BodegaAmbiguityReport {
  final String tabla;

  /// Cantidad de filas con bodega_id NULL en esta tabla.
  final int filasNull;

  /// Cuántas filas tiene cada valor de bodega_id (no nulo) presente en la
  /// tabla. Si tiene más de una clave, esos son los dueños en conflicto que
  /// hicieron que el backfill marcara la tabla como ambigua.
  final Map<String, int> conteoPorBodegaId;

  const BodegaAmbiguityReport({
    required this.tabla,
    required this.filasNull,
    required this.conteoPorBodegaId,
  });

  /// Cuántos valores de bodega_id distintos (no nulos) conviven en la tabla.
  int get cantidadBodegaIdsDistintas => conteoPorBodegaId.length;

  @override
  String toString() =>
      'BodegaAmbiguityReport(tabla: $tabla, filasNull: $filasNull, '
      'conteoPorBodegaId: $conteoPorBodegaId)';
}

/// Backfillea bodega_id en las filas que quedaron en NULL antes de que el
/// estampado en el alta (ver product/provider/receipt_repository.dart)
/// existiera. No depende de Firebase/AuthService: recibe el uid ya resuelto,
/// para quedar testeable con una base SQLite en memoria sin inicializar
/// Firebase (igual que el resto de los tests de este repo). Quien la invoca
/// (main.dart) es responsable de detectar la sesión activa y pasar su uid.
///
/// Por tabla, antes de tocar nada:
///   - si existe una fila con bodega_id NOT NULL y distinto al uid recibido,
///     esa tabla se deja intacta (caso ambiguo: el dispositivo pudo haber
///     pertenecido a otra bodega antes). Las demás tablas se evalúan de
///     forma independiente.
///   - si no, `UPDATE <tabla> SET bodega_id = uid WHERE bodega_id IS NULL`.
///
/// Sin flag de "ya corrió": es naturalmente idempotente (una segunda corrida
/// sin filas NULL no modifica nada) y se autocura solo si alguien resuelve a
/// mano la ambigüedad de una corrida anterior.
class BodegaBackfillService {
  static const List<String> _tablas = ['providers', 'products', 'receipts'];

  /// Punto de entrada: corre el backfill de las 3 tablas para [bodegaId].
  /// No lanza — cualquier fallo queda reflejado como [BodegaBackfillOutcome.error]
  /// en el resultado de esa tabla puntual, nunca como excepción no capturada.
  Future<List<BodegaBackfillResult>> runForBodega(String bodegaId) async {
    if (bodegaId.isEmpty) return const [];

    try {
      final db = await DatabaseHelper.instance.database;
      final resultados = <BodegaBackfillResult>[];
      for (final tabla in _tablas) {
        resultados.add(await _backfillTabla(db, tabla, bodegaId));
      }
      return resultados;
    } catch (e) {
      // Defensa adicional: incluso un fallo fuera del loop por-tabla (p. ej.
      // no se pudo abrir la base) queda logueado y no se propaga.
      // ignore: avoid_print
      print('[BodegaBackfillService] Error inesperado al iniciar el backfill: $e');
      return const [];
    }
  }

  Future<BodegaBackfillResult> _backfillTabla(Database db, String tabla, String bodegaId) async {
    try {
      final ajena = await db.query(
        tabla,
        columns: ['bodega_id'],
        where: 'bodega_id IS NOT NULL AND bodega_id != ?',
        whereArgs: [bodegaId],
        limit: 1,
      );

      if (ajena.isNotEmpty) {
        final encontrada = ajena.first['bodega_id'] as String?;
        // ignore: avoid_print
        print(
          "[BodegaBackfillService] '$tabla' tiene filas con bodega_id='$encontrada', "
          "distinto de la sesión activa ('$bodegaId'). El dispositivo pudo haber "
          "pertenecido a otra bodega antes. Backfill de NULLs en '$tabla' PENDIENTE "
          "DE REVISIÓN MANUAL: no se autocompletó nada en esta tabla.",
        );
        return BodegaBackfillResult(
          tabla: tabla,
          outcome: BodegaBackfillOutcome.ambiguous,
          bodegaIdAjenaDetectada: encontrada,
        );
      }

      final filas = await db.update(
        tabla,
        {'bodega_id': bodegaId},
        where: 'bodega_id IS NULL',
      );

      return BodegaBackfillResult(
        tabla: tabla,
        outcome: BodegaBackfillOutcome.completed,
        filasActualizadas: filas,
      );
    } catch (e) {
      // ignore: avoid_print
      print("[BodegaBackfillService] Error inesperado al migrar '$tabla': $e");
      return BodegaBackfillResult(
        tabla: tabla,
        outcome: BodegaBackfillOutcome.error,
        error: e.toString(),
      );
    }
  }

  /// Herramienta de diagnóstico (H1): lista, para [tabla], cuántas filas
  /// tienen bodega_id NULL y qué valores de bodega_id conviven en ella (con
  /// cuántas filas cada uno). Es de **solo lectura** — no corrige ni decide
  /// nada. Pensada para cuando [runForBodega] reporta una tabla en
  /// `ambiguous`: ese caso no tiene (ni va a tener acá) resolución
  /// automática, porque decidir a quién pertenecen esas filas es una
  /// decisión de negocio que le corresponde a una persona, no al código.
  ///
  /// Uso esperado una vez detectada la ambigüedad:
  /// ```dart
  /// final reporte = await BodegaBackfillService().inspeccionarTabla('products');
  /// print(reporte); // o inspeccionarlo en un debugger / shell de sqlite3
  /// ```
  /// Con eso en mano, quien revisa decide y corre un UPDATE dirigido, por
  /// ejemplo:
  /// ```sql
  /// -- si se confirma que las filas de 'uid-viejo' son en realidad de la
  /// -- bodega actual:
  /// UPDATE products SET bodega_id = 'uid-actual' WHERE bodega_id = 'uid-viejo';
  /// ```
  /// Resuelto eso, la próxima sesión activa backfillea sola las NULL
  /// restantes — no hace falta volver a correr nada especial.
  Future<BodegaAmbiguityReport> inspeccionarTabla(String tabla) async {
    if (!_tablas.contains(tabla)) {
      throw ArgumentError.value(tabla, 'tabla', 'Debe ser una de: $_tablas');
    }

    final db = await DatabaseHelper.instance.database;

    final nulas = await db.query(tabla, columns: ['bodega_id'], where: 'bodega_id IS NULL');

    final filas = await db.rawQuery(
      'SELECT bodega_id, COUNT(*) as total FROM $tabla WHERE bodega_id IS NOT NULL GROUP BY bodega_id',
    );
    final conteo = <String, int>{
      for (final fila in filas) (fila['bodega_id'] as String): (fila['total'] as num).toInt(),
    };

    return BodegaAmbiguityReport(
      tabla: tabla,
      filasNull: nulas.length,
      conteoPorBodegaId: conteo,
    );
  }
}
