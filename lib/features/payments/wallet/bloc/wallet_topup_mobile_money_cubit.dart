import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recharge du portefeuille par mobile money (Wave / Orange Money via
/// pawaPay) : chargement des opérateurs utilisables sur le numéro payeur,
/// initiation du dépôt, puis sondage du statut jusqu'à confirmation, échec
/// ou expiration (15 min sans réponse opérateur).
///
/// Le timer de sondage vit ici, jamais côté écran : [close] l'annule, et
/// aucun `emit` n'a lieu après fermeture du cubit (garde [isClosed]).
class WalletTopupMobileMoneyCubit extends Cubit<WalletTopupMobileMoneyState> {
  WalletTopupMobileMoneyCubit(
    this._repository,
    this._analytics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const WalletTopupMobileMoneyIdle());

  static const pollInterval = Duration(seconds: 3);
  static const expiry = Duration(minutes: 15);

  final WalletRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  Timer? _pollTimer;

  /// Incrémenté à chaque [initiate] : identifie la « session » de recharge
  /// courante. Une réponse réseau (initiation ou sondage) qui résout après
  /// qu'une nouvelle recharge a démarré porte un jeton périmé — elle ne doit
  /// alors ni émettre, ni toucher au timer de la nouvelle session (sinon la
  /// nouvelle session reste bloquée en `Awaiting`, plus jamais sondée, et un
  /// event `confirmed` peut partir pour une recharge abandonnée).
  int _generation = 0;

  /// Génération pour laquelle une requête `topupStatus` est en vol, ou
  /// `null` si aucune. Empêche deux tentatives de sondage concurrentes pour
  /// la MÊME génération (tick suivant plus rapide que la réponse) sans
  /// bloquer le sondage d'une génération plus récente pendant qu'une réponse
  /// obsolète traîne encore.
  int? _inFlightGeneration;

  /// Verrou local d'[initiate], posé AVANT le premier `await` : deux taps
  /// sur « Payer » dans la même frame passent tous deux la garde d'état du
  /// bouton (l'`emit` synchrone n'a pas encore reconstruit l'UI) et
  /// ouvriraient deux dépôts côté serveur, donc deux débits.
  bool _initiating = false;

  /// Catalogue des opérateurs utilisables sur [phoneNumber], pré-sélectionne
  /// celui détecté par pawaPay pour ce numéro.
  ///
  /// Garde par génération, comme [initiate]/[_poll] : une réponse tardive
  /// (numéro modifié puis une recharge initiée avant que ce catalogue ne
  /// revienne) ne doit jamais écraser un [WalletTopupMobileMoneyAwaiting]
  /// déjà en cours de sondage.
  Future<void> loadProviders(String phoneNumber) async {
    final generation = _generation;
    emit(const WalletTopupMobileMoneyProvidersLoading());
    try {
      final catalog = await _repository.topupProviders(phoneNumber);
      if (isClosed || generation != _generation) return;
      emit(
        WalletTopupMobileMoneyProvidersReady(
          catalog: catalog,
          selectedProvider: catalog.detected,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(WalletTopupMobileMoneyError(unwrapDioError(e)));
    }
  }

  /// Change l'opérateur choisi, ou l'efface (`null`, ex : décoché dans la
  /// checklist). Sans effet hors de [WalletTopupMobileMoneyProvidersReady].
  void selectProvider(String? code) {
    final current = state;
    if (current is WalletTopupMobileMoneyProvidersReady) {
      emit(
        WalletTopupMobileMoneyProvidersReady(
          catalog: current.catalog,
          selectedProvider: code,
        ),
      );
    }
  }

  /// Initie la recharge avec l'opérateur sélectionné (`null` si
  /// [loadProviders] n'a jamais été appelé : le back retient alors celui
  /// qu'il détecte lui-même), puis démarre le sondage du statut.
  Future<void> initiate({
    required double amount,
    required String phoneNumber,
  }) async {
    if (_initiating) return;
    _initiating = true;
    try {
      await _initiate(amount: amount, phoneNumber: phoneNumber);
    } finally {
      _initiating = false;
    }
  }

  Future<void> _initiate({
    required double amount,
    required String phoneNumber,
  }) async {
    stopPolling();
    final generation = ++_generation;
    final current = state;
    final provider = current is WalletTopupMobileMoneyProvidersReady
        ? current.selectedProvider
        : null;
    emit(const WalletTopupMobileMoneyInitiating());
    try {
      final topup = await _repository.topupMobileMoney(
        amount: amount,
        phoneNumber: phoneNumber,
        provider: provider,
      );
      // Une recharge plus récente (ou une fermeture) a déjà pris le relais
      // pendant cet appel : cette réponse est périmée, on ne l'affiche pas.
      if (isClosed || generation != _generation) return;
      emit(WalletTopupMobileMoneyAwaiting(topup: topup, startedAt: _now()));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletTopupMobileMoneyInitiated,
          properties: {'provider': topup.provider, 'currency': topup.currency},
        ),
      );
      startPolling();
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(WalletTopupMobileMoneyError(unwrapDioError(e)));
    }
  }

  /// Démarre le sondage périodique du statut. Sans effet hors de
  /// [WalletTopupMobileMoneyAwaiting].
  void startPolling() {
    stopPolling();
    if (state is! WalletTopupMobileMoneyAwaiting) return;
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Abandonne la recharge en cours (« Payer avec un autre numéro » depuis
  /// l'écran d'attente) : arrête le sondage et revient à
  /// [WalletTopupMobileMoneyIdle] pour permettre de repartir de zéro.
  ///
  /// Incrémente [_generation] comme [initiate] : une réponse encore en vol
  /// (sondage ou initiation de la recharge abandonnée) ne doit ni émettre,
  /// ni faire revivre cette recharge, ni toucher au timer (déjà arrêté ici).
  /// Sans effet après [close] — aucun `emit` n'a lieu.
  void reset() {
    stopPolling();
    _generation++;
    if (isClosed) return;
    emit(const WalletTopupMobileMoneyIdle());
  }

  Future<void> _poll() async {
    if (isClosed) return;
    // Capturé avant tout `await` : identifie la session à laquelle cette
    // invocation appartient, quoi qu'il se passe pendant l'appel réseau.
    final generation = _generation;
    if (_inFlightGeneration == generation) return;
    final current = state;
    if (current is! WalletTopupMobileMoneyAwaiting) {
      stopPolling();
      return;
    }
    if (_now().difference(current.startedAt) >= expiry) {
      stopPolling();
      if (!isClosed) {
        emit(
          const WalletTopupMobileMoneyFailed(
            reason: WalletTopupFailureReason.expired,
          ),
        );
      }
      return;
    }
    _inFlightGeneration = generation;
    try {
      final status = await _repository.topupStatus(current.topup.topupId);
      // Une nouvelle recharge a démarré (ou le cubit a fermé) pendant cet
      // appel : cette réponse est périmée pour la session en cours. Ne rien
      // émettre, ne pas toucher au timer (qui appartient déjà à la nouvelle
      // session), simplement sortir.
      if (isClosed || generation != _generation) return;
      switch (status.status) {
        case 'CONFIRMED': // i18n-ignore
          stopPolling();
          emit(WalletTopupMobileMoneyConfirmed(status));
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.walletTopupMobileMoneyConfirmed,
              properties: {
                'provider': status.provider,
                'currency': status.currency,
              },
            ),
          );
        case 'FAILED': // i18n-ignore
          stopPolling();
          emit(
            WalletTopupMobileMoneyFailed(
              reason: WalletTopupFailureReason.refused,
              operatorMessage: _presentableFailure(status.failureReason),
            ),
          );
        default:
        // PENDING : rien à faire, le prochain tick relira le statut.
      }
    } catch (_) {
      // Même garde côté échec réseau : une erreur pour une session déjà
      // remplacée ne doit rien faire (sinon, en théorie sans effet ici
      // puisque la branche est déjà silencieuse, mais on reste homogène avec
      // la branche succès et robuste à une future évolution).
      if (isClosed || generation != _generation) return;
      // Sondage silencieux : une erreur réseau transitoire ne casse pas
      // l'écran, le prochain sondage réessaiera.
    } finally {
      if (_inFlightGeneration == generation) _inFlightGeneration = null;
    }
  }

  /// Motif renvoyé par l'opérateur, nettoyé, ou `null` s'il est absent ou
  /// vide : l'écran affiche alors un message générique déterminé par
  /// [WalletTopupMobileMoneyFailed.reason].
  String? _presentableFailure(String? reason) {
    final trimmed = reason?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<void> close() {
    stopPolling();
    return super.close();
  }
}
