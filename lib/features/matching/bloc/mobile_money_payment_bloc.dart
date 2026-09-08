import 'package:dony/features/matching/bloc/mobile_money_payment_event.dart';
import 'package:dony/features/matching/bloc/mobile_money_payment_state.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/repositories/mobile_money_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// NOTE : adaptation a minima au nouveau contrat MobileMoneyPaymentStatus
// (tâche 3 du plan pawaPay). Ce bloc est entièrement réécrit par la tâche 5 ;
// il ne fait ici que mapper le nouveau statut vers les états existants.
class MobileMoneyPaymentBloc
    extends Bloc<MobileMoneyPaymentEvent, MobileMoneyPaymentState> {
  MobileMoneyPaymentBloc(this._repository)
    : super(const MobileMoneyPaymentInitial()) {
    on<MobileMoneyStatusPolled>(_onStatusPolled);
    on<MobileMoneyLinkRegenRequested>(_onLinkRegen);
  }

  final MobileMoneyRepository _repository;

  Future<void> _onStatusPolled(
    MobileMoneyStatusPolled event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    // Emit Loading only on the first call (Initial or Error state).
    // Periodic polls silently refresh to avoid flashing a full-screen spinner
    // over the PENDING content + "Payer maintenant" button.
    if (state is MobileMoneyPaymentInitial ||
        state is MobileMoneyPaymentError) {
      emit(const MobileMoneyPaymentLoading());
    }
    try {
      final status = await _repository.getStatus(event.bidId);
      emit(_stateFor(status));
    } catch (e) {
      emit(MobileMoneyPaymentError(e.toString()));
    }
  }

  Future<void> _onLinkRegen(
    MobileMoneyLinkRegenRequested event,
    Emitter<MobileMoneyPaymentState> emit,
  ) async {
    emit(const MobileMoneyPaymentLoading());
    try {
      final status = await _repository.initiate(event.bidId);
      emit(_stateFor(status));
    } catch (e) {
      emit(MobileMoneyPaymentError(e.toString()));
    }
  }

  /// Traduit le statut serveur en état d'écran. Ordre de priorité : un
  /// paiement déjà séquestré prime sur l'expiration, qui prime elle-même sur
  /// l'échec du dernier dépôt.
  MobileMoneyPaymentState _stateFor(MobileMoneyPaymentStatus status) {
    if (status.isEscrowed) return const MobileMoneyPaymentConfirmed();
    if (status.isExpired(DateTime.now())) {
      return const MobileMoneyPaymentExpired();
    }
    if (status.isDepositFailed) {
      return MobileMoneyPaymentError(
        status.deposit?.failureMessage ?? 'Paiement échoué',
      );
    }
    return MobileMoneyPaymentPending(
      paymentLink: status.deposit?.authorizationUrl ?? '',
      expiresAt: status.deadlineAt,
    );
  }
}
