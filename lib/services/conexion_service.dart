import 'dart:async';
import 'dart:io';

/// Comprobación rápida de conexión a internet (resolución DNS de [host]).
class ConexionService {
  ConexionService._();

  /// Se puede reemplazar en pruebas.
  static Future<bool> Function({String host}) verificador = _resolver;

  static Future<bool> hayConexion({String host = 'firestore.googleapis.com'}) =>
      verificador(host: host);

  static Future<bool> _resolver({String host = 'firestore.googleapis.com'}) async {
    try {
      final r = await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
