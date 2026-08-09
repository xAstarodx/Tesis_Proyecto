import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mis_pedidos.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  final _supabaseService = SupabaseService();
  List<NotificacionModel> _notificaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuarioId = await _supabaseService.getCurrentUserId();
      if (usuarioId == null) {
        setState(() {
          _error = 'Debes iniciar sesión';
          _cargando = false;
        });
        return;
      }
      final data = await _notificationService.obtenerNotificaciones(usuarioId);
      await _notificationService.marcarTodasComoLeidas(usuarioId);
      if (mounted) {
        setState(() {
          _notificaciones = data;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar notificaciones';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _alPresionar(NotificacionModel n) async {
    if (!n.leida) {
      await _notificationService.marcarComoLeida(n.id);
      setState(() {
        final i = _notificaciones.indexWhere((x) => x.id == n.id);
        if (i != -1) _notificaciones[i] = n.copyWith(leida: true);
      });
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MisPedidosPage()),
      );
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year} $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _notificaciones.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 80,
                              color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text('No tienes notificaciones por ahora',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _notificaciones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = _notificaciones[index];
                          return Card(
                            elevation: n.leida ? 0 : 2,
                            color: n.leida
                                ? AppTheme.cardBackground
                                : AppTheme.primaryColor.withValues(alpha: 0.06),
                            child: ListTile(
                              leading: Icon(
                                Icons.notifications,
                                color: n.leida ? AppTheme.textSecondary : AppTheme.primaryColor,
                              ),
                              title: Text(
                                n.titulo,
                                style: TextStyle(
                                    fontWeight: n.leida ? FontWeight.normal : FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(n.mensaje),
                                  const SizedBox(height: 4),
                                  Text(_formatearFecha(n.createdAt),
                                      style: TextStyle(
                                          fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                              trailing: n.leida
                                  ? null
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.errorColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              onTap: () => _alPresionar(n),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}