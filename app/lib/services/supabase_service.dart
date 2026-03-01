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
      print('Error al obtener productos: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    try {
      final data = await _cliente.from('categoria').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error al obtener categorías: $e');
      return [];
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
          .from('pedidos')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error al obtener pedidos: $e');
      return [];
    }
  }

  Future<void> cerrarSesion() async {
    await _cliente.auth.signOut();
  }

  Future<AuthResponse> registrarUsuario(
    String email,
    String password, {
    String? nombre,
    String? usuario,
  }) async {
    final metadatos = <String, dynamic>{};

    if (nombre != null) {
      metadatos['nombre'] = nombre;
    }
    if (usuario != null) {
      metadatos['username'] = usuario;
    }
    metadatos['contraseña'] = password;

    return await _cliente.auth.signUp(
      email: email,
      password: password,
      data: metadatos.isNotEmpty ? metadatos : null,
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
          .from('taza_dolar')
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
  }) async {
    final user = _cliente.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw Exception('Debes iniciar sesión');

    final usuarioData = await _cliente
        .from('usuario')
        .select('usuario_id')
        .eq('correo', email)
        .maybeSingle();
    if (usuarioData == null)
      throw Exception('Usuario no encontrado en la base de datos');
    final usuarioId = usuarioData['usuario_id'];

    final pedidoRes = await _cliente
        .from('pedido')
        .insert({
          'usuario_id': usuarioId,
          'estado_id': 1,
          'hora_recogida': horaRecogida,
        })
        .select('pedido_id')
        .single();

    final pedidoId = pedidoRes['pedido_id'];

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
            detalle_pedido (
              *,
              productos (
                nombre
              )
            )
          ''')
          .eq('usuario_id', usuarioId)
          .order('fecha_creacion', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error al obtener mis pedidos: $e');
      return [];
    }
  }
}
