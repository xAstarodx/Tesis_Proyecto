import 'package:flutter/material.dart';
import '../models/cart_model.dart';

class CarritoPage extends StatelessWidget {
  const CarritoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: CartModel.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(child: Text('Carrito vacío'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: Icon(item['icono']),
                  title: Text(item['nombre']),
                  subtitle: Text('\$${(item['precio'] as num).round()}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => CartModel.removeAt(index),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
