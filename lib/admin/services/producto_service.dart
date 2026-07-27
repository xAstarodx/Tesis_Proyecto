import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

String _detectarExtension(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47)
    return 'png';
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
  if (bytes.length >= 4 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46)
    return 'webp';
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46)
    return 'gif';
  return 'png';
}

class ProductoService {
  final supabase = Supabase.instance.client;

  Future<String?> _subirImagen(Uint8List bytes) async {
    try {
      final ext = _detectarExtension(bytes);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage
          .from('imagenes_productos')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      return supabase.storage.from('imagenes_productos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  Future<void> guardarProducto({
    required String nombre,
    required String descripcion,
    required double precioUsd,
    required int stock,
    required int categoriaId,
    File? imagenFile,
    Uint8List? imagenBytes,
  }) async {
    String? imagenUrl;

    if (imagenBytes != null) {
      imagenUrl = await _subirImagen(imagenBytes);
    } else if (imagenFile != null) {
      try {
        final bytes = await imagenFile.readAsBytes();
        imagenUrl = await _subirImagen(bytes);
      } catch (e) {
        debugPrint('Error leyendo archivo de imagen: $e');
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
      debugPrint('Consultando Supabase para categoría ID: $categoriaId');
      final data = await supabase
          .from('productos')
          .select()
          .eq('categoria_id', categoriaId)
          .order('producto_id', ascending: true);

      debugPrint('Datos recibidos ($categoriaId): $data');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('ERROR CRÍTICO en Supabase: $e');
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
      debugPrint('ERROR CRÍTICO en Supabase: $e');
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
    Uint8List? imagenBytes,
  }) async {
    String? imagenUrl;

    if (imagenBytes != null) {
      imagenUrl = await _subirImagen(imagenBytes);
    } else if (imagenFile != null) {
      try {
        final bytes = await imagenFile.readAsBytes();
        imagenUrl = await _subirImagen(bytes);
      } catch (e) {
        debugPrint('Error leyendo archivo de imagen: $e');
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
          .from('tasa_dolar')
          .select('valor, id_tasa')
          .eq('clave', 'tasa_usd_bs')
          .order('fecha_mod', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return {
        'valor': (response['valor'] as num).toDouble(),
        'id': response['id_tasa'] as int,
      };
    } catch (e) {
      debugPrint('Error obteniendo tasa: $e');
      return null;
    }
  }

  Future<bool> obtenerAutoTasaActiva() async {
    try {
      final res = await supabase
          .from('tasa_dolar')
          .select('valor')
          .eq('clave', 'auto_tasa_activa')
          .order('fecha_mod', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return true;
      return (res['valor'] as num).toInt() == 1;
    } catch (e) {
      return true;
    }
  }

  Future<void> establecerAutoTasa(bool activa) async {
    await supabase.from('tasa_dolar').insert({
      'clave': 'auto_tasa_activa',
      'valor': activa ? 1 : 0,
    });
  }

  Future<void> _insertarRegistroPago({
    required int pedidoId,
    required double montoTotalUsd,
    required int formaPagoId,
    int? tasaDolarId,
    String? referencia,
    String? comprobanteUrl,
  }) async {
    final registroPagoRes = await supabase
        .from('registro_pagos')
        .insert({'id_pedido': pedidoId, 'monto_total_pedido': montoTotalUsd})
        .select('id_pago')
        .maybeSingle();

    if (registroPagoRes == null)
      throw Exception('Error al crear registro de pago');
    final idPago = registroPagoRes['id_pago'];

    await supabase.from('detalle_pago').insert({
      'id_pago': idPago,
      'forma_pago_id': formaPagoId,
      'id_taza': tasaDolarId,
      'monto_pagado': montoTotalUsd,
      'referencia': referencia,
      'comprobante_url': comprobanteUrl,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialTasaCambio() async {
    try {
      final response = await supabase
          .from('tasa_dolar')
          .select('valor, fecha_mod, id_tasa')
          .eq('clave', 'tasa_usd_bs')
          .order('fecha_mod', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error obteniendo historial de tasa: $e');
      return [];
    }
  }

  Future<void> actualizarTasaCambio(double nuevaTasa) async {
    await supabase.from('tasa_dolar').insert({
      'clave': 'tasa_usd_bs',
      'valor': nuevaTasa,
    });
  }

  Future<void> autoActualizarTasaCambio() async {
    final activa = await obtenerAutoTasaActiva();
    if (!activa) return;
    for (int intento = 0; intento < 2; intento++) {
      try {
        final res = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final valor = (data['promedio'] as num).toDouble();
          final existente = await obtenerTasaCambioInfo();
          if (existente == null || (existente['valor'] as double) != valor) {
            await actualizarTasaCambio(valor);
            debugPrint('Tasa auto-actualizada: $valor Bs/USD');
          }
          return;
        }
      } catch (e) {
        debugPrint('Intento $intento falló: $e');
        if (intento == 0) await Future.delayed(const Duration(seconds: 3));
      }
    }
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
            detalle_pedido(*, productos(*)),
            registro_pagos (
              id_pago,
              detalle_pago (
                tasa_dolar ( valor )
              )
            )
          ''')
          .neq('estado_id', 5)
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

      if (nuevoEstadoId == 4 || nuevoEstadoId == 6) {
        final existePago = await supabase
            .from('registro_pagos')
            .select('id_pago')
            .eq('id_pedido', pedidoId)
            .maybeSingle();

        if (existePago != null) return;

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

        final formaPagoId =
            (pedidoData['forma_pago']?['forma_pago_id'] as num?)?.toInt() ?? 1;

        final datosPagoRaw = pedidoData['datos_pago_orden'];
        final Map<String, dynamic>? datosUsuario =
            (datosPagoRaw is List && datosPagoRaw.isNotEmpty)
            ? datosPagoRaw.first
            : (datosPagoRaw is Map ? datosPagoRaw : null);

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
      await supabase
          .from('pedido')
          .update({'estado_id': 5})
          .eq('pedido_id', pedidoId);
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

  Future<Map<String, dynamic>> importarProductosDesdeExcel({
    required List<Map<String, dynamic>> productos,
    required List<Map<String, dynamic>> categoriasExistentes,
  }) async {
    int importados = 0;
    int errores = 0;
    final List<String> mensajesError = [];

    final catMap = <String, int>{};
    for (final c in categoriasExistentes) {
      catMap[(c['nombre_categoria'] as String).toLowerCase().trim()] =
          c['categoria_id'] as int;
    }

    for (final p in productos) {
      try {
        final nombre = (p['nombre'] as String).trim();
        final descripcion = (p['descripcion'] as String?)?.trim() ?? '';
        final precio = double.parse(p['precio'].toString().replaceAll(',', '.'));
        final stock = int.parse(p['stock'].toString());
        final catNombre = (p['categoria'] as String).trim().toLowerCase();
        final imagenUrl = p['imagen_url'] as String?;

        int catId;
        if (catMap.containsKey(catNombre)) {
          catId = catMap[catNombre]!;
        } else {
          final newCat = await supabase
              .from('categoria')
              .insert({'nombre_categoria': p['categoria'].toString().trim()})
              .select('categoria_id')
              .single();
          catId = newCat['categoria_id'] as int;
          catMap[catNombre] = catId;
        }

        await supabase.from('productos').insert({
          'nombre': nombre,
          'descripcion': descripcion,
          'precio': precio,
          'stock': stock,
          'categoria_id': catId,
          if (imagenUrl != null && imagenUrl.isNotEmpty) 'imagen_url': imagenUrl,
        });
        importados++;
      } catch (e) {
        errores++;
        mensajesError.add('${p['nombre'] ?? '?'}: $e');
      }
    }

    return {
      'importados': importados,
      'errores': errores,
      'mensajes': mensajesError,
    };
  }
}
