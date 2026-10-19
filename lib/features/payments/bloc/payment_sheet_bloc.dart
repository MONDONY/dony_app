import 'dart:async';

import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_properties.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_sheet_event.dart';
part 'payment_sheet_state.dart';

/// Configuration d'une ouverture de la DonyPaymentSheet.
class PaymentSheetConfig extends Equatable {
  final String clientSecret;
  final double amountEur;

  /// Devise du PaymentIntent. [amountEur] reste le nom historique du champ
  /// pour préserver les contrats et les appels existants.
  final String currencyCode;

  /// Types du PaymentIntent renvoyés par le backend (ex. ["card","paypal"]) —
  /// le SDK flutter_stripe ne les expose pas via retrievePaymentIntent.
  final List<String> paymentMethodTypes;

  /// Parcours d'origine, envoyé en propriété `context` des événements de
  /// paiement (`bid`, `trip_negotiation`, `negotiation`, `escrow`,
  /// `wallet_topup`) : sans lui, un paiement d'offre et une recharge du
  /// solde étaient indiscernables dans PostHog.
  final String analyticsContext;

  const PaymentSheetConfig({
    required this.clientSecret,
    required this.amountEur,
    this.currencyCode = 'EUR',
    required this.paymentMethodTypes,
    this.analyticsContext = 'unknown',
  });

  /// Le clientSecret est de la forme `pi_xxx_secret_yyy`.
  String get paymentIntentId => clientSecret.split('_secret').first;

  @override
  List<Object?> get props => [
    clientSecret,
    amountEur,
    currencyCode,
    paymentMethodTypes,
    analyticsContext,
  ];

  SupportedCurrency get currency =>
      SupportedCurrency.fromCodeOrDefault(currencyCode);
}

/// Journal d'une feuille Apple Pay / Google Pay refermée en `Canceled`.
/// [suspicious] : la feuille est restée ouverte plus de
/// [PaymentSheetBloc.platformPaySuspectAfter], probablement un échec déguisé.
typedef PlatformPayCancelLogger =
    void Function(
      String message, {
      required bool suspicious,
      required Map<String, Object> data,
    });

void _appLogPlatformPayCancel(
  String message, {
  required bool suspicious,
  required Map<String, Object> data,
}) => suspicious
    ? AppLog.warn(message, data: data)
    : AppLog.info(message, data: data);

class PaymentSheetBloc extends Bloc<PaymentSheetEvent, PaymentSheetState> {
  /// Message Sentry (Logs + breadcrumb) d'une feuille Apple Pay / Google Pay
  /// refermée en `Canceled` (YADONY-FLUTTER-PROD-11).
  static const platformPayCancelledLog = 'payment.platform_pay_cancelled';

  /// Au-delà, une annulation Apple Pay / Google Pay ressemble à un échec :
  /// sans certificat de traitement côté Apple, la feuille tourne puis se
  /// referme et le SDK ne renvoie que `Canceled`.
  static const platformPaySuspectAfter = Duration(seconds: 8);

  final PaymentGateway _gateway;
  final PlatformPayCancelLogger _platformPayCancelLog;
  final DateTime Function() _now;
  final PaymentRepository _repository;
  final ErrorReportingService? _errorReporter;
  final AnalyticsService? _analytics;
  final PaymentSheetConfig config;

  PaymentSheetBloc({
    required PaymentGateway gateway,
    required PaymentRepository repository,
    required this.config,
    ErrorReportingService? errorReporter,
    AnalyticsService? analytics,
    PlatformPayCancelLogger platformPayCancelLog = _appLogPlatformPayCancel,
    DateTime Function() now = DateTime.now,
  }) : _gateway = gateway,
       _platformPayCancelLog = platformPayCancelLog,
       _now = now,
       _repository = repository,
       _errorReporter = errorReporter,
       _analytics = analytics,
       super(const PaymentSheetLoading()) {
    on<PaymentSheetStarted>(_onStarted);
    on<PaymentSheetWalletPressed>(_onWalletPressed);
    on<PaymentSheetPayPalPressed>(_onPayPalPressed);
    on<PaymentSheetCardPressed>(_onCardPressed);
  }

  Future<void> _onStarted(
    PaymentSheetStarted event,
    Emitter<PaymentSheetState> emit,
  ) async {
    // Aucun bouton mort : chaque moyen n'apparaît que s'il est disponible.
    // Les échecs de résolution ne bloquent jamais la sheet (dégradation propre).
    bool walletAvailable = false;
    try {
      walletAvailable = await _gateway.isPlatformPaySupported();
    } catch (_) {}

    final paypalAvailable = config.paymentMethodTypes.contains('paypal');
    emit(
      PaymentSheetResolved(
        walletAvailable: walletAvailable,
        paypalAvailable: paypalAvailable,
      ),
    );
    _log(AnalyticsEvents.paymentSheetOpened, {
      'wallet_available': walletAvailable,
      'paypal_available': paypalAvailable,
    });
  }

  /// Propriétés communes à tous les événements de paiement, sans montant
  /// exact (voir [analyticsAmountBracket]).
  Map<String, Object> get _baseProperties => {
    'context': config.analyticsContext,
    'currency': config.currencyCode,
    'amount_bracket': analyticsAmountBracket(config.amountEur),
  };

  void _log(
    String event, [
    Map<String, Object> extra = const {},
    PaymentMethodKind? method,
  ]) {
    final analytics = _analytics;
    if (analytics == null) return;
    unawaited(
      analytics.logEvent(
        event,
        properties: {
          ..._baseProperties,
          if (method != null) 'method': _methodName(method),
          ...extra,
        },
      ),
    );
  }

  /// Nom PostHog d'un moyen : `wallet` désigne ici Apple Pay / Google Pay,
  /// à ne pas confondre avec le solde Yadony (`wallet_balance`).
  static String _methodName(PaymentMethodKind method) => switch (method) {
    PaymentMethodKind.wallet => AnalyticsPaymentMethod.platformPay,
    PaymentMethodKind.paypal => AnalyticsPaymentMethod.paypal,
    PaymentMethodKind.card => AnalyticsPaymentMethod.card,
  };

  /// Nom PostHog d'une raison d'échec (`authentication_failed`…).
  static String _reasonName(PaymentSheetFailureReason reason) =>
      switch (reason) {
        PaymentSheetFailureReason.cardUnavailable => 'card_unavailable',
        PaymentSheetFailureReason.declined => 'declined',
        PaymentSheetFailureReason.authenticationFailed =>
          'authentication_failed',
        PaymentSheetFailureReason.sheetUnavailable => 'sheet_unavailable',
        PaymentSheetFailureReason.methodUnavailable => 'method_unavailable',
        PaymentSheetFailureReason.generic => 'generic',
      };

  /// Émet l'échec à l'écran et le trace, puis ré-arme le bouton.
  void _fail(
    Emitter<PaymentSheetState> emit,
    PaymentSheetFailure failure,
    PaymentSheetResolved ready,
    PaymentMethodKind method,
  ) {
    emit(failure);
    _log(AnalyticsEvents.paymentFailed, {
      'reason': _reasonName(failure.reason),
    }, method);
    emit(ready); // failure transitoire (snackbar) puis bouton ré-armé
  }

  Future<void> _onWalletPressed(
    PaymentSheetWalletPressed event,
    Emitter<PaymentSheetState> emit,
  ) => _confirm(
    emit,
    PaymentMethodKind.wallet,
    () => _gateway.confirmPlatformPay(
      clientSecret: config.clientSecret,
      amountEur: config.amountEur,
      currencyCode: config.currencyCode,
    ),
  );

  Future<void> _onPayPalPressed(
    PaymentSheetPayPalPressed event,
    Emitter<PaymentSheetState> emit,
  ) => _confirm(
    emit,
    PaymentMethodKind.paypal,
    () => _gateway.confirmPayPal(config.clientSecret),
  );

  /// Clé éphémère mémoïsée pour la durée de vie de la sheet : un tap
  /// Carte annulé puis retenté ne refait pas l'aller-retour réseau
  /// (la clé Stripe reste valide bien plus longtemps que la sheet).
  Future<EphemeralKeyModel>? _ephemeralKeyFuture;

  /// Récupère la clé éphémère du customer puis délègue toute la saisie/
  /// sélection de carte à la PaymentSheet native Stripe. Elle confirme
  /// elle-même le PaymentIntent une fois l'utilisateur validé.
  ///
  /// Les erreurs Stripe (carte refusée…) remontent déjà localisées via le
  /// gateway, comme pour wallet/PayPal ; seul l'échec de la clé éphémère
  /// est remappé sur [_EphemeralKeyUnavailableException], que [_confirm]
  /// distingue des échecs Stripe pour émettre
  /// [PaymentSheetFailureReason.cardUnavailable].
  Future<void> _onCardPressed(
    PaymentSheetCardPressed event,
    Emitter<PaymentSheetState> emit,
  ) => _confirm(emit, PaymentMethodKind.card, () async {
    final EphemeralKeyModel ephemeralKey;
    try {
      ephemeralKey = await (_ephemeralKeyFuture ??= _repository
          .createEphemeralKey());
    } catch (error, stackTrace) {
      unawaited(
        _errorReporter?.report(
          error,
          operation: 'payment.ephemeral_key',
          stackTrace: stackTrace,
          context: {'feature': 'payments', 'method': 'card'},
        ),
      );
      _ephemeralKeyFuture = null; // ne pas mémoïser un échec
      throw const _EphemeralKeyUnavailableException();
    }
    try {
      await _gateway.initPaymentSheet(
        clientSecret: config.clientSecret,
        customerId: ephemeralKey.customerId,
        customerEphemeralKeySecret: ephemeralKey.ephemeralKeySecret,
      );
    } on PaymentConfirmationException catch (e) {
      // Rien n'a encore été montré ni saisi : ce n'est pas un refus de la
      // carte, la feuille n'a pas pu s'ouvrir (FLUTTER-CJ).
      throw _SheetOpenFailedException(e);
    }
    await _gateway.presentPaymentSheet();
  });

  Future<void> _confirm(
    Emitter<PaymentSheetState> emit,
    PaymentMethodKind method,
    Future<void> Function() action,
  ) async {
    // Anti double-tap : le transformer par défaut de bloc traite les
    // événements en concurrence — sans ce garde, deux taps rapides lancent
    // deux chaînes de confirmation parallèles (observé en prod : 5 POST
    // ephemeral-key). L'émission de Processing est synchrone avant le
    // premier await, donc le second handler voit toujours ce garde.
    if (state is PaymentSheetProcessing) return;
    final ready = _currentReady;
    if (ready == null) return;
    emit(PaymentSheetProcessing(ready: ready, method: method));
    _log(AnalyticsEvents.paymentInitiated, const {}, method);
    final startedAt = _now();
    try {
      await action();
      emit(PaymentSheetSuccess(method: method));
      _log(AnalyticsEvents.paymentSucceeded, const {}, method);
    } on PaymentCancelledException {
      emit(ready); // annulation silencieuse — la sheet reste prête
      _log(AnalyticsEvents.paymentCancelled, const {}, method);
      if (method == PaymentMethodKind.wallet) {
        _logPlatformPayCancelled(_now().difference(startedAt));
      }
    } on _EphemeralKeyUnavailableException {
      _fail(
        emit,
        PaymentSheetFailure(
          reason: PaymentSheetFailureReason.cardUnavailable,
          ready: ready,
        ),
        ready,
        method,
      );
    } on _SheetOpenFailedException catch (e, stackTrace) {
      _reportStripeFailure(
        e.cause,
        stackTrace,
        method,
        operation: 'payment.stripe_init',
      );
      _fail(emit, _failureFor(e.cause, ready, opening: true), ready, method);
    } on PaymentConfirmationException catch (e, stackTrace) {
      _reportStripeFailure(e, stackTrace, method);
      _fail(emit, _failureFor(e, ready), ready, method);
    } catch (error, stackTrace) {
      // Dernier filet : une erreur non mappée par le gateway n'a pas de
      // message montrable (toString technique), on reste générique.
      unawaited(
        _errorReporter?.report(
          error,
          operation: 'payment.confirm',
          stackTrace: stackTrace,
          context: {'feature': 'payments', 'method': method.name},
        ),
      );
      _fail(
        emit,
        PaymentSheetFailure(
          reason: PaymentSheetFailureReason.generic,
          ready: ready,
        ),
        ready,
        method,
      );
    }
  }

  /// Classe un échec Stripe pour l'utilisateur : refus de la banque
  /// ([PaymentSheetFailureReason.declined]) ou 3-D Secure non abouti
  /// ([PaymentSheetFailureReason.authenticationFailed]), sans texte du SDK
  /// (FLUTTER-G5) ; une erreur locale du
  /// SDK (sans type Stripe, ex. « FragmentManager has been destroyed ») ou
  /// survenue à l'ouverture devient [PaymentSheetFailureReason.sheetUnavailable],
  /// le reste [PaymentSheetFailureReason.generic]. Une exception construite
  /// par l'app (hors SDK) garde son message et la raison `declined`.
  static PaymentSheetFailure _failureFor(
    PaymentConfirmationException e,
    PaymentSheetResolved ready, {
    bool opening = false,
  }) {
    final kind = e.isFromStripe
        ? classifyStripeFailure(e, opening: opening)
        : StripeFailureKind.cardDeclined;
    return switch (kind) {
      StripeFailureKind.cardDeclined => PaymentSheetFailure(
        reason: PaymentSheetFailureReason.declined,
        providerMessage: e.message,
        ready: ready,
      ),
      StripeFailureKind.authenticationFailed => PaymentSheetFailure(
        reason: PaymentSheetFailureReason.authenticationFailed,
        ready: ready,
      ),
      StripeFailureKind.sheetUnavailable => PaymentSheetFailure(
        reason: PaymentSheetFailureReason.sheetUnavailable,
        ready: ready,
      ),
      StripeFailureKind.methodUnavailable => PaymentSheetFailure(
        reason: PaymentSheetFailureReason.methodUnavailable,
        ready: ready,
      ),
      StripeFailureKind.generic => PaymentSheetFailure(
        reason: PaymentSheetFailureReason.generic,
        ready: ready,
      ),
    };
  }

  /// Le SDK ne distingue pas une feuille Apple Pay / Google Pay fermée par
  /// l'utilisateur d'une feuille en échec (certificat Apple absent,
  /// YADONY-FLUTTER-PROD-11) : les deux rendent `Canceled`. L'UX ne change
  /// pas, mais la durée part à Sentry, en warning au-delà de
  /// [platformPaySuspectAfter].
  void _logPlatformPayCancelled(Duration elapsed) {
    _platformPayCancelLog(
      platformPayCancelledLog,
      suspicious: elapsed > platformPaySuspectAfter,
      data: {
        'duration_ms': elapsed.inMilliseconds,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'apple_pay'
            : 'google_pay',
        'context': config.analyticsContext,
      },
    );
  }

  /// Remonte à Sentry un échec Stripe (hors annulation, déjà mappée en
  /// [PaymentCancelledException]) avec les codes du SDK : l'utilisateur ne
  /// voit qu'un message générique, et sans cette trace un refus de carte
  /// restait indiagnosticable (FLUTTER-7S). Un refus de carte ou un échec
  /// 3-D Secure est attendu et filtré par `ErrorReportingService` via
  /// [PaymentConfirmationException.reportSeverity] (FLUTTER-G5).
  void _reportStripeFailure(
    PaymentConfirmationException e,
    StackTrace stackTrace,
    PaymentMethodKind method, {
    String operation = 'payment.stripe_confirm',
  }) {
    if (!e.isFromStripe) return;
    unawaited(
      _errorReporter?.report(
        e,
        operation: operation,
        stackTrace: stackTrace,
        context: {
          'feature': 'payments',
          'method': method.name,
          ...stripeFailureContext(e),
        },
      ),
    );
  }

  PaymentSheetResolved? get _currentReady => switch (state) {
    final PaymentSheetResolved s => s,
    PaymentSheetProcessing(:final ready) => ready,
    PaymentSheetFailure(:final ready) => ready,
    _ => null,
  };
}

/// Marqueur interne : la clé éphémère du customer n'a pas pu être récupérée.
/// Distingue ce cas, dans [PaymentSheetBloc._confirm], d'un échec Stripe
/// ([PaymentConfirmationException]) pour émettre
/// [PaymentSheetFailureReason.cardUnavailable] plutôt que `declined`.
class _EphemeralKeyUnavailableException implements Exception {
  const _EphemeralKeyUnavailableException();
}

/// Marqueur interne : `initPaymentSheet` a échoué, avant tout affichage.
/// Distingue, dans [PaymentSheetBloc._confirm], une feuille qui n'a pas pu
/// s'ouvrir d'un refus de paiement (FLUTTER-CJ).
class _SheetOpenFailedException implements Exception {
  const _SheetOpenFailedException(this.cause);

  final PaymentConfirmationException cause;
}
