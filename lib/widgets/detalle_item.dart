import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../theme/app_theme.dart';

class DetalleItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onAdd;

  const DetalleItem({super.key, required this.item, this.onAdd});

  @override
  State<DetalleItem> createState() => _DetalleItemState();
}

class _DetalleItemState extends State<DetalleItem> {
  int _cantidad = 1;
  final _controladorNota = TextEditingController();

  @override
  void dispose() {
    _controladorNota.dispose();
    super.dispose();
  }

  void _agregar() {
    final int stockDisponible = widget.item['stock'] ?? 0;

    final itemsEnCarrito = CartModel.items.value;
    final index = itemsEnCarrito.indexWhere(
      (it) => it['producto_id'] == widget.item['producto_id'],
    );

    int cantidadEnCarrito = 0;
    if (index != -1) {
      cantidadEnCarrito = itemsEnCarrito[index]['cantidad'] ?? 0;
    }

    if (cantidadEnCarrito + _cantidad > stockDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay suficiente stock. Disponible: $stockDisponible '
            '(Ya tienes $cantidadEnCarrito en el carrito)',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } else {
      final mapa = Map<String, dynamic>.from(widget.item);
      mapa['cantidad'] = _cantidad;
      mapa['mensaje'] = _controladorNota.text.trim();

      CartModel.add(mapa);
      Navigator.pop(context);

      if (widget.onAdd != null) widget.onAdd!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final precioTotal = ((item['precio'] as num?) ?? 0) * _cantidad;
    final precioBsTotal = ((item['precio_bs'] as num?) ?? 0) * _cantidad;
    final int stockDisponible = item['stock'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _BotonCerrar(
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'product_${item['producto_id']}',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.backgroundColor,
                    border: Border.all(color: AppTheme.dividerColor, width: 1),
                  ),
                  child: item['imagen_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item['imagen_url'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            cacheHeight: 200,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.restaurant_menu,
                                  size: 40,
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            item['icono'] ?? Icons.restaurant_menu,
                            size: 40,
                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nombre'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        '\$${precioTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bs ${precioBsTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Disponible: $stockDisponible',
                      style: TextStyle(
                        fontSize: 13,
                        color: stockDisponible < 5
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (item['descripcion'] != null &&
              item['descripcion'].toString().isNotEmpty) ...[
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              item['descripcion'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  'Cantidad:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (_cantidad > 1) {
                              setState(() => _cantidad--);
                            }
                          },
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(8),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.remove,
                              color: _cantidad > 1
                                  ? AppTheme.primaryColor
                                  : AppTheme.dividerColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$_cantidad',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (_cantidad < stockDisponible) {
                              setState(() => _cantidad++);
                            }
                          },
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(8),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.add,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controladorNota,
            decoration: const InputDecoration(
              labelText: 'Nota adicional (opcional)',
              hintText: 'Ej: Sin cebolla, extra queso...',
              prefixIcon: Icon(
                Icons.note_outlined,
                color: AppTheme.primaryColor,
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _agregar,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: Text(
                'Agregar - \$${precioTotal.toStringAsFixed(2)}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonCerrar extends StatefulWidget {
  final VoidCallback onPressed;

  const _BotonCerrar({required this.onPressed});

  @override
  State<_BotonCerrar> createState() => _BotonCerrarState();
}

class _BotonCerrarState extends State<_BotonCerrar> {
  bool _activo = false;

  void _setActivo(bool valor) {
    if (mounted && _activo != valor) {
      setState(() => _activo = valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar',
      child: Tooltip(
        message: 'Cerrar',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setActivo(true),
          onTapCancel: () => _setActivo(false),
          onTapUp: (_) {
            _setActivo(false);
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _activo ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _activo
                    ? AppTheme.errorColor.withValues(alpha: 0.16)
                    : AppTheme.errorColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.errorColor.withValues(
                    alpha: _activo ? 0.35 : 0.18,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}