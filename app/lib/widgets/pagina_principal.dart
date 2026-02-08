import 'package:flutter/material.dart';
import 'elemento_menu.dart';
import 'detalle_item.dart';
import 'carrito.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Map<String, dynamic>> _menuItems = [
    {
      'nombre': 'Empanada',
      'precio': 1,
      'descripcion': 'Empanada de Pollo, al euro',
      'icono': Icons.fastfood,
    },
    {
      'nombre': 'Café',
      'precio': 1,
      'descripcion': 'Café negro (ni modo que blanco), al euro',
      'icono': Icons.coffee,
    },
    {
      'nombre': 'Hamburguesa',
      'precio': 2,
      'descripcion': 'hamburguesa con todo, como te gusta, al euro',
      'icono': Icons.lunch_dining,
    },
    {
      'nombre': 'Jugo',
      'precio': 1,
      'descripcion': 'compalte, al euro',
      'icono': Icons.local_drink,
    },
  ];

  final String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _menuItems
        .where((it) => it['nombre']
            .toString()
            .toLowerCase()
            .contains(_search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Cafetín ISABORES - IUTEPAL'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            for (var item in filtered)
              ElementoMenu(
                item: item,
                onTap: () => _showDetails(item),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CarritoPage()),
          );
        },
        tooltip: 'Carrito',
        child: const Icon(Icons.shopping_cart),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return DetalleItem(
          item: item,
          onAdd: () {
            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(content: Text('${item['nombre']} agregado ')),
            );
          },
        );
      },
    );
  }
}
