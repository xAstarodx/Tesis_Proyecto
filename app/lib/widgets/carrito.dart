import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cart_model.dart';
import '../services/supabase_service.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _formasPago = [];
  final _referenciaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarFormasPago();
  }

  @override
  void dispose() {
    _referenciaController.dispose();
    super.dispose();
  }

  Widget _buildDatoPago(String titulo, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.blue),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: valor));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$titulo copiado'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copiar $titulo',
          ),
        ],
      ),
    );
  }

  Future<void> _cargarFormasPago() async {
    final formas = await _supabaseService.obtenerFormasPago();
    if (mounted) setState(() => _formasPago = formas);
  }

  void _enviarAlAdmin(List<Map<String, dynamic>> items) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'SELECCIONE HORA DE RECOGIDA',
    );
    if (picked == null) return;
    final horaRecogida = picked.format(context);

    final pedidoResumen = items
        .map((it) {
          final qty = (it['cantidad'] ?? 1) as int;
          final precio = (it['precio'] as num).toDouble();
          final precioBs = (it['precio_bs'] as num?)?.toDouble() ?? 0.0;
          final msg = (it['mensaje'] as String?)?.trim() ?? '';
          return '${it['nombre']} x$qty - \$${precio.toStringAsFixed(2)} (Bs ${precioBs.toStringAsFixed(2)})${msg.isNotEmpty ? ' (msg: $msg)' : ''}';
        })
        .join('\n');

    final contenido =
        'Hora de recogida: $horaRecogida\n\nPedido:\n$pedidoResumen';

    int formaPagoId = _formasPago.isNotEmpty
        ? _formasPago.first['forma_pago_id']
        : 1;

    _referenciaController.clear();
    File? comprobanteImage;
    String? errorMessage;
    final picker = ImagePicker();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Evita que se cierre al tocar fuera
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Verificar si es Pago Movil
          final selectedMetodo = _formasPago.firstWhere(
            (element) => element['forma_pago_id'] == formaPagoId,
            orElse: () => {'nombre_metodo': ''},
          );
          final esPagoMovil =
              selectedMetodo['nombre_metodo'].toString().toLowerCase().contains(
                'móvil',
              ) ||
              selectedMetodo['nombre_metodo'].toString().toLowerCase().contains(
                'movil',
              );

          return AlertDialog(
            title: const Text('Confirmar envío '),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contenido),
                  const SizedBox(height: 16),
                  const Text(
                    'Forma de Pago:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_formasPago.isEmpty)
                    const Text('Cargando formas de pago...')
                  else
                    DropdownButton<int>(
                      isExpanded: true,
                      value: formaPagoId,
                      items: _formasPago.map((fp) {
                        return DropdownMenuItem<int>(
                          value: fp['forma_pago_id'],
                          child: Text(fp['nombre_metodo']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => formaPagoId = val);
                        }
                      },
                    ),
                  if (esPagoMovil) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Datos Bancarios:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDatoPago('Banco', 'Banesco (0134)'),
                          _buildDatoPago('Teléfono', '0412-1234567'),
                          _buildDatoPago('Cédula', 'V-12.345.678'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Datos del Pago Móvil:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenciaController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Referencia (Texto)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null) {
                                setStateDialog(() {
                                  comprobanteImage = File(image.path);
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Adjuntar Foto'),
                          ),
                        ),
                        if (comprobanteImage != null)
                          const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                    if (comprobanteImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Imagen seleccionada',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (esPagoMovil) {
                    if (_referenciaController.text.trim().isEmpty &&
                        comprobanteImage == null) {
                      setStateDialog(() {
                        errorMessage =
                            'Debe ingresar referencia o foto del comprobante';
                      });
                      return;
                    }
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      try {
        await _supabaseService.enviarPedido(
          items: items,
          horaRecogida: horaRecogida,
          formaPagoId: formaPagoId,
          referencia: _referenciaController.text.trim().isEmpty
              ? null
              : _referenciaController.text.trim(),
          comprobanteImage: comprobanteImage,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        CartModel.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: CartModel.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(child: Text('Carrito vacío'));
          }
          double totalUsd = 0.0;
          double totalBs = 0.0;
          for (var it in items) {
            final qty = (it['cantidad'] ?? 1) as int;
            totalUsd += ((it['precio'] as num).toDouble()) * qty;
            totalBs += ((it['precio_bs'] as num?)?.toDouble() ?? 0.0) * qty;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final qty = (item['cantidad'] ?? 1) as int;
                    final precio = (item['precio'] as num).toDouble();
                    final precioBs =
                        (item['precio_bs'] as num?)?.toDouble() ?? 0.0;
                    final mensaje = (item['mensaje'] ?? '') as String;
                    return Card(
                      child: ListTile(
                        leading: item['imagen_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  item['imagen_url'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  cacheWidth: 100,
                                  cacheHeight: 100,
                                ),
                              )
                            : Icon(item['icono']),
                        title: Text(item['nombre']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cantidad: $qty'),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(text: 'Unitario: '),
                                  TextSpan(
                                    text: '\$${precio.toStringAsFixed(2)} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '(Bs ${precioBs.toStringAsFixed(2)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(text: 'Subtotal: '),
                                  TextSpan(
                                    text:
                                        '\$${(precio * qty).toStringAsFixed(2)} ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '(Bs ${(precioBs * qty).toStringAsFixed(2)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => CartModel.removeAt(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Total: \$${totalUsd.toStringAsFixed(2)} / Bs ${totalBs.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _enviarAlAdmin(items),
                      child: const Text('Enviar pedido '),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
