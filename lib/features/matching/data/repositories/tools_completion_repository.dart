import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/tools_completion_model.dart';

/// Un seul appel pour les cinq outils : le hub tire déjà cinq requêtes au
/// chargement et son throttle anti rate-limit n'en supporterait pas cinq de
/// plus.
class ToolsCompletionRepository {
  ToolsCompletionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ToolsCompletionModel> getToolsCompletion() async {
    final response = await _apiClient.dio.get('/users/me/tools-completion');
    return ToolsCompletionModel.fromJson(response.data as Map<String, dynamic>);
  }
}
