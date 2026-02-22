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
      print('Consultando Supabase para categoría ID: $categoriaId');
      final data = await supabase
          .from('productos')
          .select()
          .eq('categoria_id', categoriaId)
          .order('producto_id', ascending: true);

      print('Datos recibidos ($categoriaId): $data');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('ERROR CRÍTICO en Supabase: $e');
      throw Exception('Error al obtener productos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerTodosLosProductos() async {
    try {
      final data = await supabase
          .from('productos')
          .select()
          .order('categoria_id', ascending: true)
          .order('nombre', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('ERROR CRÍTICO en Supabase: $e');
      throw Exception('Error al obtener todos los productos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    try {
      final data = await supabase.from('categoria').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al obtener categorías: $e');
    }
  }

  Future<void> actualizarProducto({
    required int productoId,
    required int stock,
    required double precioUsd,
  }) async {
    try {
      await supabase
          .from('productos')
          .update({
            'stock': stock,
            'precio': precioUsd,
          })
          .eq('producto_id', productoId);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  Future<double> obtenerTasaCambio() async {
    try {
      final response = await supabase
          .from('configuracion')
          .select('valor')
          .eq('clave', 'tasa_usd_bs')
          .maybeSingle();
      
      if (response == null) return 1.0;
      return (response['valor'] as num).toDouble();
    } catch (e) {
      print('Error obteniendo tasa: $e');
      return 1.0;
    }
  }

  Future<void> actualizarTasaCambio(double nuevaTasa) async {
    await supabase.from('configuracion').delete().eq('clave', 'tasa_usd_bs');
    await supabase.from('configuracion').insert(
      {'clave': 'tasa_usd_bs', 'valor': nuevaTasa},
    );
  }

  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    try {
      final data = await supabase
          .from('pedido')
          .select('''
            *,
            usuario (
              nombre,
              correo
            ),
            detalle_pedido(*, productos(*))
          ''')
          .order('fecha_creacion', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al obtener pedidos: $e');
    }
  }

  Future<void> eliminarPedido(int pedidoId) async {
    try {
      await supabase.from('pedido').delete().eq('pedido_id', pedidoId);
    } catch (e) {
      throw Exception('Error al eliminar pedido: $e');
    }
  }
}
