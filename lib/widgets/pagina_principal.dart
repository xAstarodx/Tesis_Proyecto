import 'package:flutter/material.dart';
import 'elemento_menu.dart';
import 'detalle_item.dart';
import 'carrito.dart';
import '../services/supabase_service.dart';
import '../models/producto_model.dart';
import 'login.dart';
import 'mis_pedidos.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SupabaseService _svc = SupabaseService();
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _categorias = [];
  bool _loading = true;
  String _search = '';
  String? _error;
  RealtimeChannel? _productosChannel;
  RealtimeChannel? _tasaChannel;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _suscribirARealtime();
  }

  void _suscribirARealtime() {
    _productosChannel = _svc.suscribirATabla(
      tabla: 'productos',
      alCambiar: _loadProductos,
    );
    _tasaChannel = _svc.suscribirATabla(
      tabla: 'tasa_dolar',
      alCambiar: _loadProductos,
    );
  }

  @override
  void dispose() {
    if (_productosChannel != null) {
      _svc.unsubscribeFromChannel(_productosChannel!);
    }
    if (_tasaChannel != null) _svc.unsubscribeFromChannel(_tasaChannel!);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductos() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final resultados = await Future.wait([
        _svc.obtenerProductos(),
        _svc.obtenerTasaCambio(),
        _svc.obtenerCategorias(),
      ]);

      final productos = resultados[0] as List<Producto>;
      final tasa = resultados[1] as double;
      final categorias = resultados[2] as List<Map<String, dynamic>>;

      setState(() {
        _categorias = categorias;

        _menuItems = productos.where((p) => p.stok > 0).map((p) {
          return {
            'nombre': p.nombre,
            'precio': p.precio,
            'precio_bs': p.precio * tasa,
            'descripcion': p.descripcion ?? '',
            'icono': Icons.fastfood,
            'producto_id': p.productoId,
            'imagen_url': p.imagenUrl,
            'categoria_id': p.categoriaId,
            'stock': p.stok,
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
        .where(
          (it) => it['nombre'].toString().toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Cafetín ISABORES')),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              accountName: const Text(
                'Bienvenido',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              accountEmail: const Text(
                'Cafetín ISABORES - IUTEPAL',
                style: TextStyle(fontSize: 13),
              ),
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: const Text(
                      'Mis Pedidos',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MisPedidosPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 24),
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
      body: Column(
        children: [

          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '¿Qué deseas ordenar hoy?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _search = val;
                });
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error cargando productos',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _loadProductos,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : (_menuItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay productos disponibles',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _loadProductos,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Recargar'),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadProductos,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount:
                                      _categorias.length +
                                      (filtered.any(
                                            (it) => it['categoria_id'] == null,
                                          )
                                          ? 1
                                          : 0),
                                  itemBuilder: (context, catIndex) {

                                    if (catIndex == _categorias.length) {
                                      if (!filtered.any(
                                        (it) => it['categoria_id'] == null,
                                      )) {
                                        return const SizedBox.shrink();
                                      }
                                      return _construirSeccionCategoria(
                                        context,
                                        'OTROS',
                                        filtered
                                            .where(
                                              (it) =>
                                                  it['categoria_id'] == null,
                                            )
                                            .toList(),
                                      );
                                    }

                                    final cat = _categorias[catIndex];
                                    final productosCat = filtered
                                        .where(
                                          (it) =>
                                              it['categoria_id'] ==
                                              cat['categoria_id'],
                                        )
                                        .toList();

                                    if (productosCat.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return _construirSeccionCategoria(
                                      context,
                                      cat['nombre_categoria'].toString(),
                                      productosCat,
                                    );
                                  },
                                ),
                              ))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CarritoPage()),
          );
        },
        icon: const Icon(Icons.shopping_cart),
        label: const Text('Carrito'),
      ),
    );
  }

  Widget _construirSeccionCategoria(
    BuildContext context,
    String nombreCategoria,
    List<Map<String, dynamic>> productos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                nombreCategoria.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ...productos.map(
          (item) => ElementoMenu(item: item, onTap: () => _showDetails(item)),
        ),
      ],
    );
  }

  void _showDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return DetalleItem(
              item: item,
              onAdd: () {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('${item['nombre']} agregado al carrito'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
