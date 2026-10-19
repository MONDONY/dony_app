import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_state.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_status_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recharge du portefeuille par mobile money (pawaPay) : chargement des
/// opérateurs utilisables sur le numéro payeur (ancien parcours), initiation
/// du dépôt ou reprise d'une recharge en cours ([resumePending]), puis
/// sondage du statut jusqu'à confirmation ou échec. Passé l'échéance du
/// serveur (`expiresAt`, 15 min par défaut), l'état devient
/// [WalletTopupMobileMoneyOverdue] et le sondage continue : l'opérateur
/// peut encore valider, seul le back déclare un échec.
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

  final WalletRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  Timer? _pollTimer;

  /// Montant de la recharge en cours, pour la tranche envoyée à l'issue.
  double? _amount;

  /// Recharge en cours reprise par [resumePending] plutôt qu'initiée ici :
  /// la confirmation le signale ([WalletTopupMobileMoneyConfirmed.resumed]).
  bool _resumed = false;

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

  /// Opérateur choisi dans le bloc « compte qui paie » de l'écran Recharger
  /// ([useOperator]). Ce parcours ne charge pas de catalogue par
  /// [loadProviders] : sans lui, [initiate] partirait sans opérateur.
  String? _chosenProvider;

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

  /// Retient l'opérateur choisi sur l'écran Recharger (pays, opérateur,
  /// numéro reconnu), envoyé au back par [initiate]. Un catalogue chargé par
  /// [loadProviders] (ancien parcours) garde la priorité.
  void useOperator(String? code) => _chosenProvider = code;

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

  /// Initie la recharge avec l'opérateur sélectionné dans le catalogue, à
  /// défaut celui retenu par [useOperator] (`null` si aucun des deux : le
  /// back retient alors celui qu'il détecte lui-même), puis démarre le
  /// sondage du statut.
  ///
  /// [custom] : montant saisi via « Autre montant » plutôt que choisi parmi
  /// les montants proposés (FLUTTER-CF). Seul ce drapeau part dans
  /// l'analytics, jamais le montant.
  Future<void> initiate({
    required double amount,
    required String phoneNumber,
    bool custom = false,
  }) async {
    if (_initiating) return;
    _initiating = true;
    try {
      await _initiate(amount: amount, phoneNumber: phoneNumber, custom: custom);
    } finally {
      _initiating = false;
    }
  }

  Future<void> _initiate({
    required double amount,
    required String phoneNumber,
    required bool custom,
  }) async {
    stopPolling();
    final generation = ++_generation;
    final current = state;
    final provider = current is WalletTopupMobileMoneyProvidersReady
        ? current.selectedProvider
        : _chosenProvider;
    emit(const WalletTopupMobileMoneyInitiating());
    _amount = amount;
    _resumed = false;
    try {
      final topup = await _repository.topupMobileMoney(
        amount: amount,
        phoneNumber: phoneNumber,
        provider: provider,
      );
      // Une recharge plus récente (ou une fermeture) a déjà pris le relais
      // pendant cet appel : cette réponse est périmée, on ne l'affiche pas.
      if (isClosed || generation != _generation) return;
      emit(
        WalletTopupMobileMoneyAwaiting(
          topup: topup,
          startedAt: _now(),
          amount: amount,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletTopupMobileMoneyInitiated,
          properties: {
            'provider': topup.provider,
            'currency': topup.currency,
            'custom': custom,
          },
        ),
      );
      startPolling();
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final error = unwrapDioError(e);
      // Une recharge est déjà ouverte côté serveur (ex. attente quittée par
      // le ✕ puis nouvelle recharge avant l'échéance) : on reprend celle-ci,
      // avec son avertissement, plutôt que d'afficher le 409.
      if (error.code == _alreadyPendingCode && await _resume()) return;
      if (isClosed || generation != _generation) return;
      _logOutcome(
        AnalyticsEvents.walletTopupFailed,
        reason: 'initiate_failed',
        errorCode: error.code ?? 'unknown',
      );
      emit(WalletTopupMobileMoneyError(error));
    }
  }

  /// Issue d'une recharge mobile money : `wallet_topup_completed` ou
  /// `wallet_topup_failed`, doublés de `payment_succeeded` /
  /// `payment_failed` (`context: wallet_topup`) pour lire tous les moyens
  /// dans un même tableau. Sans eux, un refus de l'opérateur ou une
  /// expiration n'atteignait jamais PostHog.
  void _logOutcome(
    String topupEvent, {
    String? currency,
    String? provider,
    String? reason,
    String? errorCode,
  }) {
    final amount = _amount;
    final properties = <String, Object>{
      'method': AnalyticsPaymentMethod.mobileMoney,
      'currency': ?currency,
      if (amount != null) 'amount_bracket': analyticsAmountBracket(amount),
      'provider': ?provider,
      'reason': ?reason,
      'error_code': ?errorCode,
    };
    unawaited(_analytics.logEvent(topupEvent, properties: properties));
    unawaited(
      _analytics.logEvent(
        topupEvent == AnalyticsEvents.walletTopupCompleted
            ? AnalyticsEvents.paymentSucceeded
            : AnalyticsEvents.paymentFailed,
        properties: {
          ...properties,
          'context': AnalyticsPaymentContext.walletTopup,
        },
      ),
    );
  }

  /// Code du 409 du back quand une recharge est déjà ouverte.
  static const _alreadyPendingCode = 'topup-already-pending'; // i18n-ignore

  /// Reprend la recharge mobile money encore ouverte côté serveur
  /// (`GET /wallet/topup/pending`), à l'ouverture de l'écran Recharger :
  /// passe en [WalletTopupMobileMoneyAwaiting] et sonde son statut. Renvoie
  /// `true` si une recharge a été reprise, `false` sinon (aucune recharge,
  /// back ancien, erreur réseau, une recharge lancée entre-temps, ou
  /// [shouldResume] qui refuse au retour de la réponse : l'écran a changé).
  Future<bool> resumePending({bool Function()? shouldResume}) async {
    if (_initiating) return false;
    return _resume(
      shouldResume: () => !_initiating && (shouldResume?.call() ?? true),
    );
  }

  Future<bool> _resume({bool Function()? shouldResume}) async {
    final generation = _generation;
    final WalletTopupStatusModel? pending;
    try {
      pending = await _repository.pendingTopup();
    } catch (_) {
      // Reprise de confort : sans elle, l'écran Recharger reste utilisable.
      return false;
    }
    if (isClosed || generation != _generation) return false;
    if (!(shouldResume?.call() ?? true)) return false;
    // Statut technique du back, jamais affiché.
    const pendingStatus = 'PENDING'; // i18n-ignore
    if (pending == null || pending.status != pendingStatus) return false;
    stopPolling();
    _generation++;
    _amount = pending.amount;
    _resumed = true;
    emit(
      WalletTopupMobileMoneyAwaiting(
        topup: WalletTopupModel(
          topupId: pending.topupId,
          currency: pending.currency,
          provider: pending.provider,
          providerLabel: pending.providerLabel,
          msisdnMasked: pending.msisdnMasked,
          authorizationUrl: pending.authorizationUrl,
          expiresAt: pending.expiresAt,
          validationHint: pending.validationHint,
        ),
        startedAt: _now(),
        amount: pending.amount,
        resumed: true,
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.walletTopupResumed,
        properties: {
          'provider': pending.provider,
          'currency': pending.currency,
        },
      ),
    );
    startPolling();
    return true;
  }

  /// L'utilisateur quitte l'écran d'attente (✕, retour système) sans
  /// abandonner la recharge : le sondage s'arrête, l'état reste celui de
  /// l'attente, le serveur continue de suivre le dépôt et notifie l'issue.
  /// Ni [reset] ni `wallet_topup_cancelled`. Sans effet si rien n'est suivi
  /// (déjà détaché, recharge terminée).
  ///
  /// Incrémente [_generation] : une réponse de sondage encore en vol au
  /// moment de la sortie n'émet plus rien (l'utilisateur a quitté le
  /// parcours, la notification du serveur annoncera l'issue).
  void detach() {
    if (_pollTimer == null) return;
    stopPolling();
    _generation++;
    final current = state;
    final remaining = current is WalletTopupMobileMoneyAwaiting
        ? current.expiresAt.difference(_now())
        : Duration.zero;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.walletTopupAwaitingClosed,
        properties: {
          'remaining_s': remaining.isNegative ? 0 : remaining.inSeconds,
        },
      ),
    );
  }

  /// Démarre le sondage périodique du statut. Sans effet hors de
  /// [WalletTopupMobileMoneyAwaiting] et [WalletTopupMobileMoneyOverdue].
  void startPolling() {
    stopPolling();
    if (state is! WalletTopupMobileMoneyAwaiting &&
        state is! WalletTopupMobileMoneyOverdue) {
      return;
    }
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Abandonne la recharge (« Payer avec un autre numéro », proposé une fois
  /// l'échéance passée ou après un échec) : arrête le sondage et revient à
  /// [WalletTopupMobileMoneyIdle] pour permettre de repartir de zéro.
  ///
  /// Incrémente [_generation] comme [initiate] : une réponse encore en vol
  /// (sondage ou initiation de la recharge abandonnée) ne doit ni émettre,
  /// ni faire revivre cette recharge, ni toucher au timer (déjà arrêté ici).
  /// Sans effet après [close] — aucun `emit` n'a lieu.
  void reset() {
    stopPolling();
    _generation++;
    // Abandon d'une recharge encore ouverte (« autre numéro ») : on la
    // compte pour ne pas la confondre avec une attente sans fin.
    if (state is WalletTopupMobileMoneyAwaiting ||
        state is WalletTopupMobileMoneyOverdue) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.walletTopupCancelled,
          properties: {'method': AnalyticsPaymentMethod.mobileMoney},
        ),
      );
    }
    if (isClosed) return;
    emit(const WalletTopupMobileMoneyIdle());
  }

  Future<void> _poll() async {
    if (isClosed) return;
    // Capturé avant tout `await` : identifie la session à laquelle cette
    // invocation appartient, quoi qu'il se passe pendant l'appel réseau.
    final generation = _generation;
    final current = state;
    final WalletTopupModel topup;
    switch (current) {
      case WalletTopupMobileMoneyAwaiting():
        topup = current.topup;
        // Échéance passée sans statut final : « pas encore validé », et le
        // sondage continue (un COMPLETED tardif crédite quand même).
        if (!_now().isBefore(current.expiresAt)) {
          emit(WalletTopupMobileMoneyOverdue(topup: topup));
        }
      case WalletTopupMobileMoneyOverdue():
        topup = current.topup;
      default:
        stopPolling();
        return;
    }
    // Après le passage en Overdue : une requête qui traîne (réseau lent)
    // ne doit pas retarder « pas encore validé ».
    if (_inFlightGeneration == generation) return;
    _inFlightGeneration = generation;
    try {
      final status = await _repository.topupStatus(topup.topupId);
      // Une nouvelle recharge a démarré (ou le cubit a fermé) pendant cet
      // appel : cette réponse est périmée pour la session en cours. Ne rien
      // émettre, ne pas toucher au timer (qui appartient déjà à la nouvelle
      // session), simplement sortir.
      if (isClosed || generation != _generation) return;
      switch (status.status) {
        case 'CONFIRMED': // i18n-ignore
          stopPolling();
          emit(WalletTopupMobileMoneyConfirmed(status, resumed: _resumed));
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.walletTopupMobileMoneyConfirmed,
              properties: {
                'provider': status.provider,
                'currency': status.currency,
              },
            ),
          );
          _logOutcome(
            AnalyticsEvents.walletTopupCompleted,
            currency: status.currency,
            provider: status.provider,
          );
        case 'FAILED': // i18n-ignore
          stopPolling();
          emit(
            WalletTopupMobileMoneyFailed(
              failureCode: status.failureCode,
              failureReason: _presentableFailure(status.failureReason),
            ),
          );
          // Le code Yadony (liste fermée) part, jamais le texte du motif.
          _logOutcome(
            AnalyticsEvents.walletTopupFailed,
            currency: status.currency,
            provider: status.provider,
            reason: 'declined',
            errorCode: status.failureCode,
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

  /// Motif renvoyé par le back, nettoyé, ou `null` s'il est absent ou vide :
  /// l'écran se rabat alors sur le texte du code d'échec, ou un message
  /// générique.
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
