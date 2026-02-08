import 'package:flutter/foundation.dart';

class CartModel {
  static final ValueNotifier<List<Map<String, dynamic>>> items =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static void add(Map<String, dynamic> item) {
    items.value = [...items.value, Map<String, dynamic>.from(item)];
  }

  static void removeAt(int index) {
    final list = [...items.value];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      items.value = list;
    }
  }

  static void clear() {
    items.value = [];
  }
}
