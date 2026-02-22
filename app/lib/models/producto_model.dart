class Producto {
  final int productoId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int stok;
  final int? categoriaId;

  Producto({
    required this.productoId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stok,
    this.categoriaId,
  });

  factory Producto.fromMap(Map<String, dynamic> m) {
    return Producto(
      productoId: (m['producto_id'] ?? m['id']) is int ? (m['producto_id'] ?? m['id']) as int : int.parse((m['producto_id'] ?? m['id']).toString()),
      nombre: (m['nombre'] ?? '') as String,
      descripcion: m['descripcion']?.toString(),
      precio: m['precio'] != null ? double.parse(m['precio'].toString()) : 0.0,
      stok: m['stok'] != null ? int.parse(m['stok'].toString()) : 0,
      categoriaId: m['categoria_id'] != null ? int.parse(m['categoria_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toMenuMap() {
    return {
      'nombre': nombre,
      'precio': precio,
      'descripcion': descripcion ?? '',
      'producto_id': productoId,
    };
  }
}
