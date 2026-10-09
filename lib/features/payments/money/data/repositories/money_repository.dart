import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/money/data/datasources/money_remote_datasource.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';

/// Levée quand le back ne sert pas encore `GET /payments/me/overview`
/// (déployé avant yadony-back #481 : 404, ou 405 selon le routage).
class MoneyOverviewUnavailable implements Exception {
  const MoneyOverviewUnavailable();
}

class MoneyRepository {
  MoneyRepository(this._datasource);

  final MoneyRemoteDatasource _datasource;

  Future<MoneyOverviewModel> getOverview() async {
    try {
      return await _datasource.getOverview();
    } catch (e) {
      final error = unwrapDioError(e);
      if (isUnavailable(error)) throw const MoneyOverviewUnavailable();
      throw error;
    }
  }

  /// Ancien back : la route n'existe pas (404) ou ne répond pas au GET (405).
  static bool isUnavailable(AppException error) =>
      error is NotFoundException ||
      error.code == '405' || // i18n-ignore : code HTTP comparé
      error.code == 'method-not-allowed'; // i18n-ignore : code serveur
}
