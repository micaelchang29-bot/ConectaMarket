import 'dart:io';

import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/providers_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/dashboard_service.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:conectamarket/services/provider_service.dart';
import 'package:conectamarket/services/receipt_service.dart';
import 'package:conectamarket/utils/validaciones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

Matcher appError(Object mensaje, {String? campo}) => isA<AppException>()
    .having((e) => e.message, 'message', mensaje)
    .having((e) => e.campo, 'campo', campo);

void main() {
  setUp(abrirBaseDePrueba);
  tearDown(cerrarBaseDePrueba);

  group('Modelo y migración', () {
    test('Product ida y vuelta con precio', () {
      final prod = Product(id: 'A1', nombre: 'Arroz', stock: 5, umbralAlerta: 3, precio: 4.5);
      final back = Product.fromMap(prod.toMap());
      expect(back.precio, 4.5);
      expect(back.stock, 5);
      // Filas antiguas sin precio y con enteros
      final viejo = Product.fromMap({'id': 'B', 'nombre': 'B', 'stock': 3, 'umbralAlerta': 1});
      expect(viejo.precio, 0);
      expect(viejo.stock, 3.0);
    });

    test('migración v4 a v5 conserva los datos y agrega precio', () async {
      await DatabaseHelper.resetForTests();
      final dir = await Directory.systemTemp.createTemp('cm_mig');
      final ruta = p.join(dir.path, 'v4.db');
      final v4 = await openDatabase(ruta, version: 4, onCreate: (db, _) async {
        await db.execute('CREATE TABLE providers (id TEXT PRIMARY KEY, nombre TEXT NOT NULL, ruc TEXT, telefono TEXT)');
        await db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, nombre TEXT NOT NULL, stock REAL DEFAULT 0, umbralAlerta INTEGER DEFAULT 5)');
        await db.execute("CREATE TABLE receipts (id TEXT PRIMARY KEY, provider_id TEXT NULL, fecha TEXT, total REAL, tipomovimiento INTEGER DEFAULT 0, synced INTEGER DEFAULT 0, serie TEXT DEFAULT 'B001')");
        await db.execute('CREATE TABLE receipt_items (id TEXT PRIMARY KEY, receipt_id TEXT, product_id TEXT, cantidad REAL, costoUnitario REAL)');
      });
      await v4.insert('products', {'id': 'P1', 'nombre': 'Leche', 'stock': 7, 'umbralAlerta': 2});
      await v4.close();

      await DatabaseHelper.resetForTests(path: ruta);
      final db = await DatabaseHelper.instance.database;
      expect(await db.getVersion(), 5);
      final filas = await db.query('products');
      expect(filas.single['nombre'], 'Leche');
      expect(filas.single['stock'], 7);
      expect(filas.single['precio'], 0);
      await DatabaseHelper.resetForTests();
      await dir.delete(recursive: true);
    });
  });

  group('Productos (CP-01, CP-04, 0002262)', () {
    test('alta con precio y edición de 4.50 a 4.80', () async {
      await crearProducto('ARZ1', 'Arroz Costeño 1kg', stock: 50, precio: 4.5);
      await ProductService().saveProduct(
        Product(id: 'ARZ1', nombre: 'Arroz Costeño 1kg', stock: 50, precio: 4.8),
      );
      final lista = ProductService().cachedProducts!;
      expect(lista.single.precio, 4.8);
    });

    test('rechaza precio 0 o negativo y stock negativo', () async {
      expect(
        () => ProductService().saveProduct(Product(id: 'X', nombre: 'Arroz', stock: 10, precio: 0), esNuevo: true),
        throwsA(appError('El precio debe ser mayor que 0', campo: 'precio')),
      );
      expect(
        () => ProductService().saveProduct(Product(id: 'X', nombre: 'Arroz', stock: -1, precio: 2), esNuevo: true),
        throwsA(appError('El stock no puede ser negativo', campo: 'stock')),
      );
    });

    test('SKU y nombre únicos, sin distinguir mayúsculas, tildes ni espacios', () async {
      await crearProducto('ARZ1', 'Arroz Costeño 1kg');
      expect(() => crearProducto('arz1', 'Otro'), throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'sku')));
      expect(() => crearProducto('ARZ2', 'arroz  costeno 1KG'),
          throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'nombre')));
      // Nombre igual al SKU de otro, y SKU igual al nombre de otro
      expect(() => crearProducto('ZZ', 'arz1'), throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'nombre')));
      expect(() => crearProducto('Arroz Costeño 1kg', 'Nuevo'),
          throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'sku')));
    });

    test('al editar, el producto no choca consigo mismo', () async {
      await crearProducto('ARZ1', 'Arroz Costeño 1kg', precio: 4.5);
      await ProductService().saveProduct(Product(id: 'ARZ1', nombre: 'ARROZ COSTEÑO 1KG', precio: 5));
      expect(ProductService().cachedProducts!.single.nombre, 'ARROZ COSTEÑO 1KG');
    });

    test('no se elimina un producto con movimientos (CP-04-02)', () async {
      await crearProducto('ARZ1', 'Arroz', stock: 100);
      for (var i = 0; i < 12; i++) {
        await registrarMovimiento([('ARZ1', 1)]);
      }
      expect(
        () => ProductService().deleteProduct('ARZ1'),
        throwsA(appError('No se puede eliminar el producto: tiene 12 movimientos asociados.')),
      );
      expect(ProductService().cachedProducts!.length, 1);
    });

    test('se elimina un producto sin movimientos', () async {
      await crearProducto('ARZ1', 'Arroz');
      await ProductService().deleteProduct('ARZ1');
      expect(ProductService().cachedProducts, isEmpty);
    });
  });

  group('Proveedores (CP-03, 0002246, 0002795, 0002796)', () {
    Provider prov(String id, {String nombre = 'Distribuidora Lima SAC', String? ruc = '20512345678', String? tel = '987654321'}) =>
        Provider(id: id, nombre: nombre, ruc: ruc, telefono: tel);

    test('registra el proveedor del caso de prueba', () async {
      await ProviderService().saveProvider(prov('P1'));
      expect(ProviderService().cachedProviders.single.ruc, '20512345678');
    });

    test('rechaza RUC de 5 dígitos, prefijo inválido y teléfono corto', () async {
      expect(() => ProviderService().saveProvider(prov('P1', ruc: '12345')),
          throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'ruc')));
      expect(() => ProviderService().saveProvider(prov('P1', ruc: '33512345678')),
          throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'ruc')));
      expect(() => ProviderService().saveProvider(prov('P1', tel: '98765432')),
          throwsA(isA<AppException>().having((e) => e.campo, 'campo', 'telefono')));
    });

    test('RUC único entre proveedores, excepto el propio al editar', () async {
      await ProviderService().saveProvider(prov('P1'));
      expect(() => ProviderService().saveProvider(prov('P2', nombre: 'Otro')),
          throwsA(isA<AppException>().having((e) => e.message, 'message', contains('ya está registrado'))));
      await ProviderService().saveProvider(prov('P1', nombre: 'Distribuidora Lima S.A.C.'));
      expect(ProviderService().cachedProviders.single.nombre, 'Distribuidora Lima S.A.C.');
    });

    test('no se elimina un proveedor con comprobantes (CP-04-02)', () async {
      await ProviderService().saveProvider(prov('P1'));
      await crearProducto('A', 'Arroz');
      await registrarMovimiento([('A', 5)], compra: true, providerId: 'P1');
      expect(() => ProviderService().removeProvider('P1'),
          throwsA(appError('No se puede eliminar el proveedor: tiene 1 comprobante asociado.')));
      await ProviderService().saveProvider(prov('P2', nombre: 'Sin compras', ruc: '10123456789'));
      await ProviderService().removeProvider('P2');
      expect(ProviderService().cachedProviders.length, 1);
    });
  });

  group('Stock de comprobantes (CP-02, 0002244, 0002245, 0002277, 0002263, 0002782)', () {
    test('venta descuenta y compra suma (CP-02-01)', () async {
      await crearProducto('A', 'Arroz Costeño 1kg', stock: 50);
      await registrarMovimiento([('A', 3)]);
      expect(await stockDe('A'), 47);
      await registrarMovimiento([('A', 10)], compra: true);
      expect(await stockDe('A'), 57);
    });

    test('venta mayor al stock se rechaza sin tocar nada (CP-02-02)', () async {
      await crearProducto('A', 'Arroz', stock: 2);
      expect(() => registrarMovimiento([('A', 5)], id: 'R1'),
          throwsA(appError('Stock insuficiente para Arroz: disponible 2, solicitado 5.')));
      expect(await stockDe('A'), 2);
      final db = await DatabaseHelper.instance.database;
      expect(await db.query('receipts'), isEmpty);
    });

    test('dos líneas del mismo producto suman lo solicitado', () async {
      await crearProducto('A', 'Arroz', stock: 5);
      expect(() => registrarMovimiento([('A', 3), ('A', 3)]),
          throwsA(appError('Stock insuficiente para Arroz: disponible 5, solicitado 6.')));
      expect(await stockDe('A'), 5);
    });

    test('cantidad 0 o negativa se rechaza', () async {
      await crearProducto('A', 'Arroz', stock: 5);
      expect(() => registrarMovimiento([('A', -2)]), throwsA(isA<AppException>()));
      expect(await stockDe('A'), 5);
    });

    test('editar revierte el efecto anterior antes de aplicar el nuevo', () async {
      await crearProducto('A', 'Arroz', stock: 10);
      await registrarMovimiento([('A', 4)], id: 'R1');
      expect(await stockDe('A'), 6);
      // Misma venta editada a 7 unidades: 10 - 7 = 3 (no 6 - 7)
      await registrarMovimiento([('A', 7)], id: 'R1');
      expect(await stockDe('A'), 3);
      final items = await ReceiptRepository().getItemsByReceiptId('R1');
      expect(items.single.cantidad, 7);
      // Editada a 11: supera lo disponible (10) y no cambia nada
      expect(() => registrarMovimiento([('A', 11)], id: 'R1'),
          throwsA(appError('Stock insuficiente para Arroz: disponible 10, solicitado 11.')));
      expect(await stockDe('A'), 3);
    });

    test('editar una compra que ya se vendió no deja stock negativo', () async {
      await crearProducto('A', 'Arroz', stock: 0);
      await registrarMovimiento([('A', 10)], id: 'C1', compra: true);
      await registrarMovimiento([('A', 8)]);
      expect(await stockDe('A'), 2);
      expect(() => registrarMovimiento([('A', 5)], id: 'C1', compra: true), throwsA(isA<AppException>()));
      expect(await stockDe('A'), 2);
    });

    test('borrar comprobante revierte el stock y borra sus ítems', () async {
      await crearProducto('A', 'Arroz', stock: 10);
      final venta = await registrarMovimiento([('A', 4)]);
      await ReceiptService().deleteReceipt(venta);
      expect(await stockDe('A'), 10);
      final db = await DatabaseHelper.instance.database;
      expect(await db.query('receipt_items'), isEmpty);
      expect(await db.query('receipts'), isEmpty);
    });

    test('borrar una compra ya vendida se rechaza', () async {
      await crearProducto('A', 'Arroz', stock: 0);
      final compra = await registrarMovimiento([('A', 10)], compra: true);
      await registrarMovimiento([('A', 8)]);
      expect(() => ReceiptService().deleteReceipt(compra),
          throwsA(isA<AppException>().having((e) => e.message, 'message', contains('No se puede eliminar el comprobante'))));
      expect(await stockDe('A'), 2);
    });
  });

  group('Lista de movimientos (CP-17)', () {
    test('ordenada de la más reciente a la más antigua, con producto y cantidad', () async {
      await crearProducto('A', 'Arroz', stock: 100);
      await crearProducto('B', 'Azúcar', stock: 100);
      await registrarMovimiento([('A', 1)], id: 'R-VIEJO', fecha: '2026-09-01T08:00:00');
      await registrarMovimiento([('B', 2), ('A', 3)], id: 'R-NUEVO', fecha: '2026-11-05T08:00:00');
      await registrarMovimiento([('A', 5)], id: 'R-MEDIO', compra: true, fecha: '2026-10-01T08:00:00');
      await ReceiptService().refreshReceipts();

      final lista = ReceiptService().cachedMovements!;
      expect(lista.map((m) => m.receipt.id), ['R-NUEVO', 'R-MEDIO', 'R-VIEJO']);
      expect(lista.first.lineas.map((l) => '${l.productNombre}:${l.cantidad}'), ['Azúcar:2.0', 'Arroz:3.0']);
      expect(lista[1].receipt.tipomovimiento, isTrue);
      // Filtro por producto
      expect(lista.where((m) => m.contieneProducto('azú')).map((m) => m.receipt.id), ['R-NUEVO']);
    });
  });

  group('Balance (CP-15)', () {
    test('mes y trimestre', () async {
      await crearProducto('A', 'Arroz', stock: 100);
      await registrarMovimiento([('A', 2)], fecha: '2026-10-10T08:00:00', costo: 5); // venta 10
      await registrarMovimiento([('A', 3)], fecha: '2026-11-03T08:00:00', costo: 5); // venta 15
      await registrarMovimiento([('A', 4)], compra: true, fecha: '2026-11-04T08:00:00', costo: 2); // compra 8

      final mes = await ReceiptService().getFinancialBalance(year: 2026, month: 11);
      expect(mes['total_ventas'], 15);
      expect(mes['total_compras'], 8);
      expect(mes['balance_neto'], 7);
      expect((mes['etiquetas_x'] as List).length, 30);

      final tri = await ReceiptService().getFinancialBalance(year: 2026, month: 11, trimestral: true);
      expect(tri['total_ventas'], 25);
      expect(tri['balance_neto'], 17);
      expect((tri['etiquetas_x'] as List).length, 92);
    });
  });

  group('Predicción (CP-08)', () {
    test('estima la demanda semanal con historial y avisa sin historial', () async {
      await crearProducto('A', 'Arroz', stock: 500);
      await crearProducto('N', 'Nuevo', stock: 50);
      for (var d = 1; d <= 30; d++) {
        final dia = d.toString().padLeft(2, '0');
        await registrarMovimiento([('A', 4)], fecha: '2026-09-${dia}T08:00:00');
      }
      await registrarMovimiento([('N', 1)], fecha: '2026-10-01T08:00:00');
      await registrarMovimiento([('N', 1)], fecha: '2026-10-02T08:00:00');

      final r = await DashboardAiService().getInventoryRiskReport();
      final items = List<Map<String, dynamic>>.from(r['items']);
      final sin = List<Map<String, dynamic>>.from(r['sin_historial']);
      expect(items.single['id'], 'A');
      expect((items.single['weekly_demand'] as double).round(), 28);
      expect(sin.single['nombre'], 'Nuevo');
      expect(sin.single['dias_con_ventas'], 2);
    });
  });

  group('Destacados del mes (CP-12)', () {
    test('mes con ventas y mes solo con compras', () async {
      await crearProducto('A', 'Arroz', stock: 100);
      await crearProducto('B', 'Azúcar', stock: 100);
      await registrarMovimiento([('A', 5)], fecha: '2026-10-10T08:00:00', costo: 2);
      await registrarMovimiento([('B', 2)], fecha: '2026-10-11T08:00:00', costo: 10);
      await registrarMovimiento([('A', 50)], compra: true, fecha: '2026-09-05T08:00:00', costo: 1);

      final oct = await DashboardAiService().getProductInsightsForMonth(2026, 10);
      expect(oct['most_sold']['nombre'], 'Arroz');
      expect(oct['most_profitable']['nombre'], 'Azúcar');

      final sep = await DashboardAiService().getProductInsightsForMonth(2026, 9);
      expect(sep['most_sold'], isEmpty);
      expect(sep['most_profitable'], isEmpty, reason: 'sin ventas no hay más rentable');
    });
  });
}
