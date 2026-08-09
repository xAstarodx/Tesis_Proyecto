import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../screens/notifications_screen.dart';

class NotificationBellIcon extends StatefulWidget {
  const NotificationBellIcon({super.key});

  @override
  State<NotificationBellIcon> createState() => _NotificationBellIconState();
}

class _NotificationBellIconState extends State<NotificationBellIcon> {
  final _notificationService = NotificationService();
  final _supabaseService = SupabaseService();
  final _audioPlayer = AudioPlayer();
  RealtimeChannel? _channel;
  String? _usuarioId;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final usuarioId = await _supabaseService.getCurrentUserId();
    if (usuarioId == null || !mounted) return;
    _usuarioId = usuarioId;
    await _cargarConteo();
    _channel = _notificationService.suscribirse(
      usuarioId: usuarioId,
      onInsert: (payload) {
        _reproducirSonido();
        _cargarConteo();
      },
    );
  }

  Future<void> _cargarConteo() async {
    if (_usuarioId == null) return;
    final conteo = await _notificationService.contarNoLeidas(_usuarioId!);
    if (mounted) setState(() => _noLeidas = conteo);
  }

  void _reproducirSonido() {
    try {
      _audioPlayer.play(AssetSource('sounds/notificacion.mp3'));
    } catch (e) {
      debugPrint('Error reproduciendo notificación: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_channel != null) {
      _notificationService.cancelarSuscripcion(_channel!);
    }
    super.dispose();
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    _cargarConteo();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: _abrirNotificaciones,
          tooltip: 'Notificaciones',
        ),
        if (_noLeidas > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _noLeidas > 9 ? '9+' : '$_noLeidas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}