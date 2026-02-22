import 'package:flutter/material.dart';
import '../models/cart_model.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final TextEditingController _mensajePedidoController = TextEditingController();

  @override
  void dispose() {
    _mensajePedidoController.dispose();
    super.dispose();
  }

  void _enviarAlAdmin(List<Map<String, dynamic>> items) async {
    final pedidoResumen = items.map((it) {
      final qty = (it['cantidad'] ?? 1) as int;
      final precio = (it['precio'] as num).round();
      final msg = (it['mensaje'] ?? '') as String;
      return '${it['nombre']} x$qty - \$$precio${msg.isNotEmpty ? ' (msg: $msg)' : ''}';
    }).join('\n');

    final orderMsg = _mensajePedidoController.text.trim();

    final contenido = 'Pedido:\n$pedidoResumen\n\nMensaje pedido: $orderMsg';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar envío '),
        content: SingleChildScrollView(child: Text(contenido)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado ')));
      CartModel.clear();
      _mensajePedidoController.clear();
    }
  }

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
          final total = items.fold<int>(0, (acc, it) {
            final qty = (it['cantidad'] ?? 1) as int;
            final precio = (it['precio'] as num).round();
            return acc + precio * qty;
          });

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final qty = (item['cantidad'] ?? 1) as int;
                    final precio = (item['precio'] as num).round();
                    final mensaje = (item['mensaje'] ?? '') as String;
                    return Card(
                      child: ListTile(
                        leading: Icon(item['icono']),
                        title: Text(item['nombre']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cantidad: $qty  •  Precio unitario: \$$precio'),
                            Text('Total: \$${precio * qty}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => CartModel.removeAt(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Total: \$$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mensajePedidoController,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _enviarAlAdmin(items),
                      child: const Text('Enviar pedido '),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
