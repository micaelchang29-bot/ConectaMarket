import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/repositories/provider_repository.dart';
import 'package:conectamarket/services/provider_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// CP006: el RUC debe tener exactamente 11 dígitos numéricos.
void main() {
  late ProviderRepository providerRepo;

  setUp(() async {
    await setUpTestDatabase();
    providerRepo = ProviderRepository();
  });

  tearDown(tearDownTestDatabase);

  Provider proveedorCon(String? ruc) => Provider(
        id: 'PROV001',
        nombre: 'Distribuidora Lima',
        ruc: ruc,
        telefono: '987654321',
      );

  final Matcher rucInvalido = throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'mensaje',
        contains('El RUC debe tener exactamente 11 dígitos numéricos'),
      ));

  test('un RUC de 5 dígitos se rechaza aunque el resto sea válido', () async {
    await expectLater(ProviderService().saveProvider(proveedorCon('12345')), rucInvalido);
    expect(await providerRepo.getProviderById('PROV001'), isNull);
  });

  test('un RUC de 11 dígitos se guarda', () async {
    await ProviderService().saveProvider(proveedorCon('20123456789'));

    final guardado = await providerRepo.getProviderById('PROV001');
    expect(guardado, isNotNull);
    expect(guardado!.ruc, '20123456789');
  });

  test('un RUC de 11 caracteres con letras se rechaza', () async {
    await expectLater(ProviderService().saveProvider(proveedorCon('2012345678A')), rucInvalido);
    expect(await providerRepo.getProviderById('PROV001'), isNull);
  });

  test('un RUC de 12 dígitos se rechaza', () async {
    await expectLater(ProviderService().saveProvider(proveedorCon('201234567890')), rucInvalido);
  });
}
