import 'package:flutter/material.dart';
import '../services/producto_service.dart';
import '../models/producto.dart';
import '../../widgets/login.dart';

final productoService = ProductoService();

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;

  static const List<String> _titulos = ['Comida', 'Bebida', 'Montos'];
  static const List<IconData> _iconos = [
    Icons.fastfood,
    Icons.local_drink,
    Icons.attach_money,
  ];

  final List<Producto> _productosComida = [];
  final List<Producto> _productosBebida = [];

  double _tasaCambio = 1.0;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final comida = await productoService.obtenerProductosPorCategoria(2);
      final bebida = await productoService.obtenerProductosPorCategoria(1);

      setState(() {
        _productosComida.clear();
        _productosBebida.clear();

        for (var p in comida) {
          _productosComida.add(
            Producto(
              nombre: p['nombre'] ?? 'Sin nombre',
              cantidad: p['stock'] ?? 0,
              precioUsd: (p['precio'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }

        for (var p in bebida) {
          _productosBebida.add(
            Producto(
              nombre: p['nombre'] ?? 'Sin nombre',
              cantidad: p['stock'] ?? 0,
              precioUsd: (p['precio'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
      });
    } catch (e) {
      print('Error cargando productos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _alTocarItem(int indice) {
    setState(() {
      _indiceSeleccionado = indice;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: _construirCuerpoSegunIndice(_indiceSeleccionado),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceSeleccionado,
        onTap: _alTocarItem,
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: List.generate(_titulos.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_iconos[index]),
            label: _titulos[index],
          );
        }),
      ),
    );
  }

  Widget _construirCuerpoSegunIndice(int indice) {
    if (indice == 2) {
      final controladorTasa = TextEditingController(text: _tasaCambio.toStringAsFixed(2));
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Column(
              children: [
                Text('${_tasaCambio.toStringAsFixed(2)} bs = 1\$',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('1\$', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: controladorTasa,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Bs por 1\$'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    final double? valor = double.tryParse(controladorTasa.text.replaceAll(',', '.'));
                    if (valor != null && valor > 0) {
                      setState(() {
                        _tasaCambio = valor;
                      });
                    }
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final esComida = indice == 0;
    final productos = esComida ? _productosComida : _productosBebida;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
            ),
            onPressed: () => _mostrarDialogoAgregarProducto(esComida),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.add_circle_outline, size: 26),
                SizedBox(width: 10),
                Text(
                  'Añadir producto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: productos.isEmpty
                ? Center(
                    child: Text('No hay productos en ${_titulos[indice]}',
                        style: const TextStyle(fontSize: 16)),
                  )
                : ListView.separated(
                    itemCount: productos.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final p = productos[i];
                      final valorBs = p.precioUsd * _tasaCambio;
                      return ListTile(
                        title: Text(p.nombre),
                        subtitle: Text(
                            'Cantidad: ${p.cantidad}    Valor: \$${p.precioUsd.toStringAsFixed(2)} (${valorBs.toStringAsFixed(2)} bs)'),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _mostrarDialogoEditarProducto(esComida, i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAgregarProducto(bool esComida) {
    final controladorNombre = TextEditingController();
    final controladorDescripcion = TextEditingController();
    final controladorPrecio = TextEditingController();
    final controladorCantidad = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controladorNombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: controladorDescripcion, decoration: const InputDecoration(labelText: 'Descripción')),
            TextField(controller: controladorCantidad, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
            TextField(controller: controladorPrecio, decoration: const InputDecoration(labelText: 'Precio (USD)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              final nombre = controladorNombre.text.trim();
              final descripcion = controladorDescripcion.text.trim();
              final cantidad = int.tryParse(controladorCantidad.text);
              final precio = double.tryParse(controladorPrecio.text.replaceAll(',', '.'));

              if (nombre.isEmpty || cantidad == null || precio == null) return;

              try {
                await productoService.guardarProducto(
                  nombre: nombre,
                  descripcion: descripcion,
                  precioUsd: precio,
                  stock: cantidad,
                  categoriaId: esComida ? 2 : 1,
                );

                await _cargarProductos();

                Navigator.of(context).pop();
              } catch (e) {
                print('Error: $e');
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarProducto(bool esComida, int indice) {
    final lista = esComida ? _productosComida : _productosBebida;
    final producto = lista[indice];

    final controladorCantidad = TextEditingController(text: producto.cantidad.toString());
    final controladorPrecio = TextEditingController(text: producto.precioUsd.toStringAsFixed(2));

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${producto.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: controladorCantidad, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number),
            TextField(controller: controladorPrecio, decoration: const InputDecoration(labelText: 'Valor (USD)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              final int? cantidad = int.tryParse(controladorCantidad.text);
              final double? precio = double.tryParse(controladorPrecio.text.replaceAll(',', '.'));
              if (cantidad == null || precio == null) return;

              setState(() {
                lista[indice] = producto.copiarCon(cantidad: cantidad, precioUsd: precio);
              });

              Navigator.of(context).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
