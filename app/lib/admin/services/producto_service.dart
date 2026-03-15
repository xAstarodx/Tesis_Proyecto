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
        'imagen_url': imagenUrl,
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

    final datosActualizar = {
      'nombre': nombre,
      'descripcion': descripcion,
      'stock': stock,
      'precio': precioUsd,
    };

    if (imagenUrl != null) {
      datosActualizar['imagen_url'] = imagenUrl;
    }

    try {
      await supabase
          .from('productos')
          .update(datosActualizar)
          .eq('producto_id', productoId);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  Future<Map<String, dynamic>?> obtenerTasaCambioInfo() async {
    try {
      final response = await supabase
          .from('taza_dolar')
          .select('valor, id')
          .eq('clave', 'tasa_usd_bs')
          .order('fecha_mod', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return {
        'valor': (response['valor'] as num).toDouble(),
        'id': response['id'] as int,
      };
    } catch (e) {
      print('Error obteniendo tasa: $e');
      return null;
    }
  }

  Future<void> _insertarRegistroPago({
    required int pedidoId,
    required double montoTotalUsd,
    required int formaPagoId,
    int? tasaDolarId,
    String? referencia,
    String? comprobanteUrl,
  }) async {
    // 1. Insert into registro_pagos
    final registroPagoRes = await supabase
        .from('registro_pagos')
        .insert({'id_pedido': pedidoId, 'monto_total_pedido': montoTotalUsd})
        .select('id_pago')
        .single();

    final idPago = registroPagoRes['id_pago'];

    // 2. Insert into detalle_pago
    await supabase.from('detalle_pago').insert({
      'id_pago': idPago,
      'forma_pago_id': formaPagoId,
      'id_taza': tasaDolarId,
      'monto_pagado': montoTotalUsd,
      'referencia': referencia,
      'comprobante_url': comprobanteUrl,
    });
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
            estado (
              etiqueta
            ),
            usuario (
              nombre,
              correo
            ),
            datos_pago_orden ( referencia, comprobante_url ),
            forma_pago ( nombre_metodo ),
            detalle_pedido(*, productos(*))
          ''')
          .order('fecha_creacion', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Error al obtener pedidos: $e');
    }
  }

  Future<void> actualizarEstadoPedido(int pedidoId, int nuevoEstadoId) async {
    try {
      await supabase
          .from('pedido')
          .update({'estado_id': nuevoEstadoId})
          .eq('pedido_id', pedidoId);

      if (nuevoEstadoId == 4) {
        // If status is changed to 'Pagado', record payment details
        final pedidoData = await supabase
            .from('pedido')
            .select('''
              *,
              forma_pago ( forma_pago_id ),
              detalle_pedido (
                cantidad,
                precio_unitario
              ),
              datos_pago_orden ( referencia, comprobante_url )
            ''')
            .eq('pedido_id', pedidoId)
            .single();

        double totalUsd = 0.0;
        final detalles = pedidoData['detalle_pedido'] as List<dynamic>? ?? [];
        for (var d in detalles) {
          totalUsd += (d['cantidad'] as num) * (d['precio_unitario'] as num);
        }

        final formaPagoId = pedidoData['forma_pago']['forma_pago_id'] as int;

        // Obtener datos reportados por el usuario
        final datosUsuario = pedidoData['datos_pago_orden'];
        // Nota: Supabase devuelve null, un Map o una Lista dependiendo de la FK. Asumimos Map o manejamos null.

        // Get current exchange rate with ID
        final tasaCambioInfo = await obtenerTasaCambioInfo();
        final tasaDolarId = tasaCambioInfo?['id'] as int?;

        await _insertarRegistroPago(
          pedidoId: pedidoId,
          montoTotalUsd: totalUsd,
          formaPagoId: formaPagoId,
          tasaDolarId: tasaDolarId,
          referencia: datosUsuario?['referencia'],
          comprobanteUrl: datosUsuario?['comprobante_url'],
        );
      }
    } catch (e) {
      throw Exception('Error al actualizar el estado del pedido: $e');
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
