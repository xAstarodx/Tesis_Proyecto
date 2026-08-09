import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _cliente = Supabase.instance.client;

  Future<List<NotificacionModel>> obtenerNotificaciones(String usuarioId) async {
    try {
      final data = await _cliente
          .from('notificaciones')
          .select()
          .eq('usuario_id', usuarioId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((e) => NotificacionModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');
      return [];
    }
  }

  Future<int> contarNoLeidas(String usuarioId) async {
    try {
      final data = await _cliente
          .from('notificaciones')
          .select('notificacion_id')
          .eq('usuario_id', usuarioId)
          .eq('leida', false);
      return (data as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> marcarComoLeida(String notificacionId) async {
    try {
      await _cliente
          .from('notificaciones')
          .update({'leida': true})
          .eq('notificacion_id', notificacionId);
    } catch (e) {
      debugPrint('Error al marcar como leída: $e');
    }
  }

  Future<void> marcarTodasComoLeidas(String usuarioId) async {
    try {
      await _cliente
          .from('notificaciones')
          .update({'leida': true})
          .eq('usuario_id', usuarioId)
          .eq('leida', false);
    } catch (e) {
      debugPrint('Error al marcar todas como leídas: $e');
    }
  }

  RealtimeChannel suscribirse({
    required String usuarioId,
    required void Function(PostgresChangePayload payload) onInsert,
  }) {
    final channel = _cliente.channel('public:notificaciones:usuario_id=eq.$usuarioId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'usuario_id',
            value: usuarioId,
          ),
          callback: onInsert,
        )
        .subscribe();
    return channel;
  }

  Future<void> cancelarSuscripcion(RealtimeChannel channel) async {
    await _cliente.removeChannel(channel);
  }
}