import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:dony/features/payments/data/payout_account_label.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opérateur mobile money habituel de l'expéditeur, quand le voyageur d'un
/// trajet ne l'accepte pas.
///
/// L'état est le libellé de cet opérateur (« Orange »), ou `null` : rien à
/// dire (mémoire vide, opérateur accepté, voyageur sans mobile money, ou aucun
/// autre moyen à proposer). Le dernier opérateur payeur ne vit que sur
/// l'appareil, jamais côté serveur.
class HabitualOperatorCubit extends Cubit<String?> {
  HabitualOperatorCubit(this._memory, this._analytics) : super(null);

  final PayerPhoneMemory _memory;
  final AnalyticsService _analytics;

  /// [accepted] : réseaux acceptés par le voyageur. [fallbackAvailable] :
  /// carte ou espèces acceptées, donc un repli à proposer (sans lui l'encart
  /// n'est pas affiché et l'event n'est pas émis).
  ///
  /// Émet `mobile_money_habitual_operator_not_accepted_viewed` une fois.
  Future<void> load(
    List<MobileMoneyNetwork> accepted, {
    bool fallbackAvailable = true,
  }) async {
    if (accepted.isEmpty || !fallbackAvailable) return;
    final payer = await _memory.read();
    if (isClosed || payer == null) return;
    if (accepted.any((n) => n.code == payer.operatorCode)) return;

    final brand = MobileMoneyPayoutAccount.brandOf(payer.operatorCode);
    emit(
      brandCountryLabel(
        brand: brand,
        country: payer.country,
        fallback: brandDisplayName(brand),
        all: [for (final n in accepted) (brand: n.brand, country: n.country)],
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.mobileMoneyHabitualOperatorNotAcceptedViewed,
        properties: {'operator': payer.operatorCode},
      ),
    );
  }
}
