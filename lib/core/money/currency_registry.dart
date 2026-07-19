import 'package:dio/dio.dart';

import 'package:dony/core/money/currency_fallback.dart';
import 'package:dony/core/money/currency_info.dart';

/// Registre des devises, synchronisé au démarrage (même pattern que
/// `dony_pricing.dart` : valeur backend si joignable, repli constant sinon).
/// Donnée de référence en lecture seule — pas de BLoC (spec §6.1).
///
/// La synchro réseau (`GET /config/currencies`) est volontairement isolée ici
/// (plutôt que suivre exactement le découpage datasource/repository de
/// `dony_pricing.dart`) : ce singleton reste autonome dans `core/money/` et
/// entièrement testable sans dépendre de `features/config/`. Le câblage au
/// démarrage de l'app (quel `Dio` lui est passé, à quel moment) est laissé à
/// la tâche suivante — ce fichier ne fait qu'exposer [sync].
class CurrencyRegistry {
  CurrencyRegistry._();

  static final CurrencyRegistry instance = CurrencyRegistry._();

  Map<String, CurrencyInfo> _byCode = {
    for (final c in kFallbackCurrencies) c.code: c,
  };

  /// Devise par code ISO, `null` si inconnue du registre (jamais d'invention
  /// d'une devise — voir [formatDual] dans `money_formatter.dart`).
  CurrencyInfo? operator [](String code) => _byCode[code];

  /// Synchronise le registre depuis `GET /config/currencies`. Ne lève jamais
  /// — en cas d'échec réseau ou de réponse vide, le registre courant (backend
  /// précédent ou repli [kFallbackCurrencies]) est conservé tel quel.
  Future<void> sync(Dio dio) async {
    try {
      final res = await dio.get<List<dynamic>>('/config/currencies');
      final list = (res.data ?? <dynamic>[])
          .map((e) => CurrencyInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        _byCode = {for (final c in list) c.code: c};
      }
    } catch (_) {
      // Offline / backend down → on garde le registre courant (indicatif
      // uniquement, jamais utilisé pour un calcul transactionnel).
    }
  }

  /// Réinitialise le registre sur le repli constant. Réservé aux tests.
  void resetToFallbackForTest() {
    _byCode = {for (final c in kFallbackCurrencies) c.code: c};
  }
}
