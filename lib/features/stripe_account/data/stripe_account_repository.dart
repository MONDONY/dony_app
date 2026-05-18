import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/data/stripe_account_datasource.dart';

abstract class IStripeAccountRepository {
  Future<ConnectAccountStatus> getAccountStatus();
}

class StripeAccountRepository implements IStripeAccountRepository {
  final StripeAccountDatasource _datasource;

  StripeAccountRepository(this._datasource);

  @override
  Future<ConnectAccountStatus> getAccountStatus() async {
    try {
      return await _datasource.getAccountStatus();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
