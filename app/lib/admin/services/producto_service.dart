import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductoService {
  final supabase = Supabase.instance.client;

  Future<void> guardarProducto({
    required String nombre,
    required String descripcion,
    required double precioUsd,
    required int stock,
    required int categoriaId,
    File? imagenFile,
  }) async {
    String? imagenUrl;

    if (imagenFile != null) {
      try {
        final bytes = await imagenFile.readAsBytes();
        final fileExt = imagenFile.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName;
        await supabase.storage
            .from('imagenes_productos')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );
        imagenUrl = supabase.storage
            .from('imagenes_productos')
            .getPublicUrl(filePath);
      } catch (e) {
        print('Error subiendo imagen: $e');
      }
    }

    try {
      await supabase.from('productos').insert({
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precioUsd,
        'stock': stock,
        'categoria_id': categoriaId,
        'imagen_url': ?imagenUrl,
      });
    } catch (e) {
      throw Exception('Error al guardar producto: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerProductosPorCategoria(
    int categoriaId,
  ) async {
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
    required String nombre,
    required String descripcion,
    required int stock,
    required double precioUsd,
    File? imagenFile,
  }) async {
    String? imagenUrl;

    if (imagenFile != null) {
      try {
        final bytes = await imagenFile.readAsBytes();
        final fileExt = imagenFile.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName;
        await supabase.storage
            .from('imagenes_productos')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );
        imagenUrl = supabase.storage
            .from('imagenes_productos')
            .getPublicUrl(filePath);
      } catch (e) {
        print('Error subiendo imagen: $e');
      }
    }

    try {
      await supabase
          .from('productos')
          .update({
            'nombre': nombre,
            'descripcion': descripcion,
            'stock': stock,
            'precio': precioUsd,
            'imagen_url': ?imagenUrl,
          })
          .eq('producto_id', productoId);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  Future<double> obtenerTasaCambio() async {
    try {
      final response = await supabase
          .from('taza_dolar')
          .select('valor')
          .eq('clave', 'tasa_usd_bs')
          .order('fecha_mod', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 1.0;
      return (response['valor'] as num).toDouble();
    } catch (e) {
      print('Error obteniendo tasa: $e');
      return 1.0;
    }
  }

  Future<void> actualizarTasaCambio(double nuevaTasa) async {
    await supabase.from('taza_dolar').insert({
      'clave': 'tasa_usd_bs',
      'valor': nuevaTasa,
      'fecha_mod': DateTime.now().toIso8601String(),
    });
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

  Future<void> eliminarProducto(int productoId) async {
    try {
      await supabase.from('productos').delete().eq('producto_id', productoId);
    } catch (e) {
      throw Exception('Error al eliminar producto: $e');
    }
  }
}
