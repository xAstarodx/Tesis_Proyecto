import 'package:flutter/material.dart';

class ElementoMenu extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  const ElementoMenu({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(item['icono']),
        title: Text(item['nombre']),
        subtitle: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(text: '\$${(item['precio'] as num).toStringAsFixed(2)} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextSpan(text: '(Bs ${(item['precio_bs'] as num).toStringAsFixed(2)})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
