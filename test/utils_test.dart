import 'dart:async';
import 'dart:io';

import 'package:conectamarket/utils/mensajes_error.dart';
import 'package:conectamarket/utils/periodos.dart';
import 'package:conectamarket/utils/validaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Precio (CP-01-01, CP-01-02)', () {
    test('acepta 4.50 y 4,50', () {
      expect(validarPrecio('4.50'), isNull);
      expect(validarPrecio('4,50'), isNull);
      expect(parseDecimal('4,50'), 4.5);
    });
    test('rechaza vacío, negativo, cero y texto', () {
      expect(validarPrecio(''), 'El precio es obligatorio');
      expect(validarPrecio(null), 'El precio es obligatorio');
      expect(validarPrecio('-1'), 'El precio debe ser mayor que 0');
      expect(validarPrecio('0'), 'El precio debe ser mayor que 0');
      expect(validarPrecio('abc'), 'El precio debe ser un número válido');
      expect(validarPrecio('4.5.0'), 'El precio debe ser un número válido');
    });
  });

  group('Stock y umbral', () {
    test('stock', () {
      expect(validarStock('50'), isNull);
      expect(validarStock('0'), isNull);
      expect(validarStock('-3'), 'El stock no puede ser negativo');
      expect(validarStock('diez'), 'El stock debe ser un número válido');
      expect(validarStock(''), 'El stock es obligatorio');
    });
    test('umbral', () {
      expect(validarUmbral('5'), isNull);
      expect(validarUmbral('2.5'), isNotNull);
      expect(validarUmbral('-1'), isNotNull);
    });
  });

  group('RUC (CP-03-01, CP-03-02)', () {
    test('acepta el RUC del caso de prueba sin validar dígito verificador', () {
      expect(validarRuc('20512345678'), isNull);
    });
    test('acepta los prefijos 10, 15, 17 y 20', () {
      for (final pre in ['10', '15', '17', '20']) {
        expect(validarRuc('${pre}123456789'), isNull, reason: pre);
      }
    });
    test('rechaza 12345, letras, prefijo inválido y vacío', () {
      expect(validarRuc('12345'), 'El RUC debe tener exactamente 11 dígitos numéricos');
      expect(validarRuc('2051234567A'), 'El RUC debe tener exactamente 11 dígitos numéricos');
      expect(validarRuc('30512345678'), 'El RUC debe empezar con 10, 15, 17 o 20');
      expect(validarRuc(''), 'El RUC es obligatorio');
      expect(validarRuc('', obligatorio: false), isNull);
    });
  });

  group('Teléfono (al menos 9 dígitos)', () {
    test('acepta celular, fijo y con prefijo internacional', () {
      expect(validarTelefono('987654321'), isNull);
      expect(validarTelefono('014567890'), isNull);
      expect(validarTelefono('+51 987 654 321'), isNull);
    });
    test('rechaza 8 dígitos, vacío y letras', () {
      expect(validarTelefono('98765432'), 'El teléfono debe tener al menos 9 dígitos');
      expect(validarTelefono(''), 'El teléfono es obligatorio');
      expect(validarTelefono('98765432a'), 'El teléfono solo puede contener números');
    });
  });

  test('normalizarClave ignora mayúsculas, tildes y espacios', () {
    expect(normalizarClave('Arroz Costeño 1kg'), normalizarClave('arroz  costeno 1KG'));
    expect(normalizarClave('Azúcar'), normalizarClave('AZUCAR'));
    expect(normalizarClave('Arroz'), isNot(normalizarClave('Arroz 5kg')));
  });

  test('formatoCantidad', () {
    expect(formatoCantidad(2.0), '2');
    expect(formatoCantidad(2.5), '2.5');
  });

  group('Mensajes de Firebase Auth (CP-18-02)', () {
    test('el login no revela qué campo falló', () {
      for (final c in ['user-not-found', 'wrong-password', 'invalid-credential', 'invalid-email']) {
        expect(mensajeErrorAuth(c, esRegistro: false), mensajeCredencialesIncorrectas, reason: c);
      }
    });
    test('registro y otros códigos', () {
      expect(mensajeErrorAuth('email-already-in-use', esRegistro: true), contains('ya está registrado'));
      expect(mensajeErrorAuth('weak-password', esRegistro: true), contains('6 caracteres'));
      expect(mensajeErrorAuth('invalid-email', esRegistro: true), contains('formato'));
      expect(mensajeErrorAuth('network-request-failed', esRegistro: false), mensajeSinConexion);
      expect(mensajeErrorAuth('too-many-requests', esRegistro: false), contains('Demasiados intentos'));
      expect(mensajeErrorAuth('operation-not-allowed', esRegistro: true), contains('no está habilitado'));
      expect(mensajeErrorAuth('algo-raro', esRegistro: false), isNot(contains('algo-raro')));
    });
  });

  group('Sin conexión (CP-05-02, CP-21-02)', () {
    test('detecta errores de red', () {
      expect(esErrorDeConexion(const SocketException('Failed host lookup')), isTrue);
      expect(esErrorDeConexion(TimeoutException('t')), isTrue);
      expect(esErrorDeConexion(Exception('[firebase_auth/network-request-failed]')), isTrue);
      expect(esErrorDeConexion(Exception('[cloud_firestore/unavailable] offline')), isTrue);
      expect(esErrorDeConexion(Exception('otra cosa')), isFalse);
    });
    test('mensajeAmigable no muestra texto técnico', () {
      expect(mensajeAmigable(const SocketException('x')), mensajeSinConexion);
      expect(mensajeAmigable(Exception('Stock insuficiente')), 'Stock insuficiente');
      expect(mensajeAmigable(const AppException('Hola')), 'Hola');
    });
    test('errores HTTP del asistente', () {
      expect(mensajeErrorAsistente(401), contains('clave'));
      expect(mensajeErrorAsistente(429), contains('demasiadas consultas'));
      expect(mensajeErrorAsistente(503), contains('no responde'));
    });
  });

  group('Etiqueta de sincronización (0002205)', () {
    test('invitado o sin respaldo: gris', () {
      final a = estadoEtiquetaSync(autenticado: false, ultimoRespaldo: DateTime(2026, 11, 6));
      expect(a.sincronizado, isFalse);
      expect(a.texto, 'Sin sincronizar');
      expect(estadoEtiquetaSync(autenticado: true).sincronizado, isFalse);
    });
    test('con respaldo: verde con fecha y hora', () {
      final e = estadoEtiquetaSync(autenticado: true, ultimoRespaldo: DateTime(2026, 11, 6, 9, 5));
      expect(e.sincronizado, isTrue);
      expect(e.texto, 'Synced · 06/11 09:05');
    });
  });

  group('Periodos del balance (CP-15-02)', () {
    test('mes', () {
      final r = rangoPeriodo(2026, 2);
      expect(r.inicio, DateTime(2026, 2, 1));
      expect(r.fin, DateTime(2026, 2, 28));
      expect(r.dias, 28);
    });
    test('trimestre calendario del mes', () {
      final r = rangoPeriodo(2026, 11, trimestral: true);
      expect(r.inicio, DateTime(2026, 10, 1));
      expect(r.fin, DateTime(2026, 12, 31));
      expect(r.dias, 92);
      expect(rangoPeriodo(2026, 1, trimestral: true).fin, DateTime(2026, 3, 31));
      expect(etiquetaTrimestre(2026, 5), 'Trimestre 2 (Abr–Jun) 2026');
    });
  });
}
