import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/storage/hive_service.dart';

/// Devise active mise en cache après confirmation par le backend.
///
/// Une valeur absente ou inconnue ne doit pas être remplacée par une devise
/// arbitraire : le backend conserve alors seul la source de vérité.
abstract final class ActiveCurrency {
  static SupportedCurrency? fromHive(HiveService? hiveService) {
    final storedCode = hiveService?.userPrefs.get(
      HiveService.kCurrencyCode,
      defaultValue: null,
    );
    return SupportedCurrency.fromCode(storedCode is String ? storedCode : null);
  }
}
