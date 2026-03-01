import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/producto_service.dart';
import '../../widgets/login.dart';

final productoService = ProductoService();

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;
  final _controladorTasa = TextEditingController();

  static const List<String> _titulos = [
    'Comida',
    'Bebida',
    'Pedidos',
    'Montos',
  ];
  static const List<IconData> _iconos = [
    Icons.fastfood,
    Icons.local_drink,
    Icons.list_alt,
    Icons.attach_money,
  ];

  List<Map<String, dynamic>> _productosComida = [];
  List<Map<String, dynamic>> _productosBebida = [];
  List<Map<String, dynamic>> _listaPedidos = [];

  double _tasaCambio = 1.0;
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _controladorTasa.text = _tasaCambio.toStringAsFixed(2);
    _cargarProductos();
  }

  @override
  void dispose() {
    _controladorTasa.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _estaCargando = true);
    try {
      final comida = await productoService.obtenerProductosPorCategoria(2);
      final bebida = await productoService.obtenerProductosPorCategoria(1);
      final tasa = await productoService.obtenerTasaCambio();
      final pedidos = await productoService.obtenerPedidos();

      setState(() {
        _productosComida = comida;
        _productosBebida = bebida;
        _listaPedidos = pedidos;
        _tasaCambio = tasa;
        _controladorTasa.text = _tasaCambio.toStringAsFixed(2);
      });
    } catch (e) {
      print('Error cargando productos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  void _alTocarItem(int indice) {
    setState(() {
      _indiceSeleccionado = indice;
    });
  }

  void _confirmarEliminarPedido(int pedidoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pedido'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este pedido?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await productoService.eliminarPedido(pedidoId);
                _cargarProductos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pedido eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarProducto(int productoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este producto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await productoService.eliminarProducto(productoId);
                await _cargarProductos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallePedido(Map<String, dynamic> pedido) {
    final detalles = (pedido['detalle_pedido'] as List<dynamic>? ?? []);
    final cliente = pedido['usuario']?['nombre'] ?? 'Desconocido';
    final correo = pedido['usuario']?['correo'] ?? 'Sin correo';
    final fecha = pedido['fecha_creacion'] != null
        ? DateTime.parse(
            pedido['fecha_creacion'],
          ).toLocal().toString().split('.')[0]
        : '';
    final horaRecogida = pedido['hora_recogida'] ?? 'No especificada';

    double totalUsd = 0.0;

    for (var d in detalles) {
      final cantidad = (d['cantidad'] as num).toDouble();
      final precio = (d['precio_unitario'] as num).toDouble();
      totalUsd += cantidad * precio;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pedido #${pedido['pedido_id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cliente: $cliente',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Correo: $correo'),
              Text('Fecha: $fecha'),
              Text(
                'Hora Recogida: $horaRecogida',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              const Text(
                'Productos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...detalles.map((d) {
                final prod = d['productos'];
                final cantidad = d['cantidad'] as num;
                final precio = d['precio_unitario'] as num;
                final subtotal = cantidad * precio;
                final desc =
                    d['Descripcion'] != null &&
                        d['Descripcion'].toString().isNotEmpty
                    ? '\nNota: ${d['Descripcion']}'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${prod?['nombre'] ?? 'Producto'} (x$cantidad)'),
                      Text(
                        'Precio: \$${precio.toStringAsFixed(2)} - Subtotal: \$${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      if (desc.isNotEmpty)
                        Text(
                          desc.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const Divider(),
              Text(
                'Total USD: \$${totalUsd.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Total Bs: Bs ${(totalUsd * _tasaCambio).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
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
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
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
    if (indice == 3) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Column(
              children: [
                Text(
                  '${_tasaCambio.toStringAsFixed(2)} bs = 1\$',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '1\$',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _controladorTasa,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Bs por 1\$'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final double? valor = double.tryParse(
                      _controladorTasa.text.replaceAll(',', '.'),
                    );
                    if (valor != null && valor > 0) {
                      try {
                        await productoService.actualizarTasaCambio(valor);
                        setState(() {
                          _tasaCambio = valor;
                        });
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tasa de cambio actualizada'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Valor inválido'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      _controladorTasa.text = _tasaCambio.toStringAsFixed(2);
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

    if (indice == 2) {
      return _estaCargando
          ? const Center(child: CircularProgressIndicator())
          : _listaPedidos.isEmpty
          ? const Center(child: Text('No hay pedidos recientes'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _listaPedidos.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final pedido = _listaPedidos[i];
                final detalles =
                    (pedido['detalle_pedido'] as List<dynamic>? ?? []);

                double totalUsd = 0.0;
                final detalleTexto = detalles
                    .map((d) {
                      final prod = d['productos'];
                      final subtotal =
                          (d['cantidad'] as num) *
                          (d['precio_unitario'] as num);
                      totalUsd += subtotal;
                      final desc =
                          d['Descripcion'] != null &&
                              d['Descripcion'].toString().isNotEmpty
                          ? ' (${d['Descripcion']})'
                          : '';
                      return '${prod?['nombre'] ?? 'Producto'} x${d['cantidad']}$desc';
                    })
                    .join(', ');

                final totalBs = totalUsd * _tasaCambio;
                final fecha = pedido['fecha_creacion'] != null
                    ? DateTime.parse(
                        pedido['fecha_creacion'],
                      ).toLocal().toString().split('.')[0]
                    : '';
                final cliente = pedido['usuario']?['nombre'] ?? 'Desconocido';
                final horaRecogida = pedido['hora_recogida'] ?? 'Sin hora';

                return ListTile(
                  title: Text('Cliente: $cliente'),
                  subtitle: Text(
                    '$detalleTexto\n\nFecha: $fecha\nHora Recogida: $horaRecogida',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${totalUsd.toStringAsFixed(2)}\nBs ${totalBs.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _confirmarEliminarPedido(pedido['pedido_id']),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () => _mostrarDetallePedido(pedido),
                );
              },
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
            child: _estaCargando
                ? const Center(child: CircularProgressIndicator())
                : productos.isEmpty
                ? Center(
                    child: Text(
                      'No hay productos en ${_titulos[indice]}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: productos.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) {
                      final producto = productos[i];
                      final precioUsd =
                          (producto['precio'] as num?)?.toDouble() ?? 0.0;
                      final valorBs = precioUsd * _tasaCambio;
                      return ListTile(
                        title: Text(producto['nombre'] ?? 'Sin nombre'),
                        subtitle: Text(
                          'Cantidad: ${producto['stock'] ?? 0}    Valor: \$${precioUsd.toStringAsFixed(2)} (${valorBs.toStringAsFixed(2)} bs)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _mostrarDialogoEditarProducto(
                                producto,
                                esComida,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmarEliminarProducto(
                                producto['producto_id'],
                              ),
                            ),
                          ],
                        ),
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
    File? imagenSeleccionada;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Añadir producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      setStateDialog(() {
                        imagenSeleccionada = File(pickedFile.path);
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: imagenSeleccionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imagenSeleccionada!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Colors.grey,
                                size: 40,
                              ),
                              Text('Seleccionar Imagen'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controladorNombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: controladorDescripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                TextField(
                  controller: controladorCantidad,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: controladorPrecio,
                  decoration: const InputDecoration(labelText: 'Precio (USD)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nombre = controladorNombre.text.trim();
                final descripcion = controladorDescripcion.text.trim();
                final cantidad = int.tryParse(controladorCantidad.text);
                final precio = double.tryParse(
                  controladorPrecio.text.replaceAll(',', '.'),
                );

                if (nombre.isEmpty || cantidad == null || precio == null)
                  return;

                try {
                  await productoService.guardarProducto(
                    nombre: nombre,
                    descripcion: descripcion,
                    precioUsd: precio,
                    stock: cantidad,
                    categoriaId: esComida ? 2 : 1,
                    imagenFile: imagenSeleccionada,
                  );

                  await _cargarProductos();

                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto guardado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('Error: $e');
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarProducto(
    Map<String, dynamic> producto,
    bool esComida,
  ) {
    final controladorNombre = TextEditingController(
      text: producto['nombre'] ?? '',
    );
    final controladorDescripcion = TextEditingController(
      text: producto['descripcion'] ?? '',
    );
    final controladorCantidad = TextEditingController(
      text: (producto['stock'] ?? 0).toString(),
    );
    final controladorPrecio = TextEditingController(
      text: ((producto['precio'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(
        2,
      ),
    );
    File? imagenSeleccionada;
    final String? imagenActualUrl = producto['imagen_url'];

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Editar ${producto['nombre'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      setStateDialog(() {
                        imagenSeleccionada = File(pickedFile.path);
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: imagenSeleccionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imagenSeleccionada!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : (imagenActualUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imagenActualUrl,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      color: Colors.grey,
                                      size: 40,
                                    ),
                                    Text('Cambiar Imagen'),
                                  ],
                                )),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controladorNombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: controladorDescripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                TextField(
                  controller: controladorCantidad,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: controladorPrecio,
                  decoration: const InputDecoration(labelText: 'Precio (USD)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nombre = controladorNombre.text.trim();
                final descripcion = controladorDescripcion.text.trim();
                final int? cantidad = int.tryParse(controladorCantidad.text);
                final double? precio = double.tryParse(
                  controladorPrecio.text.replaceAll(',', '.'),
                );
                final int? productoId = producto['producto_id'];

                if (nombre.isEmpty ||
                    cantidad == null ||
                    precio == null ||
                    productoId == null) {
                  return;
                }

                try {
                  await productoService.actualizarProducto(
                    productoId: productoId,
                    nombre: nombre,
                    descripcion: descripcion,
                    stock: cantidad,
                    precioUsd: precio,
                    imagenFile: imagenSeleccionada,
                  );
                  await _cargarProductos();
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Producto actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}
