import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/config/data/config_datasource.dart';

abstract class IConfigRepository {
  Future<double> getCommissionRate();
}

class ConfigRepository implements IConfigRepository {
  final ConfigDatasource _datasource;

  ConfigRepository(this._datasource);

  @override
  Future<double> getCommissionRate() async {
    try {
      return await _datasource.getCommissionRate();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
