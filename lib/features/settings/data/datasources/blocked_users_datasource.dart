import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';

class BlockedUsersDatasource {
  final ApiClient _api;
  const BlockedUsersDatasource(this._api);

  Future<List<BlockedUserModel>> fetchBlockedUsers() async {
    final resp = await _api.dio.get('/users/me/blocks');
    final list = resp.data as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(BlockedUserModel.fromJson)
        .toList();
  }

  Future<void> unblockUser(String userId) async {
    await _api.dio.delete('/users/me/blocks/$userId');
  }
}
