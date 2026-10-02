import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/calls/data/models/call_token.dart';
import 'package:dony/features/calls/data/models/started_call.dart';

/// Appels audio : le back délivre le jeton Stream et crée seul les appels,
/// après avoir vérifié que la commande les autorise.
class CallsDatasource {
  CallsDatasource(this._apiClient);

  final ApiClient _apiClient;

  Future<CallToken> fetchToken() async {
    final response = await _apiClient.dio.get<dynamic>('/calls/token');
    return CallToken.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StartedCall> startCall(String conversationId) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/conversations/$conversationId/calls',
    );
    return StartedCall.fromJson(response.data as Map<String, dynamic>);
  }
}
