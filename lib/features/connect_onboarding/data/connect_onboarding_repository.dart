import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_datasource.dart';

class ConnectAccountStatus {
  final String? accountId;
  final String status;
  final String? country;
  final bool isProAccount;

  const ConnectAccountStatus({
    this.accountId,
    required this.status,
    this.country,
    this.isProAccount = false,
  });

  factory ConnectAccountStatus.fromJson(Map<String, dynamic> json) {
    return ConnectAccountStatus(
      accountId: json['accountId'] as String?,
      status: json['status'] as String? ?? 'NOT_CREATED',
      country: json['country'] as String?,
      isProAccount: json['isProAccount'] as bool? ?? false,
    );
  }

  bool get isComplete => status == 'ONBOARDING_COMPLETE';
  bool get needsOnboarding =>
      status == 'NOT_CREATED' || status == 'PENDING_ONBOARDING';
}

abstract class IConnectOnboardingRepository {
  Future<ConnectAccountStatus> getAccountStatus();
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
  Future<String> createOnboardingLink() async {
    try {
      return await _datasource.createOnboardingLink();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
