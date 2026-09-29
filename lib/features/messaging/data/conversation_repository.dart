import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';

class ConversationRepository {
  final ApiClient _api;
  ConversationRepository(this._api);

  /// Taille de la page demandée : la liste n'est pas paginée côté écran, elle
  /// doit tenir en un appel pour un utilisateur ordinaire.
  static const pageSize = 100;

  /// Conversations actives, la plus récente en tête.
  ///
  /// Le tri est refait ici : un serveur antérieur rend les fils dans l'ordre
  /// physique de sa table, et seulement 20 par défaut. [ConversationPage.isComplete]
  /// dit si le serveur a tout rendu (`last`), condition pour que l'app puisse
  /// traiter un fil absent comme supprimé.
  Future<ConversationPage> getConversationPage() async {
    final response = await _api.dio.get(
      '/conversations',
      queryParameters: {'size': pageSize},
    );
    final data = response.data;
    final page = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    final content = page['content'] as List<dynamic>? ?? const <dynamic>[];
    final items = content
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ConversationPage(
      sortByLastMessage(items),
      isComplete: page['last'] == true,
    );
  }

  /// Dernier message en tête, fils sans date en fin, ordre d'origine conservé
  /// à égalité.
  static List<ConversationModel> sortByLastMessage(
    List<ConversationModel> conversations,
  ) {
    final indexed = conversations.indexed.toList()
      ..sort((a, b) {
        final at = a.$2.lastMessageAt;
        final bt = b.$2.lastMessageAt;
        if (at == null && bt == null) return a.$1.compareTo(b.$1);
        if (at == null) return 1;
        if (bt == null) return -1;
        final byDate = bt.compareTo(at);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, c) in indexed) c];
  }

  Future<ConversationModel> getConversation(String id) async {
    final response = await _api.dio.get('/conversations/$id');
    return ConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ConversationModel> getByBidId(String bidId) async {
    final response = await _api.dio.get('/conversations/bid/$bidId');
    return ConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateLastMessage(String id, String preview) async {
    await _api.dio.post(
      '/conversations/$id/last-message',
      data: {'preview': preview},
    );
  }

  Future<void> deleteConversation(String id) async {
    await _api.dio.delete('/conversations/$id');
  }

  Future<ConversationModel> restoreConversation(String id) async {
    final response = await _api.dio.post('/conversations/$id/restore');
    return ConversationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ConversationModel>> getArchivedConversations() async {
    final response = await _api.dio.get('/conversations/archived');
    // Le serveur renvoie une page ({content: [...]}) comme pour la liste
    // active ; un serveur antérieur renvoie la liste nue. Les deux formes
    // sont lues : un cast en Map sur une liste faisait planter l'écran des
    // conversations archivées face à un serveur en retard.
    final data = response.data;
    final list = switch (data) {
      final List<dynamic> raw => raw,
      final Map<String, dynamic> page =>
        page['content'] as List<dynamic>? ?? const <dynamic>[],
      _ => const <dynamic>[],
    };
    return list
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> archiveConversation(String id) async {
    await _api.dio.post('/conversations/$id/archive');
  }

  Future<void> unarchiveConversation(String id) async {
    await _api.dio.post('/conversations/$id/unarchive');
  }

  Future<Map<String, String>> uploadImage(
    String conversationId,
    List<int> bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await _api.dio.post(
      '/conversations/$conversationId/upload',
      data: formData,
    );
    return {
      'presignedUrl': response.data['presignedUrl'] as String,
      's3Key': response.data['s3Key'] as String,
    };
  }
}

/// Liste active telle que rendue par le serveur.
class ConversationPage {
  final List<ConversationModel> items;

  /// `true` quand aucune autre page n'existe. Tant qu'elle est incomplète, un
  /// fil absent de [items] n'est pas un fil supprimé.
  final bool isComplete;

  const ConversationPage(this.items, {this.isComplete = true});
}
