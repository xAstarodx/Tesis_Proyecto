import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto_model.dart';

class SupabaseService {
  final _cliente = Supabase.instance.client;

  Future<List<Producto>> obtenerProductos() async {
    try {
      final data = await _cliente.from('productos').select();

      return (data as List<dynamic>)
          .map((e) => Producto.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener productos: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    try {
      final data = await _cliente.from('categoria').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error al obtener categorías: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> obtenerFormasPago() async {
    try {
      final data = await _cliente
          .from('forma_pago')
          .select()
          .order('forma_pago_id', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [
        {'forma_pago_id': 1, 'nombre_metodo': 'Efectivo'},
        {'forma_pago_id': 2, 'nombre_metodo': 'Tarjeta'},
        {'forma_pago_id': 3, 'nombre_metodo': 'Pago Móvil'},
      ];
    }
  }

  Future<void> crearProducto(
    String nombre,
    double precio,
    int categoriaId,
  ) async {
    await _cliente.from('productos').insert({
      'nombre': nombre,
      'precio': precio,
      'categoria_id': categoriaId,
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    try {
      final data = await _cliente
          .from('pedido')
          .select()
          .order('fecha_creacion', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error al obtener pedidos: $e');
      return [];
    }
  }

  Future<void> cerrarSesion() async {
    await _cliente.auth.signOut();
  }

  
  
  Future<bool> esAdmin(String email) async {
    try {
      final data = await _cliente
          .from('usuario')
          .select('rol_id')
          .eq('correo', email)
          .maybeSingle();

      if (data == null) return false;
      return (data['rol_id'] as num?)?.toInt() == 2;
    } catch (e) {
      debugPrint('Error al verificar rol de admin: $e');
      return false;
    }
  }

  Future<AuthResponse> registrarUsuario(
    String email,
    String password, {
    String? nombre,
  }) async {
    final metadatos = <String, dynamic>{};
    if (nombre != null) metadatos['nombre'] = nombre;
    metadatos['contraseña'] = password;

    return await _cliente.auth.signUp(
      email: email,
      password: password,
      data: metadatos,
    );
  }

  Future<void> iniciarSesionGoogle() async {
    await _cliente.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<AuthResponse> iniciarSesion(String email, String password) async {
    return await _cliente.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<double> obtenerTasaCambio() async {
    try {
      final response = await _cliente
          .from('tasa_dolar')
          .select('valor')
          .eq('clave', 'tasa_usd_bs')
          .order('fecha_mod', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 1.0;
      return (response['valor'] as num).toDouble();
    } catch (e) {
      return 1.0;
    }
  }

  Future<void> enviarPedido({
    required List<Map<String, dynamic>> items,
    required String horaRecogida,
    required int formaPagoId,
    String? referencia,
    File? comprobanteImage,
    String? nota,
  }) async {
    final user = _cliente.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw Exception('Debes iniciar sesión');

    final usuarioData = await _cliente
        .from('usuario')
        .select('usuario_id')
        .eq('correo', email)
        .maybeSingle();
    if (usuarioData == null) {
      throw Exception('Usuario no encontrado en la base de datos');
    }
    final usuarioId = usuarioData['usuario_id'];

    String? comprobanteUrl;

    if (comprobanteImage != null) {
      try {
        final bytes = await comprobanteImage.readAsBytes();
        final fileExt = comprobanteImage.path.split('.').last;
        final fileName =
            'comprobante_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        await _cliente.storage
            .from('comprobantes_pago')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );
        comprobanteUrl = _cliente.storage
            .from('comprobantes_pago')
            .getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Error al subir comprobante: $e');
      }
    }

    final pedidoRes = await _cliente
        .from('pedido')
        .insert({
          'usuario_id': usuarioId,
          'estado_id': 1,
          'hora_recogida': horaRecogida,
          'forma_pago_id': formaPagoId,
          'nota': nota,
        })
        .select('pedido_id')
        .single();

    final pedidoId = pedidoRes['pedido_id'];

    if (referencia != null || comprobanteUrl != null) {
      await _cliente.from('datos_pago_orden').insert({
        'pedido_id': pedidoId,
        'referencia': referencia,
        'comprobante_url': comprobanteUrl,
      });
    }

    final detalles = items
        .map(
          (item) => {
            'pedido_id': pedidoId,
            'producto_id': item['producto_id'],
            'cantidad': item['cantidad'],
            'precio_unitario': item['precio'],
            'Descripcion': item['mensaje'] ?? '',
          },
        )
        .toList();

    await _cliente.from('detalle_pedido').insert(detalles);
  }

  Future<String?> getCurrentUserId() async {
    final user = _cliente.auth.currentUser;
    if (user == null || user.email == null) return null;
    try {
      final usuarioData = await _cliente
          .from('usuario')
          .select('usuario_id')
          .eq('correo', user.email!)
          .single();
      return usuarioData['usuario_id'] as String?;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  RealtimeChannel suscribirATabla({
    required String tabla,
    required void Function() alCambiar,
    String? filtroColumna,
    dynamic filtroValor,
  }) {
    final channel = _cliente.channel('public:$tabla');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tabla,
          filter: (filtroColumna != null && filtroValor != null)
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filtroColumna,
                  value: filtroValor,
                )
              : null,
          callback: (payload) => alCambiar(),
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel subscribeToPedidos({
    required String userId,
    required void Function(PostgresChangePayload payload) onUpdate,
  }) {
    final channel = _cliente.channel('public:pedido:usuario_id=eq.$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedido',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: userId,
          ),
          callback: onUpdate,
        )
        .subscribe();

    return channel;
  }

  Future<void> unsubscribeFromChannel(RealtimeChannel channel) async {
    await _cliente.removeChannel(channel);
  }

  Future<List<Map<String, dynamic>>> obtenerMisPedidos() async {
    final user = _cliente.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return [];

    try {
      final usuarioData = await _cliente
          .from('usuario')
          .select('usuario_id')
          .eq('correo', email)
          .maybeSingle();
      if (usuarioData == null) return [];
      final usuarioId = usuarioData['usuario_id'];

      final data = await _cliente
          .from('pedido')
          .select('''
            *,
            estado (
              etiqueta
            ),
            datos_pago_orden ( referencia, comprobante_url ),
            forma_pago ( nombre_metodo ),
            detalle_pedido (
              *,
              productos (
                nombre
              )
            )
          ''')
          .eq('usuario_id', usuarioId)
          .neq(
            'estado_id',
            5,
          )
          .order('fecha_creacion', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error al obtener mis pedidos: $e');
      return [];
    }
  }
}
