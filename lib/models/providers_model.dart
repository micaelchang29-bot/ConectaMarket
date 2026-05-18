class Provider {
  final String id;
  final String nombre;
  final String? ruc;
  final String? telefono;

  Provider({required this.id, required this.nombre, this.ruc, this.telefono});

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'ruc': ruc,
    'telefono': telefono,
  };

  factory Provider.fromMap(Map<String, dynamic> map) => Provider(
    id: map['id'],
    nombre: map['nombre'],
    ruc: map['ruc'],
    telefono: map['telefono'],
  );
}