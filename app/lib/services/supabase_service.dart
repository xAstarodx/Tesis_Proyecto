import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto_model.dart';

class SupabaseService {
  final _cliente = Supabase.instance.client;

  Future<List<Producto>> obtenerProductos() async {
    try {
      // Supabase v2: .select() devuelve directamente List<Map<String, dynamic>>
      final data = await _cliente.from('productos').select();
      
      // Convertimos la respuesta a una lista de objetos Producto
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
      final data = await _cliente.from('categorias').select();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error al obtener categorías: $e');
      return []; // Retorna lista vacía si falla o no existe la tabla
    }
  }

  Future<void> crearProducto(String nombre, double precio, int categoriaId) async {
    await _cliente.from('productos').insert({
      'nombre': nombre,
      'precio': precio,
      'categoria_id': categoriaId,
      // 'imagen_url': imagenUrl, // Descomentar si manejas imágenes
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPedidos() async {
    try {
      final data = await _cliente.from('pedidos').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error al obtener pedidos: $e');
      return [];
    }
  }

  Future<void> cerrarSesion() async {
    await _cliente.auth.signOut();
  }

  Future<AuthResponse> registrarUsuario(String email, String password, {String? nombre, String? usuario}) async {
    final metadatos = <String, dynamic>{};
    
    // Supabase usa 'full_name' por convención
    if (nombre != null) {
      metadatos['full_name'] = nombre;
    }
    if (usuario != null) {
      metadatos['username'] = usuario;
    }

    return await _cliente.auth.signUp(
      email: email,
      password: password,
      data: metadatos.isNotEmpty ? metadatos : null,
    );
  }

  Future<AuthResponse> iniciarSesion(String email, String password) async {
    return await _cliente.auth
        .signInWithPassword(email: email, password: password);
  }

  Future<double> obtenerTasaCambio() async {
    try {
      final response = await _cliente
          .from('configuracion')
          .select('valor')
          .eq('clave', 'tasa_usd_bs')
          .maybeSingle();
      
      if (response == null) return 1.0;
      return (response['valor'] as num).toDouble();
    } catch (e) {
      return 1.0;
    }
  }
}
