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
        subtitle: Text('\$${(item['precio'] as num).round()}'),
        onTap: onTap,
      ),
    );
  }
}
