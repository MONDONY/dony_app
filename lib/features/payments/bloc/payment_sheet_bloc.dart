import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'payment_sheet_event.dart';
part 'payment_sheet_state.dart';

/// Configuration d'une ouverture de la DonyPaymentSheet.
class PaymentSheetConfig extends Equatable {
  final String clientSecret;
  final double amountEur;

  /// Types du PaymentIntent renvoyés par le backend (ex. ["card","paypal"]) —
  /// le SDK flutter_stripe ne les expose pas via retrievePaymentIntent.
  final List<String> paymentMethodTypes;

  const PaymentSheetConfig({
    required this.clientSecret,
    required this.amountEur,
    required this.paymentMethodTypes,
  });

  /// Le clientSecret est de la forme `pi_xxx_secret_yyy`.
  String get paymentIntentId => clientSecret.split('_secret').first;

  @override
  List<Object?> get props => [clientSecret, amountEur, paymentMethodTypes];
}

class PaymentSheetBloc extends Bloc<PaymentSheetEvent, PaymentSheetState> {
  final PaymentGateway _gateway;
  final PaymentRepository _repository;
  final PaymentSheetConfig config;

  PaymentSheetBloc({
    required PaymentGateway gateway,
    required PaymentRepository repository,
    required this.config,
  })  : _gateway = gateway,
        _repository = repository,
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

    emit(PaymentSheetResolved(
      walletAvailable: walletAvailable,
      paypalAvailable: config.paymentMethodTypes.contains('paypal'),
    ));
  }

  Future<void> _onWalletPressed(
    PaymentSheetWalletPressed event,
    Emitter<PaymentSheetState> emit,
  ) =>
      _confirm(
        emit,
        PaymentMethodKind.wallet,
        () => _gateway.confirmPlatformPay(
          clientSecret: config.clientSecret,
          amountEur: config.amountEur,
        ),
      );

  Future<void> _onPayPalPressed(
    PaymentSheetPayPalPressed event,
    Emitter<PaymentSheetState> emit,
  ) =>
      _confirm(
        emit,
        PaymentMethodKind.paypal,
        () => _gateway.confirmPayPal(config.clientSecret),
      );

  /// Message du parcours carte quand la clé éphémère est irrécupérable :
  /// le toString() brut d'une AppException réseau n'est pas montrable.
  static const cardUnavailableMessage =
      'Le paiement par carte est indisponible pour le moment. '
      'Réessaie dans un instant.';

  /// Dernier filet de [_confirm] pour une erreur non mappée par le gateway.
  static const genericFailureMessage =
      'Le paiement a échoué. Réessaie dans un instant.';

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
  /// est remappé sur [cardUnavailableMessage].
  Future<void> _onCardPressed(
    PaymentSheetCardPressed event,
    Emitter<PaymentSheetState> emit,
  ) =>
      _confirm(
        emit,
        PaymentMethodKind.card,
        () async {
          final EphemeralKeyModel ephemeralKey;
          try {
            ephemeralKey =
                await (_ephemeralKeyFuture ??= _repository.createEphemeralKey());
          } catch (_) {
            _ephemeralKeyFuture = null; // ne pas mémoïser un échec
            throw const PaymentConfirmationException(cardUnavailableMessage);
          }
          await _gateway.initPaymentSheet(
            clientSecret: config.clientSecret,
            customerId: ephemeralKey.customerId,
            customerEphemeralKeySecret: ephemeralKey.ephemeralKeySecret,
          );
          await _gateway.presentPaymentSheet();
        },
      );

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
    try {
      await action();
      emit(PaymentSheetSuccess(method: method));
    } on PaymentCancelledException {
      emit(ready); // annulation silencieuse — la sheet reste prête
    } on PaymentConfirmationException catch (e) {
      emit(PaymentSheetFailure(message: e.message, ready: ready));
      emit(ready); // failure transitoire (snackbar) puis bouton ré-armé
    } catch (_) {
      // Dernier filet : une erreur non mappée par le gateway n'a pas de
      // message montrable (toString technique), on reste générique.
      emit(PaymentSheetFailure(message: genericFailureMessage, ready: ready));
      emit(ready);
    }
  }

  PaymentSheetResolved? get _currentReady => switch (state) {
        final PaymentSheetResolved s => s,
        PaymentSheetProcessing(:final ready) => ready,
        PaymentSheetFailure(:final ready) => ready,
        _ => null,
      };
}
