import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';

String _detectarExtension(Uint8List bytes) {
  if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
  if (bytes.length >= 4 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'webp';
  if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';
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
      return supabase.storage
          .from('imagenes_productos')
          .getPublicUrl(fileName);
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

    if (registroPagoRes == null) throw Exception('Error al crear registro de pago');
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
            detalle_pedido(*, productos(*)),
            registro_pagos (
              id_pago,
              detalle_pago (
                tasa_dolar ( valor )
              )
            )
          ''')
          .neq(
            'estado_id',
            5,
          )
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

        final formaPagoId = (pedidoData['forma_pago']?['forma_pago_id'] as num?)?.toInt() ?? 1;

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

  Future<Uint8List> generarPlantillaExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Productos'];
    sheet.appendRow([
      TextCellValue('nombre'),
      TextCellValue('descripcion'),
      TextCellValue('precio'),
      TextCellValue('stock'),
      TextCellValue('categoria'),
      TextCellValue('imagen_url'),
    ]);
    sheet.appendRow([
      TextCellValue('Café Americano'),
      TextCellValue('Café americano 500ml'),
      IntCellValue(3),
      IntCellValue(50),
      TextCellValue('Bebidas'),
      TextCellValue('https://ejemplo.com/imagen.jpg'),
    ]);
    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? []);
  }

  // ponytail: linear scan on name for upsert; add DB unique constraint if scale requires it
  Future<Map<String, int>> importarProductosDesdeExcel(
    Uint8List bytes,
    List<Map<String, dynamic>> categorias,
  ) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.values.isEmpty) return {'creados': 0, 'actualizados': 0, 'errores': 0};
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;

    int creados = 0, actualizados = 0, errores = 0;

    final existentes = await obtenerTodosLosProductos();
    final productosPorNombre = <String, Map<String, dynamic>>{};
    for (final p in existentes) {
      productosPorNombre[p['nombre'] as String] = p;
    }

    final catPorNombre = <String, int>{};
    for (final c in categorias) {
      catPorNombre[(c['nombre_categoria'] as String).toLowerCase()] =
          c['categoria_id'] as int;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 5) continue;

      final nombre = (row[0]?.value?.toString() ?? '').trim();
      if (nombre.isEmpty) continue;

      final descripcion = (row[1]?.value?.toString() ?? '').trim();
      final precio = double.tryParse(
        (row[2]?.value?.toString() ?? '').replaceAll(',', '.'),
      );
      final stock = int.tryParse(row[3]?.value?.toString() ?? '');
      final catName = (row[4]?.value?.toString() ?? '').trim().toLowerCase();

      if (precio == null || stock == null) {
        errores++;
        continue;
      }

      final categoriaId = catPorNombre[catName];
      if (categoriaId == null) {
        errores++;
        continue;
      }

      Uint8List? imagenBytes;
      if (row.length > 5) {
        final imgVal = (row[5]?.value?.toString() ?? '').trim();
        if (imgVal.isNotEmpty) {
          try {
            if (imgVal.startsWith('http://') || imgVal.startsWith('https://')) {
              final client = HttpClient();
              try {
                final req = await client.getUrl(Uri.parse(imgVal));
                final res = await req.close();
                final chunks = <int>[];
                await for (final chunk in res) {
                  chunks.addAll(chunk);
                }
                imagenBytes = Uint8List.fromList(chunks);
              } finally {
                client.close();
              }
            } else {
              final file = File(imgVal);
              if (await file.exists()) {
                imagenBytes = await file.readAsBytes();
              }
            }
          } catch (e) {
            debugPrint('Error procesando imagen para $nombre: $e');
          }
        }
      }

      if (productosPorNombre.containsKey(nombre)) {
        final existing = productosPorNombre[nombre]!;
        await actualizarProducto(
          productoId: existing['producto_id'] as int,
          nombre: nombre,
          descripcion: descripcion,
          stock: stock,
          precioUsd: precio,
          imagenBytes: imagenBytes,
        );
        actualizados++;
      } else {
        await guardarProducto(
          nombre: nombre,
          descripcion: descripcion,
          precioUsd: precio,
          stock: stock,
          categoriaId: categoriaId,
          imagenBytes: imagenBytes,
        );
        creados++;
      }
    }

    return {'creados': creados, 'actualizados': actualizados, 'errores': errores};
  }
}
