import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MisPedidosPage extends StatefulWidget {
  const MisPedidosPage({super.key});

  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    final pedidos = await _supabaseService.obtenerMisPedidos();
    if (mounted) {
      setState(() {
        _pedidos = pedidos;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
          ? const Center(child: Text('No has realizado pedidos '))
          : ListView.builder(
              itemCount: _pedidos.length,
              itemBuilder: (context, index) {
                final pedido = _pedidos[index];
                final estado = pedido['estado']?['etiqueta'] ?? 'Procesando';
                final fecha = pedido['fecha_creacion'] != null
                    ? DateTime.parse(
                        pedido['fecha_creacion'],
                      ).toLocal().toString().split('.')[0]
                    : '';
                final horaRecogida =
                    pedido['hora_recogida'] ?? 'No especificada';
                final detalles =
                    (pedido['detalle_pedido'] as List<dynamic>? ?? []);

                double total = 0;
                for (var d in detalles) {
                  total +=
                      (d['cantidad'] as num) * (d['precio_unitario'] as num);
                }

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ExpansionTile(
                    title: Text('Pedido #${pedido['pedido_id']}'),
                    subtitle: Text(
                      'Estado: $estado\nFecha: $fecha\nHora Recogida: $horaRecogida\nTotal: \$${total.toStringAsFixed(2)}',
                    ),
                    children: detalles.map<Widget>((d) {
                      final prodNombre =
                          d['productos']?['nombre'] ?? 'Producto';
                      final cant = d['cantidad'];
                      final precio = d['precio_unitario'];
                      return ListTile(
                        title: Text(prodNombre),
                        subtitle: Text('Cantidad: $cant - Precio: \$$precio'),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
