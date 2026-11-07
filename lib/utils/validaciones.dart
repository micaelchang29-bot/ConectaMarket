/// Reglas de validación de formularios y servicios, sin dependencias de UI.
library;

/// Error de negocio con un mensaje listo para mostrar al usuario.
/// [campo] indica qué campo del formulario debe marcarse (opcional).
class AppException implements Exception {
  final String message;
  final String? campo;

  const AppException(this.message, {this.campo});

  @override
  String toString() => message;
}

/// Convierte un texto a número aceptando coma o punto como separador decimal.
/// Devuelve null si el texto está vacío o no es un número válido.
double? parseDecimal(String? texto) {
  if (texto == null) return null;
  final limpio = texto.trim().replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(limpio) &&
      !RegExp(r'^-?\.\d+$').hasMatch(limpio)) {
    return null;
  }
  return double.tryParse(limpio);
}

/// Muestra una cantidad sin decimales innecesarios: 2.0 -> "2", 2.5 -> "2.5".
String formatoCantidad(num valor) {
  final d = valor.toDouble();
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String? validarObligatorio(String? v, String nombreCampo) {
  if (v == null || v.trim().isEmpty) return '$nombreCampo es obligatorio';
  return null;
}

String? validarPrecio(String? v) {
  if (v == null || v.trim().isEmpty) return 'El precio es obligatorio';
  final n = parseDecimal(v);
  if (n == null) return 'El precio debe ser un número válido';
  if (n <= 0) return 'El precio debe ser mayor que 0';
  return null;
}

String? validarStock(String? v) {
  if (v == null || v.trim().isEmpty) return 'El stock es obligatorio';
  final n = parseDecimal(v);
  if (n == null) return 'El stock debe ser un número válido';
  if (n < 0) return 'El stock no puede ser negativo';
  return null;
}

String? validarUmbral(String? v) {
  if (v == null || v.trim().isEmpty) return 'El umbral es obligatorio';
  final n = int.tryParse(v.trim());
  if (n == null) return 'El umbral debe ser un número entero';
  if (n < 0) return 'El umbral no puede ser negativo';
  return null;
}

const prefijosRucValidos = ['10', '15', '17', '20'];

/// Formato del RUC (no valida el dígito verificador).
/// Con [obligatorio] en false, un valor vacío es válido.
String? validarRuc(String? v, {bool obligatorio = true}) {
  final ruc = v?.trim() ?? '';
  if (ruc.isEmpty) return obligatorio ? 'El RUC es obligatorio' : null;
  if (!RegExp(r'^\d{11}$').hasMatch(ruc)) {
    return 'El RUC debe tener exactamente 11 dígitos numéricos';
  }
  if (!prefijosRucValidos.contains(ruc.substring(0, 2))) {
    return 'El RUC debe empezar con 10, 15, 17 o 20';
  }
  return null;
}

/// Teléfono: al menos 9 dígitos. Se permiten espacios, guiones, paréntesis y "+".
String? validarTelefono(String? v, {bool obligatorio = true}) {
  final tel = v?.trim() ?? '';
  if (tel.isEmpty) return obligatorio ? 'El teléfono es obligatorio' : null;
  if (!RegExp(r'^[\d\s()+\-]+$').hasMatch(tel)) {
    return 'El teléfono solo puede contener números';
  }
  final digitos = tel.replaceAll(RegExp(r'\D'), '');
  if (digitos.length < 9) return 'El teléfono debe tener al menos 9 dígitos';
  return null;
}

/// Clave para comparar nombres y SKU sin distinguir mayúsculas, tildes ni espacios.
String normalizarClave(String texto) {
  const conTilde = 'áàäâéèëêíìïîóòöôúùüûñ';
  const sinTilde = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final ch in texto.toLowerCase().split('')) {
    final i = conTilde.indexOf(ch);
    buffer.write(i >= 0 ? sinTilde[i] : ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), '');
}
