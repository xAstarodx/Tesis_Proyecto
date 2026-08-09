class NotificacionModel {
  final String id;
  final String usuarioId;
  final int pedidoId;
  final String titulo;
  final String mensaje;
  final int? estadoId;
  final bool leida;
  final DateTime createdAt;

  NotificacionModel({
    required this.id,
    required this.usuarioId,
    required this.pedidoId,
    required this.titulo,
    required this.mensaje,
    this.estadoId,
    required this.leida,
    required this.createdAt,
  });

  factory NotificacionModel.fromMap(Map<String, dynamic> map) {
    return NotificacionModel(
      id: map['notificacion_id'] as String,
      usuarioId: map['usuario_id'] as String,
      pedidoId: map['pedido_id'] as int,
      titulo: map['titulo'] as String? ?? '',
      mensaje: map['mensaje'] as String? ?? '',
      estadoId: map['estado_id'] as int?,
      leida: map['leida'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  NotificacionModel copyWith({bool? leida}) => NotificacionModel(
        id: id,
        usuarioId: usuarioId,
        pedidoId: pedidoId,
        titulo: titulo,
        mensaje: mensaje,
        estadoId: estadoId,
        leida: leida ?? this.leida,
        createdAt: createdAt,
      );
}