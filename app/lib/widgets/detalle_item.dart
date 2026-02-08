import 'package:flutter/material.dart';
import '../models/cart_model.dart';

class DetalleItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onAdd;
  const DetalleItem({super.key, required this.item, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item['icono'], size: 36),
              const SizedBox(width: 12),
              Text(item['nombre'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('\$${(item['precio'] as num).round()}', style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(item['descripcion'] ?? '', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              ElevatedButton(
                onPressed: () {
                  CartModel.add(item);
                  Navigator.pop(context);
                  if (onAdd != null) onAdd!();
                },
                child: const Text('Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
