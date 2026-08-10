import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_datasource.dart';

export 'package:dony/core/models/connect_account_status.dart';

abstract class IConnectOnboardingRepository {
  Future<ConnectAccountStatus> getAccountStatus();
  Future<ConnectAccountStatus> createAccount();
  Future<String> createOnboardingLink();
}

class ConnectOnboardingRepository implements IConnectOnboardingRepository {
  final ConnectOnboardingDatasource _datasource;

  ConnectOnboardingRepository(this._datasource);

  @override
  Future<ConnectAccountStatus> getAccountStatus() async {
    try {
      return await _datasource.getAccountStatus();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<ConnectAccountStatus> createAccount() async {
    try {
      return await _datasource.createAccount();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<String> createOnboardingLink() async {
    try {
      return await _datasource.createOnboardingLink();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
