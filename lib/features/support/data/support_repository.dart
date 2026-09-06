import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/support/data/support_models.dart';

/// Accès REST au support. Pas de temps réel ni de cache : la liste et le
/// détail sont rechargés à l'ouverture de l'écran ou après un envoi.
class SupportRepository {
  SupportRepository(this._api);

  final ApiClient _api;

  Future<List<SupportPredefinedReply>> loadReplies() async {
    final response = await _api.dio.get('/support/replies');
    final list = response.data as List<dynamic>? ?? const [];
    return list
        .map((e) => SupportPredefinedReply.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupportTicket>> loadTickets({int page = 0, int size = 50}) async {
    final response = await _api.dio.get(
      '/support/tickets',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data as Map<String, dynamic>? ?? const {};
    final content = data['content'] as List<dynamic>? ?? const [];
    return content
        .map((e) => SupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    String? message,
    List<String> attachmentKeys = const [],
  }) async {
    final response = await _api.dio.post(
      '/support/tickets',
      data: {
        'category': category,
        'subject': subject,
        'message': message,
        'attachmentKeys': attachmentKeys,
      },
    );
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SupportTicket> loadTicket(String ticketId) async {
    final response = await _api.dio.get('/support/tickets/$ticketId');
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SupportMessage> sendMessage(
    String ticketId,
    String content,
    List<String> attachmentKeys,
  ) async {
    final response = await _api.dio.post(
      '/support/tickets/$ticketId/messages',
      data: {'content': content, 'attachmentKeys': attachmentKeys},
    );
    return SupportMessage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marque un ticket comme lu. Renvoie 204 sans corps.
  Future<void> markRead(String ticketId) async {
    await _api.dio.post('/support/tickets/$ticketId/read');
  }

  /// Retourne le nombre total de messages non lus dans tous les tickets.
  Future<int> loadUnreadCount() async {
    final response = await _api.dio.get('/support/unread-count');
    final data = response.data as Map<String, dynamic>? ?? const {};
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// Upload une image en multipart et retourne la clé objet distante.
  /// La clé est ensuite passée dans `attachmentKeys` lors de la création
  /// d'un ticket ou d'un message.
  Future<String> uploadAttachment(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.dio.post('/support/attachments', data: form);
    return (response.data as Map<String, dynamic>)['key'] as String;
  }
}
