import 'package:dony/features/settings/data/datasources/blocked_users_datasource.dart';
import 'package:dony/features/settings/data/models/blocked_user_model.dart';

class BlockedUsersRepository {
  final BlockedUsersDatasource _datasource;
  const BlockedUsersRepository(this._datasource);

  Future<List<BlockedUserModel>> fetchBlockedUsers() =>
      _datasource.fetchBlockedUsers();

  Future<void> blockUser(String blockedUserId) =>
      _datasource.blockUser(blockedUserId);

  Future<void> unblockUser(String userId) => _datasource.unblockUser(userId);
}
