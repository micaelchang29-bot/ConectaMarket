class Product {
  final String id;
  final String nombre;
  final double stock;
  final int umbralAlerta;

  Product({required this.id, required this.nombre, this.stock = 0, this.umbralAlerta = 5});

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'stock': stock,
    'umbralAlerta': umbralAlerta,
  };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
    id: map['id'],
    nombre: map['nombre'],
    stock: map['stock'],
    umbralAlerta: map['umbralAlerta'],
  );
}