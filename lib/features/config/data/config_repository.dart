import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/features/config/data/config_datasource.dart';

abstract class IConfigRepository {
  Future<double> getCommissionRate();
  Future<int> getUrgencyThresholdDays();
  Future<double> getReimbursementCap();
  Future<bool> getSmsEnabled();
  Future<bool> getProEnabled();
  Future<bool> getFlightsEnabled();
  Future<Map<String, double>> getExchangeRates();

  /// Grilles en vigueur et suivante. [CommissionGridConfig.none] quand le back
  /// ne connaît pas encore la route (404).
  Future<CommissionGridConfig> getCommissionGrid();

  /// Grille figée par identifiant, `null` si inconnue ou annulée (404).
  Future<CommissionGrid?> getCommissionGridById(String id);
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
  Future<bool> getFlightsEnabled() async {
    try {
      return await _datasource.getFlightsEnabled();
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

  @override
  Future<CommissionGridConfig> getCommissionGrid() async {
    try {
      return await _datasource.getCommissionGrid();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return CommissionGridConfig.none;
      }
      throw unwrapDioError(e);
    }
  }

  @override
  Future<CommissionGrid?> getCommissionGridById(String id) async {
    try {
      return await _datasource.getCommissionGridById(id);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) return null;
      throw unwrapDioError(e);
    }
  }
}
