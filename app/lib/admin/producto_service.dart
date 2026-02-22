import 'package:supabase_flutter/supabase_flutter.dart';

class ProductoService {
  final supabase = Supabase.instance.client;

  Future<void> guardarProducto({
    required String nombre,
    required String descripcion,
    required double precioUsd,
    required int stock,
    required int categoriaId,
  }) async {
    try {
      await supabase.from('productos').insert({
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precioUsd,
        'stock': stock,
        'categoria_id': categoriaId,
      });
    } catch (e) {
      throw Exception('Error al guardar producto: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerProductosPorCategoria(int categoriaId) async {
    try {
      final data = await supabase
          .from('productos')
          .select()
          .eq('categoria_id', categoriaId)
          .order('producto_id', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al obtener productos: $e');
    }
  }
}
