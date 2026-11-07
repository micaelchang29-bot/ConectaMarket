import 'package:conectamarket/models/products_model.dart';
import 'package:conectamarket/models/receipt_items_model.dart';
import 'package:conectamarket/models/receipts_model.dart';
import 'package:conectamarket/repositories/database_helper.dart';
import 'package:conectamarket/repositories/receipt_repository.dart';
import 'package:conectamarket/services/product_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiListo = false;

/// Abre una base SQLite vacía en memoria para la prueba.
Future<void> abrirBaseDePrueba() async {
  if (!_ffiListo) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiListo = true;
  }
  await DatabaseHelper.resetForTests(path: inMemoryDatabasePath);
  // Fuerza la creación del esquema antes de usar los servicios
  await DatabaseHelper.instance.database;
}

Future<void> cerrarBaseDePrueba() => DatabaseHelper.resetForTests();

Future<Product> crearProducto(String id, String nombre,
    {double stock = 10, double precio = 1, int umbral = 5}) async {
  final p = Product(id: id, nombre: nombre, stock: stock, precio: precio, umbralAlerta: umbral);
  await ProductService().saveProduct(p, esNuevo: true);
  return p;
}

Future<double> stockDe(String id) async {
  final db = await DatabaseHelper.instance.database;
  final r = await db.query('products', where: 'id = ?', whereArgs: [id]);
  return (r.first['stock'] as num).toDouble();
}

int _seq = 0;

/// Registra un comprobante con líneas (productId, cantidad).
Future<String> registrarMovimiento(
  List<(String, double)> lineas, {
  bool compra = false,
  String? id,
  String fecha = '2026-11-05T10:00:00',
  String? providerId,
  double costo = 2,
}) async {
  final rid = id ?? 'REC-T${_seq++}';
  final items = [
    for (final (pid, qty) in lineas)
      ReceiptItem(id: 'IT-${_seq++}', receiptId: rid, productId: pid, cantidad: qty, costoUnitario: costo),
  ];
  await ReceiptRepository().saveFullReceipt(
    Receipt(
      id: rid,
      providerId: providerId ?? '',
      fecha: fecha,
      total: items.fold(0.0, (s, i) => s + i.cantidad * i.costoUnitario),
      tipomovimiento: compra,
    ),
    items,
  );
  return rid;
}
