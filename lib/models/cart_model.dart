import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartModel {
  static final ValueNotifier<List<Map<String, dynamic>>> items =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static String? horaRecogida;
  static String? referencia;
  static String? notaAdmin;

  static Future<void> cargarCarrito() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? carritoJson = prefs.getString('carrito_persistente');

      horaRecogida = prefs.getString('cart_hora');
      referencia = prefs.getString('cart_ref');
      notaAdmin = prefs.getString('cart_nota');

      if (carritoJson != null) {
        final List<dynamic> decoded = jsonDecode(carritoJson);
        items.value = List<Map<String, dynamic>>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error cargando el carrito persistido: $e');
    }
  }

  static Future<void> _guardarLocalmente() async {
    final prefs = await SharedPreferences.getInstance();

    final listaSegura = items.value.map((item) {
      final map = Map<String, dynamic>.from(item);
      map.remove(
        'icono',
      );
      return map;
    }).toList();
    await prefs.setString('carrito_persistente', jsonEncode(listaSegura));

    await prefs.setString('cart_hora', horaRecogida ?? '');
    await prefs.setString('cart_ref', referencia ?? '');
    await prefs.setString('cart_nota', notaAdmin ?? '');
  }

  static void actualizarDatosCheckout({
    String? hora,
    String? ref,
    String? nota,
  }) {
    if (hora != null) horaRecogida = hora;
    if (ref != null) referencia = ref;
    if (nota != null) notaAdmin = nota;
    _guardarLocalmente();
  }

  static void add(Map<String, dynamic> item) {
    final list = List<Map<String, dynamic>>.from(items.value);
    final index = list.indexWhere((it) => it['producto_id'] == item['producto_id']);

    if (index != -1) {

      final existingItem = Map<String, dynamic>.from(list[index]);
      existingItem['cantidad'] = (existingItem['cantidad'] ?? 1) + (item['cantidad'] ?? 1);
      list[index] = existingItem;
      items.value = list;
    } else {

      items.value = [...items.value, Map<String, dynamic>.from(item)];
    }
    _guardarLocalmente();
  }

  static void removeAt(int index) {
    final list = [...items.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      items.value = list;
      _guardarLocalmente();
    }
  }

  static void clear() {
    items.value = [];
    horaRecogida = null;
    referencia = null;
    notaAdmin = null;
    _guardarLocalmente();
  }
}
