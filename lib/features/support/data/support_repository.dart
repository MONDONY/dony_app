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
    required String message,
  }) async {
    final response = await _api.dio.post(
      '/support/tickets',
      data: {'category': category, 'subject': subject, 'message': message},
    );
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SupportTicket> loadTicket(String ticketId) async {
    final response = await _api.dio.get('/support/tickets/$ticketId');
    return SupportTicket.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SupportMessage> sendMessage(String ticketId, String content) async {
    final response = await _api.dio.post(
      '/support/tickets/$ticketId/messages',
      data: {'content': content},
    );
    return SupportMessage.fromJson(response.data as Map<String, dynamic>);
  }
}
