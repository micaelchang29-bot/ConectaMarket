import 'dart:async';
import 'dart:io';

/// Mensaje único para cualquier función que necesita internet.
const mensajeSinConexion =
    'Esta función necesita conexión a internet. Tus datos locales no se han tocado.';

const mensajeCredencialesIncorrectas = 'Correo o contraseña incorrectos.';

/// Indica si un error proviene de la falta de conexión.
bool esErrorDeConexion(Object error) {
  if (error is SocketException || error is TimeoutException) return true;
  final texto = error.toString().toLowerCase();
  const pistas = [
    'network-request-failed',
    'network error',
    'failed host lookup',
    'unable to resolve host',
    'connection refused',
    'connection reset',
    'connection closed',
    'software caused connection abort',
    'unavailable',
    'socketexception',
    'clientexception',
  ];
  return pistas.any(texto.contains);
}

/// Traduce el código de error de Firebase Auth a un mensaje para el usuario.
/// En el inicio de sesión no se revela si falló el correo o la contraseña.
String mensajeErrorAuth(String codigo, {required bool esRegistro}) {
  switch (codigo) {
    case 'network-request-failed':
      return mensajeSinConexion;
    case 'too-many-requests':
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    case 'operation-not-allowed':
      return 'El acceso con correo y contraseña no está habilitado. Contacta al administrador.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada.';
  }
  if (esRegistro) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Ese correo ya está registrado. Inicia sesión.';
      case 'invalid-email':
        return 'El correo no tiene un formato válido.';
      case 'weak-password':
        return 'La contraseña es muy débil: usa al menos 6 caracteres.';
    }
    return 'No se pudo crear la cuenta. Inténtalo de nuevo.';
  }
  switch (codigo) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'invalid-email':
    case 'invalid-password':
      return mensajeCredencialesIncorrectas;
  }
  return 'No se pudo iniciar sesión. Inténtalo de nuevo.';
}

/// Mensaje para un código HTTP de error del asistente.
String mensajeErrorAsistente(int status) {
  if (status == 401 || status == 403) {
    return 'El asistente no está disponible: la clave de acceso no es válida.';
  }
  if (status == 429) {
    return 'El asistente recibió demasiadas consultas. Espera un momento e inténtalo de nuevo.';
  }
  if (status >= 500) {
    return 'El servicio del asistente no responde en este momento. Inténtalo más tarde.';
  }
  return 'No se pudo obtener respuesta del asistente (código $status).';
}

/// Mensaje para mostrar a partir de cualquier error, sin texto técnico.
String mensajeAmigable(Object error, {String porDefecto = 'Ocurrió un error inesperado.'}) {
  if (esErrorDeConexion(error)) return mensajeSinConexion;
  final texto = error.toString();
  if (texto.startsWith('Exception: ')) return texto.substring(11);
  return texto.isEmpty ? porDefecto : texto;
}

/// Estado de la etiqueta de sincronización del dashboard.
class EtiquetaSync {
  final String texto;
  final bool sincronizado;
  const EtiquetaSync(this.texto, this.sincronizado);
}

EtiquetaSync estadoEtiquetaSync({required bool autenticado, DateTime? ultimoRespaldo}) {
  if (!autenticado || ultimoRespaldo == null) {
    return const EtiquetaSync('Sin sincronizar', false);
  }
  String dos(int n) => n.toString().padLeft(2, '0');
  final d = ultimoRespaldo;
  return EtiquetaSync('Synced · ${dos(d.day)}/${dos(d.month)} ${dos(d.hour)}:${dos(d.minute)}', true);
}
