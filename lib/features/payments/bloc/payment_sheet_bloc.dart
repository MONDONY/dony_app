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

  /// Message unique du parcours carte : toute défaillance technique
  /// (clé éphémère, init, présentation) hors annulation utilisateur.
  static const cardUnavailableMessage =
      'Le paiement par carte est indisponible pour le moment. '
      'Réessaie dans un instant.';

  /// Récupère la clé éphémère du customer puis délègue toute la saisie/
  /// sélection de carte à la PaymentSheet native Stripe — elle confirme
  /// elle-même le PaymentIntent une fois l'utilisateur validé.
  ///
  /// Tout échec non-annulation est remappé sur [cardUnavailableMessage] :
  /// le toString() brut d'une AppException réseau n'est pas montrable.
  Future<void> _onCardPressed(
    PaymentSheetCardPressed event,
    Emitter<PaymentSheetState> emit,
  ) =>
      _confirm(
        emit,
        PaymentMethodKind.card,
        () async {
          try {
            final ephemeralKey = await _repository.createEphemeralKey(
              kStripeEphemeralKeyApiVersion,
            );
            await _gateway.initPaymentSheet(
              clientSecret: config.clientSecret,
              customerId: ephemeralKey.customerId,
              customerEphemeralKeySecret: ephemeralKey.ephemeralKeySecret,
            );
            await _gateway.presentPaymentSheet();
          } on PaymentCancelledException {
            rethrow; // annulation silencieuse, gérée par _confirm
          } catch (_) {
            throw const PaymentConfirmationException(cardUnavailableMessage);
          }
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
    } catch (e) {
      emit(PaymentSheetFailure(message: e.toString(), ready: ready));
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
