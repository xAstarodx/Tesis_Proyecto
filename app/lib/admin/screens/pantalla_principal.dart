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

  static const List<String> _titulos = ['Productos', 'Pedidos', 'Montos'];
  static const List<IconData> _iconos = [
    Icons.store,
    Icons.list_alt,
    Icons.attach_money,
  ];

  List<Map<String, dynamic>> _todosLosProductos = [];
  List<Map<String, dynamic>> _listaPedidos = [];
  List<Map<String, dynamic>> _categorias = [];

  double _tasaCambioValor = 1.0;
  int? _tasaCambioId; // To store the ID of the exchange rate
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _controladorTasa.text = _tasaCambioValor.toStringAsFixed(2);
    _cargarDatos();
  }

  @override
  void dispose() {
    _controladorTasa.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _estaCargando = true);
    try {
      // Optimización: Carga paralela de todos los recursos
      final resultados = await Future.wait([
        productoService.obtenerTodosLosProductos(),
        productoService.obtenerTasaCambioInfo(), // Use the new method
        productoService.obtenerPedidos(),
        productoService.obtenerCategorias(),
      ]);

      final productos = resultados[0] as List<Map<String, dynamic>>;
      final tasaInfo = resultados[1] as Map<String, dynamic>?;
      final tasa = tasaInfo?['valor'] as double? ?? 1.0;
      final tasaId = tasaInfo?['id'] as int?;
      final pedidos = resultados[2] as List<Map<String, dynamic>>;
      final categorias = resultados[3] as List<Map<String, dynamic>>;

      setState(() {
        _todosLosProductos = productos;
        _listaPedidos = pedidos;
        _categorias = categorias;
        _tasaCambioValor = tasa;
        _tasaCambioId = tasaId;
        _controladorTasa.text = _tasaCambioValor.toStringAsFixed(2);
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
                _cargarDatos();
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
                await _cargarDatos();
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
    final formaPago =
        pedido['forma_pago']?['nombre_metodo'] ?? 'No especificada';

    final datosPago = pedido['datos_pago_orden'];
    final referencia = datosPago?['referencia'];
    final comprobanteUrl = datosPago?['comprobante_url'];

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
              Text('Forma de Pago: $formaPago'),
              const Divider(),
              if (referencia != null || comprobanteUrl != null) ...[
                const Text(
                  'Datos de Pago del Usuario:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                if (referencia != null) Text('Referencia: $referencia'),
                if (comprobanteUrl != null) ...[
                  const SizedBox(height: 8),
                  const Text('Comprobante:'),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) =>
                            Dialog(child: Image.network(comprobanteUrl)),
                      );
                    },
                    child: SizedBox(
                      height: 150,
                      child: Image.network(comprobanteUrl, fit: BoxFit.cover),
                    ),
                  ),
                ],
                const Divider(),
              ],
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
                'Total Bs: Bs ${(totalUsd * _tasaCambioValor).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue,
                ),
              ),
              const Divider(),
              const Text(
                'Cambiar Estado:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Listo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 2
                        ? null
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                2,
                              );
                              Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 3
                        ? null
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                3,
                              );
                              Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Pagado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 4
                        ? null // Disable if already paid
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                4, // Estado 'Pagado'
                              );
                              Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                ],
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
        ],
      ),
      backgroundColor: Colors.white,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu Admin',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            for (int i = 0; i < _titulos.length; i++)
              ListTile(
                leading: Icon(_iconos[i]),
                title: Text(_titulos[i]),
                selected: _indiceSeleccionado == i,
                onTap: () {
                  _alTocarItem(i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: _construirCuerpoSegunIndice(_indiceSeleccionado),
    );
  }

  Widget _construirCuerpoSegunIndice(int indice) {
    if (indice == 2) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            if (_tasaCambioValor != null)
              Column(
                children: [
                  Text(
                    '${_tasaCambioValor.toStringAsFixed(2)} bs = 1\$',
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
                        await _cargarDatos(); // Reload all data including new tasa ID
                        if (!context.mounted) return;
                        setState(() {
                          // Update local state if _cargarDatos didn't trigger a full rebuild
                          _tasaCambioValor = valor;
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
                      _controladorTasa.text = _tasaCambioValor.toStringAsFixed(
                        2,
                      );
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

    if (indice == 1) {
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

                final totalBs = totalUsd * _tasaCambioValor;
                final fecha = pedido['fecha_creacion'] != null
                    ? DateTime.parse(
                        pedido['fecha_creacion'],
                      ).toLocal().toString().split('.')[0]
                    : '';
                final cliente = pedido['usuario']?['nombre'] ?? 'Desconocido';
                final horaRecogida = pedido['hora_recogida'] ?? 'Sin hora';
                final estado = pedido['estado']?['etiqueta'] ?? 'Pendiente';
                final formaPago =
                    pedido['forma_pago']?['nombre_metodo'] ?? 'N/A';

                return ListTile(
                  title: Text('Cliente: $cliente'),
                  subtitle: Text(
                    'Estado: $estado\nPago: $formaPago\n$detalleTexto\n\nFecha: $fecha\nHora Recogida: $horaRecogida',
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
                  isThreeLine: false,
                  onTap: () => _mostrarDetallePedido(pedido),
                );
              },
            );
    }

    // Indice 0: Productos
    if (_estaCargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _mostrarDialogoAgregarProducto,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Añadir Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _todosLosProductos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: _todosLosProductos.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) {
                    final producto = _todosLosProductos[i];
                    final categoria = _categorias.firstWhere(
                      (cat) => cat['categoria_id'] == producto['categoria_id'],
                      orElse: () => {'nombre_categoria': 'Sin categoría'},
                    );
                    final categoriaEtiqueta =
                        (categoria['nombre_categoria'] as String?) ??
                        'Sin categoría';
                    final precioUsd =
                        (producto['precio'] as num?)?.toDouble() ?? 0.0;
                    final valorBs = precioUsd * _tasaCambioValor;
                    return ListTile(
                      title: Text(producto['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(
                        'Cantidad: ${producto['stock'] ?? 0} | \$${precioUsd.toStringAsFixed(2)} (Bs ${valorBs.toStringAsFixed(2)})',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _mostrarDialogoEditarProducto(producto),
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
    );
  }

  void _mostrarDialogoAgregarProducto() {
    final controladorNombre = TextEditingController();
    final controladorDescripcion = TextEditingController();
    final controladorPrecio = TextEditingController();
    final controladorCantidad = TextEditingController();
    File? imagenSeleccionada;
    int? categoriaSeleccionadaId;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Añadir producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _categorias.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'No se encontraron categorías. Por favor, añada categorías en la base de datos para poder crear productos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : DropdownButtonFormField<int>(
                        initialValue: categoriaSeleccionadaId,
                        hint: const Text('Seleccionar Categoría'),
                        items: _categorias.map((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['categoria_id'] as int,
                            child: Text(
                              (cat['nombre_categoria'] as String?) ??
                                  'Sin Etiqueta',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setStateDialog(() {
                            categoriaSeleccionadaId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Seleccione una categoría' : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                const SizedBox(height: 16),
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

                if (nombre.isEmpty ||
                    cantidad == null ||
                    precio == null ||
                    categoriaSeleccionadaId == null) {
                  return;
                }

                try {
                  await productoService.guardarProducto(
                    nombre: nombre,
                    descripcion: descripcion,
                    precioUsd: precio,
                    stock: cantidad,
                    categoriaId: categoriaSeleccionadaId!,
                    imagenFile: imagenSeleccionada,
                  );

                  await _cargarDatos();

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

  void _mostrarDialogoEditarProducto(Map<String, dynamic> producto) {
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
                  await _cargarDatos();
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
