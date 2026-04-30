import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';

class ConversationRepository {
  final ApiClient _api;
  ConversationRepository(this._api);

  Future<List<ConversationModel>> getConversations() async {
    final response = await _api.dio.get('/conversations');
    final content = (response.data['content'] as List<dynamic>? ?? []);
    return content
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    await _api.dio.post('/conversations/$id/last-message', data: {'preview': preview});
  }

  Future<void> deleteConversation(String id) async {
    await _api.dio.delete('/conversations/$id');
  }

  Future<Map<String, String>> uploadImage(
      String conversationId, List<int> bytes, String filename) async {
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
