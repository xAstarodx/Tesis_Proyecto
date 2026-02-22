import 'package:flutter/material.dart';
import '../models/cart_model.dart';

class DetalleItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onAdd;
  const DetalleItem({super.key, required this.item, this.onAdd});

  @override
  State<DetalleItem> createState() => _DetalleItemState();
}

class _DetalleItemState extends State<DetalleItem> {
  int _cantidad = 1;
  final _controladorNota = TextEditingController();

  @override
  void dispose() {
    _controladorNota.dispose();
    super.dispose();
  }

  void _agregar() {
    final mapa = Map<String, dynamic>.from(widget.item);
    mapa['cantidad'] = _cantidad;
    mapa['mensaje'] = _controladorNota.text.trim();
    CartModel.add(mapa);
    Navigator.pop(context);
    if (widget.onAdd != null) widget.onAdd!();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
            children: [
              const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() { if (_cantidad > 1) _cantidad--; }),
              ),
              Text('$_cantidad', style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() { _cantidad++; }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controladorNota,
            decoration: const InputDecoration(
              labelText: 'Nota / Descripción (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _agregar,
                child: const Text('Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
