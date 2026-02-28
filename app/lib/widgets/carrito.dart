import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../services/supabase_service.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final _supabaseService = SupabaseService();

  void _enviarAlAdmin(List<Map<String, dynamic>> items) async {
    final pedidoResumen = items.map((it) {
      final qty = (it['cantidad'] ?? 1) as int;
      final precio = (it['precio'] as num).toDouble();
      final precioBs = (it['precio_bs'] as num?)?.toDouble() ?? 0.0;
      final msg = (it['mensaje'] as String?)?.trim() ?? '';
      return '${it['nombre']} x$qty - \$${precio.toStringAsFixed(2)} (Bs ${precioBs.toStringAsFixed(2)})${msg.isNotEmpty ? ' (msg: $msg)' : ''}';
    }).join('\n');

    final contenido = 'Pedido:\n$pedidoResumen';

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
      try {
        await _supabaseService.enviarPedido(
          items: items,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado exitosamente'), backgroundColor: Colors.green));
        CartModel.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar pedido: $e'), backgroundColor: Colors.red));
      }
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
          double totalUsd = 0.0;
          double totalBs = 0.0;
          for (var it in items) {
            final qty = (it['cantidad'] ?? 1) as int;
            totalUsd += ((it['precio'] as num).toDouble()) * qty;
            totalBs += ((it['precio_bs'] as num?)?.toDouble() ?? 0.0) * qty;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final qty = (item['cantidad'] ?? 1) as int;
                    final precio = (item['precio'] as num).toDouble();
                    final precioBs = (item['precio_bs'] as num?)?.toDouble() ?? 0.0;
                    final mensaje = (item['mensaje'] ?? '') as String;
                    return Card(
                      child: ListTile(
                        leading: item['imagen_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(item['imagen_url'],
                                    width: 50, height: 50, fit: BoxFit.cover),
                              )
                            : Icon(item['icono']),
                        title: Text(item['nombre']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cantidad: $qty'),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(text: 'Unitario: '),
                                  TextSpan(text: '\$${precio.toStringAsFixed(2)} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '(Bs ${precioBs.toStringAsFixed(2)})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(text: 'Subtotal: '),
                                  TextSpan(text: '\$${(precio * qty).toStringAsFixed(2)} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: '(Bs ${(precioBs * qty).toStringAsFixed(2)})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
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
                    Text('Total: \$${totalUsd.toStringAsFixed(2)} / Bs ${totalBs.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
