import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

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
    try {
      _audioPlayer.play(AssetSource('sounds/notificacion.mp3'));
    } catch (e) {
      debugPrint('Error reproduciendo notificación: $e');
    }
  }

  Future<void> _suscribirACambios() async {
    final userId = await _supabaseService.getCurrentUserId();
    if (userId == null || !mounted) return;

    _pedidosChannel = _supabaseService.subscribeToPedidos(
      userId: userId,
      onUpdate: (payload) {
        final newRecord = payload.newRecord;

        if (newRecord.isNotEmpty) {
          final pedidoId = newRecord['pedido_id'];
          final nuevoEstado = newRecord['estado_id'];

          final pedidoLocal = _pedidos.firstWhere(
            (p) => p['pedido_id'] == pedidoId,
            orElse: () => {},
          );
          final estadoAnterior = pedidoLocal.isNotEmpty
              ? pedidoLocal['estado_id']
              : null;

          if (nuevoEstado == 2 && estadoAnterior != 2) {
            _reproducirSonidoNotificacion();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Tu pedido está En Proceso'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPedidos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No has realizado pedidos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus pedidos aparecerán aquí',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarPedidos,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pedidos.length,
                itemBuilder: (context, index) {
                  final pedido = _pedidos[index];
                  final estado = pedido['estado']?['etiqueta'] ?? 'Procesando';
                  final estadoId = pedido['estado_id'] as int?;
                  final horaRecogida =
                      pedido['hora_recogida'] ?? 'No especificada';
                  final detalles =
                      (pedido['detalle_pedido'] as List<dynamic>? ?? []);

                  double total = 0;
                  for (var d in detalles) {
                    total +=
                        ((d['cantidad'] as num?) ?? 0) * ((d['precio_unitario'] as num?) ?? 0);
                  }

                  Color getEstadoColor() {
                    switch (estadoId) {
                      case 1:
                        return AppTheme.warningColor;
                      case 2:
                        return AppTheme.primaryColor;
                      case 3:
                        return AppTheme.accentColor;
                      case 4:
                      case 6:
                        return AppTheme.successColor;
                      case 5:
                        return AppTheme.errorColor;
                      default:
                        return AppTheme.textSecondary;
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: getEstadoColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          estadoId == 4 || estadoId == 6
                              ? Icons.check_circle
                              : estadoId == 5
                              ? Icons.cancel
                              : estadoId == 2
                              ? Icons.restaurant
                              : Icons.pending,
                          color: getEstadoColor(),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        'Pedido #${pedido['pedido_id']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: getEstadoColor(),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  estado,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Recogida: $horaRecogida',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Productos:',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ...detalles.map<Widget>((d) {
                                final prodNombre =
                                    d['productos']?['nombre'] ?? 'Producto';
                                final cant = (d['cantidad'] as num?) ?? 0;
                                final precio = (d['precio_unitario'] as num?) ?? 0;
                                final subtotal = cant * precio;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentColor,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              prodNombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '$cant x \$${(precio).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.accentGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
