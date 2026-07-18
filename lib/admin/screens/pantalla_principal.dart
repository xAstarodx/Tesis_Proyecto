import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/producto_service.dart';
import '../../widgets/login.dart';
import '../../theme/app_theme.dart';

final productoService = ProductoService();

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;
  final _controladorTasa = TextEditingController();
  final _controladorBusquedaPedidos = TextEditingController();
  String _textoBusquedaPedidos = '';
  DateTime? _fechaInicioReporte;
  DateTime? _fechaFinReporte;

  static const List<String> _titulos = [
    'Dashboard',
    'Productos',
    'Pedidos',
    'Pagados',
    'Montos',
    'Reporte',
  ];
  static const List<IconData> _iconos = [
    Icons.dashboard_rounded,
    Icons.store,
    Icons.list_alt,
    Icons.history,
    Icons.attach_money,
    Icons.picture_as_pdf,
  ];

  List<Map<String, dynamic>> _todosLosProductos = [];
  List<Map<String, dynamic>> _listaPedidos = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _historialTasaCambio = [];

  double _tasaCambioValor = 1.0;
  bool _estaCargando = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  RealtimeChannel? _pedidosRealtime;

  @override
  void initState() {
    super.initState();
    _controladorTasa.text = _tasaCambioValor.toStringAsFixed(2);
    _controladorBusquedaPedidos.addListener(() {
      setState(() {
        _textoBusquedaPedidos = _controladorBusquedaPedidos.text;
      });
    });
    _cargarDatos();
    _escucharPedidos();
  }

  void _escucharPedidos() {
    _pedidosRealtime = Supabase.instance.client
        .channel('public:pedido')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedido',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              _audioPlayer.play(AssetSource('sounds/notificacion.mp3'));
            }
            _cargarDatos();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _controladorTasa.dispose();
    _controladorBusquedaPedidos.dispose();
    _audioPlayer.dispose();
    if (_pedidosRealtime != null) {
      Supabase.instance.client.removeChannel(_pedidosRealtime!);
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _estaCargando = true);
    try {

      final resultados = await Future.wait([
        productoService.obtenerTodosLosProductos(),
        productoService.obtenerTasaCambioInfo(),
        productoService.obtenerPedidos(),
        productoService.obtenerCategorias(),
        productoService.obtenerHistorialTasaCambio(),
      ]);

      final productos = resultados[0] as List<Map<String, dynamic>>;
      final tasaInfo = resultados[1] as Map<String, dynamic>?;
      final tasa = tasaInfo?['valor'] as double? ?? 1.0;
      final pedidos = resultados[2] as List<Map<String, dynamic>>;
      final categorias = resultados[3] as List<Map<String, dynamic>>;
      final historial = resultados[4] as List<Map<String, dynamic>>;

      setState(() {
        _todosLosProductos = productos;
        _listaPedidos = pedidos;
        _categorias = categorias;
        _historialTasaCambio = historial;
        _tasaCambioValor = tasa;
        _controladorTasa.text = _tasaCambioValor.toStringAsFixed(2);
      });
    } catch (e) {
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

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: (_fechaInicioReporte != null && _fechaFinReporte != null)
          ? DateTimeRange(start: _fechaInicioReporte!, end: _fechaFinReporte!)
          : null,
      helpText: 'Seleccionar rango de fechas para el reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      saveText: 'Guardar',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (rango != null) {
      setState(() {
        _fechaInicioReporte = rango.start;
        _fechaFinReporte = rango.end;
      });
    }
  }

  Future<void> _seleccionarFechaUnica() async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicioReporte ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Seleccionar una fecha para el reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() {
        _fechaInicioReporte = fecha;
        _fechaFinReporte = fecha;
      });
    }
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

    final datosPagoRaw = pedido['datos_pago_orden'];
    final Map<String, dynamic>? datosPago =
        (datosPagoRaw is List && datosPagoRaw.isNotEmpty)
        ? datosPagoRaw.first
        : (datosPagoRaw is Map ? datosPagoRaw : null);

    final referencia = datosPago?['referencia'];
    final comprobanteUrl = datosPago?['comprobante_url'];
    final notaGeneral = pedido['nota'];

    double totalUsd = 0.0;

    for (var d in detalles) {
      final cantidad = (d['cantidad'] as num).toDouble();
      final precio = (d['precio_unitario'] as num).toDouble();
      totalUsd += cantidad * precio;
    }

    final registrosPagos = pedido['registro_pagos'] as List<dynamic>?;
    double tasaParaCalculo = _tasaCambioValor;
    if (registrosPagos != null && registrosPagos.isNotEmpty) {
      final detallesPago =
          registrosPagos.first['detalle_pago'] as List<dynamic>?;
      if (detallesPago != null && detallesPago.isNotEmpty) {
        final tasaDolar = detallesPago.first['tasa_dolar'];
        if (tasaDolar != null && tasaDolar['valor'] != null) {
          tasaParaCalculo = (tasaDolar['valor'] as num).toDouble();
        }
      }
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
              if (notaGeneral != null && notaGeneral.toString().isNotEmpty) ...[
                const Text(
                  'MENSAJE DEL CLIENTE:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    notaGeneral.toString(),
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                const Divider(),
              ],
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
                  Builder(
                    builder: (ctx) {
                      final url = comprobanteUrl is String
                          ? comprobanteUrl
                          : null;
                      return url != null
                          ? GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: ctx,
                                  builder: (_) =>
                                      Dialog(child: Image.network(url)),
                                );
                              },
                              child: SizedBox(
                                height: 150,
                                child: Image.network(url, fit: BoxFit.cover),
                              ),
                            )
                          : const SizedBox.shrink();
                    },
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
                'Total Bs: Bs ${(totalUsd * tasaParaCalculo).toStringAsFixed(2)}',
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
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Proceso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.alarm_on),
                    label: const Text('Listo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 8
                        ? null
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                8,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.handshake),
                    label: const Text('Entregado y Pagado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 6
                        ? null
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                6,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
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
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Pagado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: pedido['estado_id'] == 4
                        ? null
                        : () async {
                            try {
                              await productoService.actualizarEstadoPedido(
                                pedido['pedido_id'],
                                4,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _cargarDatos();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
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

    final int pedidosNuevos = _listaPedidos
        .where((p) => p['estado_id'] == 1)
        .length;
    // El índice de Pedidos ahora es 2 (Dashboard=0, Productos=1, Pedidos=2)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: pedidosNuevos > 0
                ? Badge(
                    label: Text('$pedidosNuevos'),
                    backgroundColor: AppTheme.errorColor,
                    child: const Icon(Icons.menu),
                  )
                : const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              accountName: const Text(
                'Administrador',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              accountEmail: const Text(
                'Panel de Control',
                style: TextStyle(fontSize: 13),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'SECCIONES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  for (int i = 0; i < _titulos.length; i++)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _indiceSeleccionado == i
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: (i == 2 && pedidosNuevos > 0)
                            ? Badge(
                                label: Text('$pedidosNuevos'),
                                backgroundColor: AppTheme.errorColor,
                                child: Icon(
                                  _iconos[i],
                                  color: _indiceSeleccionado == i
                                      ? AppTheme.primaryColor
                                      : AppTheme.textSecondary,
                                  size: 20,
                                ),
                              )
                            : Icon(
                                _iconos[i],
                                color: _indiceSeleccionado == i
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                                size: 20,
                              ),
                      ),
                      title: Text(
                        _titulos[i],
                        style: TextStyle(
                          fontWeight: _indiceSeleccionado == i
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _indiceSeleccionado == i
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                      selected: _indiceSeleccionado == i,
                      selectedTileColor: AppTheme.primaryColor.withValues(
                        alpha: 0.05,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onTap: () {
                        _alTocarItem(i);
                        Navigator.pop(context);
                      },
                    ),
                  const Divider(height: 32),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: AppTheme.errorColor,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _cerrarSesion();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _construirCuerpoSegunIndice(_indiceSeleccionado),
    );
  }

  /// Calcula los productos más y menos vendidos a partir de los pedidos.
  List<MapEntry<String, int>> _calcularProductosPorVentas() {
    final Map<String, int> conteo = {};
    for (final pedido in _listaPedidos) {
      final detalles = pedido['detalle_pedido'] as List<dynamic>? ?? [];
      for (final detalle in detalles) {
        final nombre = detalle['productos']?['nombre'] as String? ?? 'Desconocido';
        final cantidad = (detalle['cantidad'] as num?)?.toInt() ?? 0;
        conteo[nombre] = (conteo[nombre] ?? 0) + cantidad;
      }
    }
    final entries = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Widget _construirDashboard() {
    final ventasPorProducto = _calcularProductosPorVentas();
    final int totalPedidos = _listaPedidos.length;
    final int pedidosPendientes = _listaPedidos.where((p) => p['estado_id'] == 1).length;
    final int pedidosCompletados = _listaPedidos.where((p) => p['estado_id'] == 6 || p['estado_id'] == 4).length;
    final int totalProductos = _todosLosProductos.length;

    // Top 5 más vendidos
    final masVendidos = ventasPorProducto.take(5).toList();
    // Top 5 menos vendidos (con al menos 1 venta)
    final menosVendidos = ventasPorProducto.reversed.take(5).toList();
    // Productos sin ventas
    final nombresConVentas = ventasPorProducto.map((e) => e.key).toSet();
    final sinVentas = _todosLosProductos
        .where((p) => !nombresConVentas.contains(p['nombre']))
        .toList();

    final int maxVentas = masVendidos.isNotEmpty ? masVendidos.first.value : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Resumen general de ventas y productos',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tarjetas de resumen ─────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _tarjetaResumen(
                    'Total Pedidos',
                    '$totalPedidos',
                    Icons.receipt_long_rounded,
                    AppTheme.primaryColor,
                  ),
                  _tarjetaResumen(
                    'Pendientes',
                    '$pedidosPendientes',
                    Icons.hourglass_empty_rounded,
                    AppTheme.warningColor,
                  ),
                  _tarjetaResumen(
                    'Completados',
                    '$pedidosCompletados',
                    Icons.check_circle_rounded,
                    AppTheme.successColor,
                  ),
                  _tarjetaResumen(
                    'Productos',
                    '$totalProductos',
                    Icons.store_rounded,
                    AppTheme.accentColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Más vendidos ────────────────────────────────────────────
          _seccionTitulo(
            '🏆 Productos más vendidos',
            AppTheme.successColor,
          ),
          const SizedBox(height: 12),
          masVendidos.isEmpty
              ? _mensajeVacio('No hay datos de ventas aún')
              : Column(
                  children: masVendidos.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final nombre = entry.value.key;
                    final cantidad = entry.value.value;
                    final porcentaje = maxVentas > 0 ? cantidad / maxVentas : 0.0;
                    return _filaProducto(
                      rank: rank,
                      nombre: nombre,
                      cantidad: cantidad,
                      porcentaje: porcentaje,
                      color: AppTheme.successColor,
                      esMasVendido: true,
                    );
                  }).toList(),
                ),
          const SizedBox(height: 24),

          // ── Menos vendidos ──────────────────────────────────────────
          _seccionTitulo(
            '📉 Productos menos vendidos',
            AppTheme.warningColor,
          ),
          const SizedBox(height: 12),
          menosVendidos.isEmpty
              ? _mensajeVacio('No hay datos de ventas aún')
              : Column(
                  children: menosVendidos.asMap().entries.map((entry) {
                    final nombre = entry.value.key;
                    final cantidad = entry.value.value;
                    final porcentaje = maxVentas > 0 ? cantidad / maxVentas : 0.0;
                    return _filaProducto(
                      rank: null,
                      nombre: nombre,
                      cantidad: cantidad,
                      porcentaje: porcentaje,
                      color: AppTheme.warningColor,
                      esMasVendido: false,
                    );
                  }).toList(),
                ),

          // ── Sin ventas ──────────────────────────────────────────────
          if (sinVentas.isNotEmpty) ...[
            const SizedBox(height: 24),
            _seccionTitulo('⚠️ Sin ventas registradas', AppTheme.errorColor),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sinVentas.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_shopping_cart_rounded,
                        size: 16,
                        color: AppTheme.errorColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p['nombre'] ?? 'Sin nombre',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.errorColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tarjetaResumen(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icono, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String titulo, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          mensaje,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      ),
    );
  }

  Widget _filaProducto({
    required int? rank,
    required String nombre,
    required int cantidad,
    required double porcentaje,
    required Color color,
    required bool esMasVendido,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rank != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: rank == 1
                        ? const Color(0xFFFFD700)
                        : rank == 2
                        ? const Color(0xFFC0C0C0)
                        : rank == 3
                        ? const Color(0xFFCD7F32)
                        : color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$cantidad uds',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCuerpoSegunIndice(int indice) {
    if (indice == 0) return _construirDashboard();
    if (indice == 4) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_tasaCambioValor.toStringAsFixed(2)} bs = 1\$',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '1\$',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controladorTasa,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[,.]?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Bs por 1\$',
                      ),
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
                          await _cargarDatos();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tasa de cambio actualizada'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
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
                        _controladorTasa.text = _tasaCambioValor
                            .toStringAsFixed(2);
                      }
                    },
                    child: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Historial de cambios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              _historialTasaCambio.isEmpty
                  ? const Text(
                      'No hay registros en el historial',
                      style: TextStyle(color: Colors.grey),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _historialTasaCambio.length,
                      itemBuilder: (context, index) {
                        final registro = _historialTasaCambio[index];
                        final valor = (registro['valor'] as num).toDouble();
                        final fechaMod = registro['fecha_mod'] as String?;
                        DateTime? fecha;
                        if (fechaMod != null) {
                          try {
                            fecha = DateTime.parse(fechaMod);
                          } catch (e) {

                          }
                        }

                        final esPrimero = index == 0;
                        final formatoFecha = fecha != null
                            ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                            : 'Fecha desconocida';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: esPrimero
                              ? Colors.blue.withValues(alpha: 0.1)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.access_time,
                              color: esPrimero ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              '${valor.toStringAsFixed(2)} bs = 1\$',
                              style: TextStyle(
                                fontWeight: esPrimero
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(formatoFecha),
                            trailing: esPrimero
                                ? const Chip(
                                    label: Text(
                                      'Actual',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.blue,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      );
    }

    Widget buildSearchField() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _controladorBusquedaPedidos,
          decoration: InputDecoration(
            hintText: 'Buscar por ID o cliente...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
            suffixIcon: _textoBusquedaPedidos.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _controladorBusquedaPedidos.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      );
    }

    if (indice == 5) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 750;
          final double horizontalPadding = isWide ? 32.0 : 24.0;

          Widget cardVentas = Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: AppTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reporte de Ventas (Pagados)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Resumen de productos vendidos en pedidos pagados o entregados.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _fechaInicioReporte != null && _fechaFinReporte != null
                                  ? (_fechaInicioReporte == _fechaFinReporte
                                      ? 'Fecha: ${_fechaInicioReporte!.day.toString().padLeft(2, '0')}/${_fechaInicioReporte!.month.toString().padLeft(2, '0')}/${_fechaInicioReporte!.year}'
                                      : 'Rango: ${_fechaInicioReporte!.day.toString().padLeft(2, '0')}/${_fechaInicioReporte!.month.toString().padLeft(2, '0')}/${_fechaInicioReporte!.year} al ${_fechaFinReporte!.day.toString().padLeft(2, '0')}/${_fechaFinReporte!.month.toString().padLeft(2, '0')}/${_fechaFinReporte!.year}')
                                  : 'Todos los registros (sin filtro de fecha)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _fechaInicioReporte != null
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _estaCargando ? null : _seleccionarFechaUnica,
                                    icon: const Icon(Icons.today, size: 16),
                                    label: const Text('Elegir Día', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _estaCargando ? null : _seleccionarRangoFechas,
                                    icon: const Icon(Icons.date_range, size: 16),
                                    label: const Text('Elegir Rango', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                if (_fechaInicioReporte != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _estaCargando
                                        ? null
                                        : () {
                                            setState(() {
                                              _fechaInicioReporte = null;
                                              _fechaFinReporte = null;
                                            });
                                          },
                                    icon: const Icon(Icons.clear, size: 18),
                                    color: AppTheme.errorColor,
                                    tooltip: 'Limpiar filtro',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _estaCargando ? null : _generarPDFReporte,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('DESCARGAR REPORTE DE VENTAS'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          Widget cardPendientes = Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: AppTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pending_actions, color: AppTheme.warningColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reporte de Pedidos Pendientes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Genera un documento con todos los pedidos en preparación, listos o nuevos para facilitar el despacho.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      if (isWide) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 86,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.pending_actions_outlined,
                            size: 48,
                            color: AppTheme.dividerColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _estaCargando ? null : _generarPDFReportePedidosPendientes,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('DESCARGAR REPORTE PENDIENTES'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.warningColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Generar Reportes PDF',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona el tipo de reporte que deseas generar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (isWide)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cardVentas),
                            const SizedBox(width: 16),
                            Expanded(child: cardPendientes),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          cardVentas,
                          const SizedBox(height: 16),
                          cardPendientes,
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (indice == 3) {
      final query = _textoBusquedaPedidos.toLowerCase();
      final pedidosPagados = _listaPedidos
          .where((p) => p['estado_id'] == 4 || p['estado_id'] == 6)
          .where((p) {
            if (query.isEmpty) return true;
            final id = p['pedido_id'].toString().toLowerCase();
            final cliente = (p['usuario']?['nombre'] ?? '')
                .toString()
                .toLowerCase();
            return id.contains(query) || cliente.contains(query);
          })
          .toList();

      return Column(
        children: [
          buildSearchField(),
          Expanded(
            child: _estaCargando
                ? const Center(child: CircularProgressIndicator())
                : pedidosPagados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay pedidos pagados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los pedidos completados aparecerán aquí',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pedidosPagados.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final pedido = pedidosPagados[i];
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

                        final registros =
                            pedido['registro_pagos'] as List<dynamic>?;
                        double tasaAplicada = _tasaCambioValor;
                        if (registros != null && registros.isNotEmpty) {
                          final detallesPago =
                              registros.first['detalle_pago'] as List<dynamic>?;
                          if (detallesPago != null && detallesPago.isNotEmpty) {
                            final tasaDolar = detallesPago.first['tasa_dolar'];
                            if (tasaDolar != null &&
                                tasaDolar['valor'] != null) {
                              tasaAplicada = (tasaDolar['valor'] as num)
                                  .toDouble();
                            }
                          }
                        }

                        final totalBs = totalUsd * tasaAplicada;
                        final cliente =
                            pedido['usuario']?['nombre'] ?? 'Desconocido';
                        final estado =
                            pedido['estado']?['etiqueta'] ?? 'Pagado';
                        final formaPago =
                            pedido['forma_pago']?['nombre_metodo'] ?? 'N/A';

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _mostrarDetallePedido(pedido),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: AppTheme.successColor,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pedido #${pedido['pedido_id']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cliente,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    detalleTexto,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet,
                                        size: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formaPago,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '\$${totalUsd.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            Text(
                                              'Bs ${totalBs.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        onPressed: () =>
                                            _mostrarDetallePedido(pedido),
                                        tooltip: 'Ver detalle',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    }

    if (indice == 2) {
      final query = _textoBusquedaPedidos.toLowerCase();
      final pedidosPendientes = _listaPedidos

          .where(
            (p) =>
                p['estado_id'] != 4 &&
                p['estado_id'] != 6 &&
                p['estado_id'] != 5,
          )
          .where((p) {
            if (query.isEmpty) return true;
            final id = p['pedido_id'].toString().toLowerCase();
            final cliente = (p['usuario']?['nombre'] ?? '')
                .toString()
                .toLowerCase();
            return id.contains(query) || cliente.contains(query);
          })
          .toList();

      return Column(
        children: [
          buildSearchField(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedidos Pendientes (${pedidosPendientes.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
              ],
            ),
          ),
          Expanded(
            child: _estaCargando
                ? const Center(child: CircularProgressIndicator())
                : pedidosPendientes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 80,
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay pedidos pendientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Los nuevos pedidos aparecerán aquí',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pedidosPendientes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final pedido = pedidosPendientes[i];
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
                        final cliente =
                            pedido['usuario']?['nombre'] ?? 'Desconocido';
                        final horaRecogida =
                            pedido['hora_recogida'] ?? 'Sin hora';
                        final estado =
                            pedido['estado']?['etiqueta'] ?? 'Pendiente';
                        final formaPago =
                            pedido['forma_pago']?['nombre_metodo'] ?? 'N/A';

                        Color getEstadoColor(int estadoId) {
                          switch (estadoId) {
                            case 1:
                              return AppTheme.warningColor;
                            case 2:
                              return AppTheme.primaryColor;
                            case 3:
                              return AppTheme.accentColor;
                            default:
                              return AppTheme.textSecondary;
                          }
                        }

                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _mostrarDetallePedido(pedido),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: getEstadoColor(
                                            pedido['estado_id'] as int,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          pedido['estado_id'] == 1
                                              ? Icons.pending_outlined
                                              : pedido['estado_id'] == 2
                                              ? Icons.restaurant
                                              : Icons.local_shipping_outlined,
                                          color: getEstadoColor(
                                            pedido['estado_id'] as int,
                                          ),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pedido #${pedido['pedido_id']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              cliente,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: getEstadoColor(
                                            pedido['estado_id'] as int,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Text(
                                    detalleTexto,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        horaRecogida,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.payment,
                                        size: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        formaPago,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '\$${totalUsd.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Bs ${totalBs.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility_outlined,
                                              color: AppTheme.primaryColor,
                                            ),
                                            onPressed: () =>
                                                _mostrarDetallePedido(pedido),
                                            tooltip: 'Ver detalle',
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: AppTheme.errorColor,
                                            ),
                                            onPressed: () =>
                                                _confirmarEliminarPedido(
                                                  pedido['pedido_id'],
                                                ),
                                            tooltip: 'Eliminar pedido',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    }

    if (_estaCargando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _mostrarDialogoAgregarProducto,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Añadir Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay productos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega tu primer producto',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: _todosLosProductos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final producto = _todosLosProductos[i];
                      final categoria = _categorias.firstWhere(
                        (cat) =>
                            cat['categoria_id'] == producto['categoria_id'],
                        orElse: () => {'nombre_categoria': 'Sin categoría'},
                      );
                      final categoriaEtiqueta =
                          (categoria['nombre_categoria'] as String?) ??
                          'Sin categoría';
                      final precioUsd =
                          (producto['precio'] as num?)?.toDouble() ?? 0.0;
                      final stock = (producto['stock'] as num?)?.toInt() ?? 0;

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 1,
                        child: InkWell(
                          onTap: () => _mostrarDialogoEditarProducto(producto),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: AppTheme.backgroundColor,
                                    border: Border.all(color: AppTheme.dividerColor),
                                  ),
                                  child: producto['imagen_url'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            producto['imagen_url'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(Icons.restaurant_menu),
                                          ),
                                        )
                                      : const Icon(Icons.restaurant_menu),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        producto['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          categoriaEtiqueta,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            stock > 0 ? Icons.inventory : Icons.error_outline,
                                            size: 14,
                                            color: stock > 0 ? AppTheme.textSecondary : AppTheme.errorColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Stock: $stock',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: stock > 0 ? AppTheme.textSecondary : AppTheme.errorColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.accentGradient,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '\$${precioUsd.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          color: AppTheme.primaryColor,
                                          onPressed: () => _mostrarDialogoEditarProducto(producto),
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          color: AppTheme.errorColor,
                                          onPressed: () => _confirmarEliminarProducto(producto['producto_id']),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Añadir producto'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
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
                  TextFormField(
                    controller: controladorNombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es obligatorio'
                        : null,
                  ),
                  TextFormField(
                    controller: controladorDescripcion,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'La descripción es obligatoria'
                        : null,
                  ),
                  TextFormField(
                    controller: controladorCantidad,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Número inválido';
                      final n = int.tryParse(v);
                      if (n == null) return 'Número inválido';
                      if (n < 0) return 'La cantidad no puede ser negativa';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: controladorPrecio,
                    decoration: const InputDecoration(
                      labelText: 'Precio (USD)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[,.]?\d*'),
                      ),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Precio inválido';
                      final p = double.tryParse(v.replaceAll(',', '.'));
                      if (p == null) return 'Precio inválido';
                      if (p <= 0) return 'El precio debe ser mayor a cero';
                      return null;
                    },
                  ),
                ],
              ),
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
                if (!(formKey.currentState?.validate() ?? false) ||
                    categoriaSeleccionadaId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, rellene todos los campos'),
                    ),
                  );
                  return;
                }
                final nombre = controladorNombre.text.trim();
                final descripcion = controladorDescripcion.text.trim();
                final cantidad = int.tryParse(controladorCantidad.text);
                final precio = double.tryParse(
                  controladorPrecio.text.replaceAll(',', '.'),
                );

                if (cantidad == null || precio == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valores numéricos inválidos'),
                    ),
                  );
                  return;
                }

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

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

                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Producto guardado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
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
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Editar ${producto['nombre'] ?? ''}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
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
                  TextFormField(
                    controller: controladorNombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controladorDescripcion,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'La descripción es obligatoria'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controladorCantidad,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Inválido';
                      final n = int.tryParse(v);
                      if (n == null) return 'Inválido';
                      if (n < 0) return 'La cantidad no puede ser negativa';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controladorPrecio,
                    decoration: const InputDecoration(
                      labelText: 'Precio (USD)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[,.]?\d*'),
                      ),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Inválido';
                      final p = double.tryParse(v.replaceAll(',', '.'));
                      if (p == null) return 'Inválido';
                      if (p <= 0) return 'El precio debe ser mayor a cero';
                      return null;
                    },
                  ),
                ],
              ),
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
                if (!(formKey.currentState?.validate() ?? false)) return;

                final nombre = controladorNombre.text.trim();
                final descripcion = controladorDescripcion.text.trim();
                final int? cantidad = int.tryParse(controladorCantidad.text);
                final double? precio = double.tryParse(
                  controladorPrecio.text.replaceAll(',', '.'),
                );
                final int productoId = producto['producto_id'] as int;

                if (cantidad == null || precio == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Valores numéricos inválidos'),
                    ),
                  );
                  return;
                }

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

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
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Producto actualizado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar: $e'),
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

  Future<void> _generarPDFReporte() async {
    setState(() => _estaCargando = true);
    try {

      var pedidosPagados = _listaPedidos
          .where((p) => p['estado_id'] == 4 || p['estado_id'] == 6)
          .toList();

      if (_fechaInicioReporte != null && _fechaFinReporte != null) {
        final inicio = DateTime(
          _fechaInicioReporte!.year,
          _fechaInicioReporte!.month,
          _fechaInicioReporte!.day,
          0,
          0,
          0,
        );
        final fin = DateTime(
          _fechaFinReporte!.year,
          _fechaFinReporte!.month,
          _fechaFinReporte!.day,
          23,
          59,
          59,
          999,
        );
        pedidosPagados = pedidosPagados.where((p) {
          if (p['fecha_creacion'] == null) return false;
          final fechaPed = DateTime.parse(p['fecha_creacion'] as String).toLocal();
          return fechaPed.isAfter(inicio.subtract(const Duration(milliseconds: 1))) &&
              fechaPed.isBefore(fin.add(const Duration(milliseconds: 1)));
        }).toList();
      }

      if (pedidosPagados.isEmpty) {
        if (_fechaInicioReporte != null && _fechaFinReporte != null) {
          final fIni = '${_fechaInicioReporte!.day.toString().padLeft(2, '0')}/${_fechaInicioReporte!.month.toString().padLeft(2, '0')}/${_fechaInicioReporte!.year}';
          final fFin = '${_fechaFinReporte!.day.toString().padLeft(2, '0')}/${_fechaFinReporte!.month.toString().padLeft(2, '0')}/${_fechaFinReporte!.year}';
          if (_fechaInicioReporte == _fechaFinReporte) {
            throw Exception('No hay pedidos pagados en la fecha seleccionada ($fIni).');
          } else {
            throw Exception('No hay pedidos pagados en el rango de fechas seleccionado ($fIni al $fFin).');
          }
        } else {
          throw Exception('No hay pedidos pagados para generar el reporte.');
        }
      }

      final Map<String, Map<String, dynamic>> aggregated = {};
      double granTotal = 0;
      double granTotalBs = 0;

      for (var p in pedidosPagados) {

        final registrosPagos = p['registro_pagos'] as List<dynamic>?;
        double tasaAplicada = _tasaCambioValor;
        if (registrosPagos != null && registrosPagos.isNotEmpty) {
          final detallesPago =
              registrosPagos.first['detalle_pago'] as List<dynamic>?;
          if (detallesPago != null && detallesPago.isNotEmpty) {
            final tasaDolar = detallesPago.first['tasa_dolar'];
            if (tasaDolar != null && tasaDolar['valor'] != null) {
              tasaAplicada = (tasaDolar['valor'] as num).toDouble();
            }
          }
        }

        final detalles = p['detalle_pedido'] as List<dynamic>? ?? [];
        for (var d in detalles) {
          final nombre = d['productos']?['nombre'] ?? 'Producto Desconocido';
          final cant = (d['cantidad'] as num).toDouble();
          final precio = (d['precio_unitario'] as num).toDouble();
          final subtotal = cant * precio;
          final subtotalBs = subtotal * tasaAplicada;

          if (aggregated.containsKey(nombre)) {
            aggregated[nombre]!['cantidad'] += cant;
            aggregated[nombre]!['total'] += subtotal;
            aggregated[nombre]!['total_bs'] += subtotalBs;
          } else {
            aggregated[nombre] = {
              'nombre': nombre,
              'cantidad': cant,
              'precio_unitario': precio,
              'total': subtotal,
              'total_bs': subtotalBs,
            };
          }
          granTotal += subtotal;
          granTotalBs += subtotalBs;
        }
      }

      final ventas = aggregated.values.toList();
      final pdf = pw.Document();
      final fecha = DateTime.now().toString().split('.')[0];

      final String tituloReporte;
      if (_fechaInicioReporte != null && _fechaFinReporte != null) {
        final fIni = '${_fechaInicioReporte!.day.toString().padLeft(2, '0')}/${_fechaInicioReporte!.month.toString().padLeft(2, '0')}/${_fechaInicioReporte!.year}';
        final fFin = '${_fechaFinReporte!.day.toString().padLeft(2, '0')}/${_fechaFinReporte!.month.toString().padLeft(2, '0')}/${_fechaFinReporte!.year}';
        if (_fechaInicioReporte == _fechaFinReporte) {
          tituloReporte = 'Reporte de Ventas ($fIni)';
        } else {
          tituloReporte = 'Reporte de Ventas ($fIni al $fFin)';
        }
      } else {
        tituloReporte = 'Reporte de Ventas - General';
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('$tituloReporte - Cafetín ISABORES'),
                      pw.Text(fecha, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Resumen de Productos Vendidos (Pagados):',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Producto',
                    'Cant.',
                    'P. Unit (USD)',
                    'Total (USD)',
                    'Total (Bs)',
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  data: ventas
                      .map(
                        (v) => [
                          v['nombre'],
                          v['cantidad'].toString(),
                          '\$${(v['precio_unitario'] as num).toStringAsFixed(2)}',
                          '\$${(v['total'] as num).toStringAsFixed(2)}',
                          'Bs ${(v['total_bs'] as num).toStringAsFixed(2)}',
                        ],
                      )
                      .toList(),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TOTAL GENERAL (USD): \$${granTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'TOTAL GENERAL (BS): Bs ${granTotalBs.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
          },
        ),
      );

      final String nombrePdf;
      if (_fechaInicioReporte != null && _fechaFinReporte != null) {
        final fIni = '${_fechaInicioReporte!.day.toString().padLeft(2, '0')}-${_fechaInicioReporte!.month.toString().padLeft(2, '0')}-${_fechaInicioReporte!.year}';
        final fFin = '${_fechaFinReporte!.day.toString().padLeft(2, '0')}-${_fechaFinReporte!.month.toString().padLeft(2, '0')}-${_fechaFinReporte!.year}';
        if (_fechaInicioReporte == _fechaFinReporte) {
          nombrePdf = 'Reporte_Ventas_ISABORES_$fIni.pdf';
        } else {
          nombrePdf = 'Reporte_Ventas_ISABORES_${fIni}_a_$fFin.pdf';
        }
      } else {
        nombrePdf = 'Reporte_Ventas_ISABORES.pdf';
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => pdf.save(),
        name: nombrePdf,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  Future<void> _generarPDFReportePedidosPendientes() async {
    setState(() => _estaCargando = true);
    try {
      final pedidosPendientes = _listaPedidos
          .where(
            (p) =>
                p['estado_id'] != 4 &&
                p['estado_id'] != 6 &&
                p['estado_id'] != 5,
          )
          .toList();

      if (pedidosPendientes.isEmpty) {
        throw Exception('No hay pedidos pendientes para generar el reporte.');
      }

      final pdf = pw.Document();
      final fecha = DateTime.now().toString().split('.')[0];

      double granTotalUsd = 0.0;
      for (var p in pedidosPendientes) {
        final detalles = p['detalle_pedido'] as List<dynamic>? ?? [];
        for (var d in detalles) {
          granTotalUsd += (d['cantidad'] as num) * (d['precio_unitario'] as num);
        }
      }
      final granTotalBs = granTotalUsd * _tasaCambioValor;

      final List<List<String>> tableData = [];
      for (var p in pedidosPendientes) {
        final id = '#${p['pedido_id']}';
        final cliente = p['usuario']?['nombre'] ?? 'Desconocido';
        final correo = p['usuario']?['correo'] ?? 'Sin correo';

        final fechaPed = p['fecha_creacion'] != null
            ? DateTime.parse(p['fecha_creacion'] as String).toLocal().toString().split('.')[0]
            : 'N/A';
        final horaRecogida = p['hora_recogida'] ?? 'Sin hora';
        final estado = p['estado']?['etiqueta'] ?? 'Pendiente';
        final formaPago = p['forma_pago']?['nombre_metodo'] ?? 'N/A';

        final detalles = p['detalle_pedido'] as List<dynamic>? ?? [];
        double totalPedido = 0.0;
        final detalleTexto = detalles.map((d) {
          final prod = d['productos'];
          final cant = d['cantidad'];
          final precio = d['precio_unitario'] as num;
          totalPedido += cant * precio;
          final desc = d['Descripcion'] != null && d['Descripcion'].toString().isNotEmpty
              ? ' (${d['Descripcion']})'
              : '';
          return '${prod?['nombre'] ?? 'Producto'} x$cant$desc';
        }).join('\n');

        final totalBsPedido = totalPedido * _tasaCambioValor;

        tableData.add([
          id,
          '$cliente\n$correo',
          'Creación:\n$fechaPed\nRecogida:\n$horaRecogida',
          detalleTexto,
          '$formaPago\n$estado',
          '\$${totalPedido.toStringAsFixed(2)}\nBs ${totalBsPedido.toStringAsFixed(2)}',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reporte de Pedidos Pendientes - Cafetín ISABORES',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
                    ),
                    pw.Text(fecha, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Pedidos pendientes de preparación o entrega (${pedidosPendientes.length}):',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  'ID',
                  'Cliente',
                  'Fechas / Horas',
                  'Productos / Detalles',
                  'Pago / Estado',
                  'Total',
                ],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.topLeft,
                cellAlignments: {
                  0: pw.Alignment.topCenter,
                  5: pw.Alignment.topRight,
                },
                data: tableData,
                columnWidths: const {
                  0: pw.FixedColumnWidth(35),
                  1: pw.FixedColumnWidth(90),
                  2: pw.FixedColumnWidth(95),
                  3: pw.FixedColumnWidth(170),
                  4: pw.FixedColumnWidth(70),
                  5: pw.FixedColumnWidth(70),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TOTAL PENDIENTE (USD): \$${granTotalUsd.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'TOTAL PENDIENTE (BS): Bs ${granTotalBs.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final String nombrePdf = 'Reporte_Pedidos_Pendientes_ISABORES_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => pdf.save(),
        name: nombrePdf,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }
}
