import 'package:dony/features/payments/data/models/saved_card_model.dart';
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
    on<PaymentSheetCardChoiceChanged>(_onCardChoiceChanged);
    on<PaymentSheetPayPressed>(_onPayPressed);
    on<PaymentSheetSaveCardToggled>(_onSaveCardToggled);
    on<PaymentSheetBackToMainPressed>(_onBackToMain);
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

    List<SavedCardModel> savedCards = const [];
    try {
      savedCards = await _repository.listSavedPaymentMethods();
    } catch (_) {}

    emit(PaymentSheetResolved(
      walletAvailable: walletAvailable,
      paypalAvailable: config.paymentMethodTypes.contains('paypal'),
      savedCards: savedCards,
      saveCard: true,
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

  void _onCardChoiceChanged(
    PaymentSheetCardChoiceChanged event,
    Emitter<PaymentSheetState> emit,
  ) {
    final ready = _currentReady;
    if (ready == null) return;
    emit(ready.copyWith(cardChoice: event.choice));
  }

  Future<void> _onPayPressed(
    PaymentSheetPayPressed event,
    Emitter<PaymentSheetState> emit,
  ) async {
    final choice = _currentReady?.cardChoice;
    switch (choice) {
      case SavedCardChoice(:final card):
        await _confirm(
          emit,
          PaymentMethodKind.savedCard,
          () => _gateway.confirmWithSavedCard(
            clientSecret: config.clientSecret,
            paymentMethodId: card.id,
          ),
        );
      case NewCardChoice():
        await _confirm(
          emit,
          PaymentMethodKind.newCard,
          () => _gateway.confirmWithNewCard(config.clientSecret),
        );
      case null:
        return; // bouton payer inactif tant qu'aucune carte n'est choisie
    }
  }

  Future<void> _onSaveCardToggled(
    PaymentSheetSaveCardToggled event,
    Emitter<PaymentSheetState> emit,
  ) async {
    final ready = _currentReady;
    if (ready == null) return;
    emit(ready.copyWith(saveCard: event.save));
    try {
      await _repository.updateSavePaymentMethod(
        config.paymentIntentId,
        event.save,
      );
    } catch (_) {
      // Non bloquant : au pire la carte est enregistrée alors que l'utilisateur
      // a décoché — elle reste supprimable côté Stripe, le paiement n'est pas gêné.
    }
  }

  void _onBackToMain(
    PaymentSheetBackToMainPressed event,
    Emitter<PaymentSheetState> emit,
  ) {
    final ready = _currentReady;
    if (ready == null) return;
    emit(PaymentSheetResolved(
      walletAvailable: ready.walletAvailable,
      paypalAvailable: ready.paypalAvailable,
      savedCards: ready.savedCards,
      saveCard: ready.saveCard,
    ));
  }

  Future<void> _confirm(
    Emitter<PaymentSheetState> emit,
    PaymentMethodKind method,
    Future<void> Function() action,
  ) async {
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
