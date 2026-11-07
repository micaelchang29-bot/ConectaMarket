/// Rango de fechas (inclusive) de un periodo del balance.
class RangoPeriodo {
  final DateTime inicio;
  final DateTime fin;
  const RangoPeriodo(this.inicio, this.fin);

  // En UTC para que un cambio de horario no altere la cuenta de días
  int get dias =>
      DateTime.utc(fin.year, fin.month, fin.day)
          .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
          .inDays +
      1;
}

/// Número de trimestre calendario (1..4) de un mes.
int trimestreDeMes(int mes) => ((mes - 1) ~/ 3) + 1;

/// Rango del mes o del trimestre calendario que contiene al mes indicado.
RangoPeriodo rangoPeriodo(int anio, int mes, {bool trimestral = false}) {
  if (!trimestral) {
    return RangoPeriodo(DateTime(anio, mes, 1), DateTime(anio, mes + 1, 0));
  }
  final mesInicio = (trimestreDeMes(mes) - 1) * 3 + 1;
  return RangoPeriodo(DateTime(anio, mesInicio, 1), DateTime(anio, mesInicio + 3, 0));
}

const _mesesAbrev = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

/// Ej.: "Trimestre 2 (Abr–Jun) 2026".
String etiquetaTrimestre(int anio, int mes) {
  final t = trimestreDeMes(mes);
  final ini = (t - 1) * 3;
  return 'Trimestre $t (${_mesesAbrev[ini]}–${_mesesAbrev[ini + 2]}) $anio';
}
