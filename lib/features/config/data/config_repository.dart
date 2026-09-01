import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/config/data/config_datasource.dart';

abstract class IConfigRepository {
  Future<double> getCommissionRate();
  Future<int> getUrgencyThresholdDays();
  Future<double> getReimbursementCap();
  Future<bool> getSmsEnabled();
  Future<bool> getProEnabled();
  Future<Map<String, double>> getExchangeRates();
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

  @override
  Future<int> getUrgencyThresholdDays() async {
    try {
      return await _datasource.getUrgencyThresholdDays();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<double> getReimbursementCap() async {
    try {
      return await _datasource.getReimbursementCap();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<bool> getSmsEnabled() async {
    try {
      return await _datasource.getSmsEnabled();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<bool> getProEnabled() async {
    try {
      return await _datasource.getProEnabled();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  @override
  Future<Map<String, double>> getExchangeRates() async {
    try {
      return await _datasource.getExchangeRates();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
