import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MisPedidosPage extends StatefulWidget {
  const MisPedidosPage({super.key});

  @override
  State<MisPedidosPage> createState() => _MisPedidosPageState();
}

class _MisPedidosPageState extends State<MisPedidosPage> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;
  final _audioPlayer = AudioPlayer();
  RealtimeChannel? _pedidosChannel;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    // Cargamos primero para tener el estado base local
    await _cargarPedidos();
    if (mounted) _suscribirACambios();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_pedidosChannel != null) {
      _supabaseService.unsubscribeFromChannel(_pedidosChannel!);
    }
    super.dispose();
  }

  void _reproducirSonidoNotificacion() {
    _audioPlayer.play(AssetSource('sounds/notification.mp3'));
  }

  Future<void> _suscribirACambios() async {
    final userId = await _supabaseService.getCurrentUserId();
    if (userId == null || !mounted) return;

    _pedidosChannel = _supabaseService.subscribeToPedidos(
      userId: userId,
      onUpdate: (payload) {
        final newRecord = payload.newRecord;

        final pedidoId = newRecord['pedido_id'];
        final nuevoEstado = newRecord['estado_id'];

        // Buscamos el estado que tenía este pedido en nuestra lista local
        final pedidoLocal = _pedidos.firstWhere(
          (p) => p['pedido_id'] == pedidoId,
          orElse: () => {},
        );
        final estadoAnterior = pedidoLocal.isNotEmpty
            ? pedidoLocal['estado_id']
            : null;

        // Solo notificamos si el estado cambió a 2 (Listo) y antes NO era 2
        if (nuevoEstado == 2 && estadoAnterior != 2) {
          _reproducirSonidoNotificacion();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡Tu pedido #$pedidoId está listo para recoger!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
        // Recargar la lista para mostrar el estado actualizado
        if (mounted) {
          _cargarPedidos();
        }
      },
    );
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
                final formaPago =
                    pedido['forma_pago']?['nombre_metodo'] ?? 'N/A';
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
                      'Estado: $estado\nPago: $formaPago\nFecha: $fecha\nHora Recogida: $horaRecogida\nTotal: \$${total.toStringAsFixed(2)}',
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
