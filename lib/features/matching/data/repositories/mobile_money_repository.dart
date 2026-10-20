import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/datasources/mobile_money_remote_datasource.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';

class MobileMoneyRepository {
  const MobileMoneyRepository(this._datasource);
  final MobileMoneyRemoteDatasource _datasource;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) =>
      _datasource.getStatus(scope);

  /// Opérateurs acceptés par le voyageur, ou `null` quand le back ne connaît
  /// pas encore la route (404 d'un ancien back) : l'appelant se replie alors
  /// sur le comportement d'avant, sans restriction.
  Future<MobileMoneyAcceptedOperators?> acceptedOperators(
    MobileMoneyScope scope,
  ) async {
    try {
      return await _datasource.acceptedOperators(scope);
    } catch (e) {
      if (unwrapDioError(e) is NotFoundException) return null;
      rethrow;
    }
  }

  Future<MobileMoneyPaymentStatus> initiate(
    MobileMoneyScope scope, {
    String? phoneNumber,
    String? provider,
  }) =>
      _datasource.initiate(scope, phoneNumber: phoneNumber, provider: provider);
}
