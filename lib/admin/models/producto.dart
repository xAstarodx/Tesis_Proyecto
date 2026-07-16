class Producto {
  final String nombre;
  final int cantidad;
  final double precioUsd;

  Producto({
    required this.nombre,
    required this.cantidad,
    required this.precioUsd,
  });

  Producto copiarCon({String? nombre, int? cantidad, double? precioUsd}) {
    return Producto(
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      precioUsd: precioUsd ?? this.precioUsd,
    );
  }
}
