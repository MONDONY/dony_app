import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Point d'entrée du bouton « Changer de compte bancaire », pour l'analytics.
enum BankAccountLinkSource {
  /// Écran « Recevoir mes paiements » (`/payments/onboarding`).
  payoutsScreen('payouts_screen'), // i18n-ignore : valeur analytics
  /// Feuille d'un virement bancaire échoué (« Mon argent »).
  bankPayoutSheet('bank_payout_sheet'); // i18n-ignore : valeur analytics

  const BankAccountLinkSource(this.analyticsValue);

  final String analyticsValue;
}

/// Pourquoi le lien vers l'espace Stripe n'a pas pu être ouvert.
enum BankAccountLinkFailure {
  /// 404 `stripe-account-missing` : aucun compte Stripe relié.
  accountMissing('account_missing'), // i18n-ignore : valeur analytics
  /// 409 `stripe-onboarding-incomplete` : inscription Stripe à finir.
  onboardingIncomplete('onboarding_incomplete'), // i18n-ignore
  /// Back antérieur à la route (404 sans code, 405) : « disponible bientôt ».
  unavailable('unavailable'), // i18n-ignore : valeur analytics
  /// Le navigateur n'a pas pu s'ouvrir.
  launch('launch'), // i18n-ignore : valeur analytics
  /// Réseau, serveur… : message du catalogue d'erreurs.
  error('error'); // i18n-ignore : valeur analytics

  const BankAccountLinkFailure(this.analyticsValue);

  final String analyticsValue;
}

sealed class BankAccountLinkState {
  const BankAccountLinkState();
}

class BankAccountLinkIdle extends BankAccountLinkState {
  const BankAccountLinkIdle();
}

class BankAccountLinkLoading extends BankAccountLinkState {
  const BankAccountLinkLoading();
}

/// Lien obtenu : l'écran l'ouvre puis appelle [BankAccountLinkCubit.handled].
/// Jamais réutilisé, Stripe le fait expirer en quelques minutes.
class BankAccountLinkReady extends BankAccountLinkState {
  // Pas `const` : deux liens successifs doivent rester deux états distincts.
  BankAccountLinkReady(this.url);

  final String url;
}

class BankAccountLinkFailed extends BankAccountLinkState {
  BankAccountLinkFailed(this.failure, [this.error]);

  final BankAccountLinkFailure failure;

  /// Erreur d'origine, pour [BankAccountLinkFailure.error].
  final AppException? error;
}

/// Demande à la volée le lien de l'espace Stripe Express du voyageur
/// (`POST /payments/connect/dashboard-link`), où il change son IBAN.
class BankAccountLinkCubit extends Cubit<BankAccountLinkState> {
  BankAccountLinkCubit(this._repository, this._analytics)
    : super(const BankAccountLinkIdle());

  final IConnectOnboardingRepository _repository;
  final AnalyticsService _analytics;
  BankAccountLinkSource _source = BankAccountLinkSource.payoutsScreen;

  Future<void> request(BankAccountLinkSource source) async {
    if (state is BankAccountLinkLoading) return;
    _source = source;
    emit(const BankAccountLinkLoading());
    try {
      final url = await _repository.createDashboardLink();
      if (isClosed) return;
      emit(BankAccountLinkReady(url));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bankAccountChangeLinkOpened,
          properties: {'source': source.analyticsValue},
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final error = unwrapDioError(e);
      _fail(classify(error), error);
    }
  }

  /// L'écran a ouvert (ou tenté d'ouvrir) le lien.
  void handled() {
    if (!isClosed) emit(const BankAccountLinkIdle());
  }

  /// Le navigateur n'a pas pu s'ouvrir.
  void launchFailed() => _fail(BankAccountLinkFailure.launch, null);

  void _fail(BankAccountLinkFailure failure, AppException? error) {
    emit(BankAccountLinkFailed(failure, error));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.bankAccountChangeLinkFailed,
        properties: {
          'source': _source.analyticsValue,
          'reason': failure.analyticsValue,
          'error_code': error?.code ?? 'unknown', // i18n-ignore
        },
      ),
    );
  }

  /// Contrat de la PR jumelle yadony-back ; tout autre 404/405 vient d'un back
  /// qui ne sert pas encore la route.
  static BankAccountLinkFailure classify(AppException error) {
    switch (error.code) {
      case 'stripe-account-missing': // i18n-ignore : code serveur
        return BankAccountLinkFailure.accountMissing;
      case 'stripe-onboarding-incomplete': // i18n-ignore : code serveur
        return BankAccountLinkFailure.onboardingIncomplete;
      case '405': // i18n-ignore : code HTTP comparé
      case 'method-not-allowed': // i18n-ignore : code serveur
        return BankAccountLinkFailure.unavailable;
    }
    if (error is NotFoundException) return BankAccountLinkFailure.unavailable;
    return BankAccountLinkFailure.error;
  }
}
