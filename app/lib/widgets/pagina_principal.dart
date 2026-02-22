import 'package:flutter/material.dart';
import 'elemento_menu.dart';
import 'detalle_item.dart';
import 'carrito.dart';
import '../services/supabase_service.dart';
import 'login.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SupabaseService _svc = SupabaseService();
  List<Map<String, dynamic>> _menuItems = [];
  bool _loading = true;
  final String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProductos();
  }

  Future<void> _loadProductos() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final productos = await _svc.obtenerProductos();
      final tasa = await _svc.obtenerTasaCambio();
      setState(() {
        _menuItems = productos.map((p) {
          
          return {
            'nombre': p.nombre,
            'precio': p.precio,
            'precio_bs': p.precio * tasa,
            'descripcion': p.descripcion ?? '',
            'icono': Icons.fastfood, // Puedes asignar íconos según la categoría o tipo de producto
            'producto_id': p.productoId,
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
        _menuItems = [];
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await _svc.cerrarSesion();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Error cargando productos:\n$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadProductos, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : (_menuItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No hay productos disponibles'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadProductos, child: const Text('Recargar')),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          for (var item in filtered)
                            ElementoMenu(
                              item: item,
                              onTap: () => _showDetails(item),
                            ),
                        ],
                      ))),
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
