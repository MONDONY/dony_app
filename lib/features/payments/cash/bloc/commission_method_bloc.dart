import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/repositories/commission_method_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommissionMethodBloc
    extends Bloc<CommissionMethodEvent, CommissionMethodState> {
  final CommissionMethodRepository _repo;

  CommissionMethodBloc(this._repo) : super(CommissionMethodInitial()) {
    on<CommissionMethodLoadRequested>(_load);
    on<CommissionMethodSetupRequested>(_setup);
    on<CommissionMethodSetupCompleted>(_saveAndReload);
    on<CommissionMethodSetupCancelled>(
      (_, _) => add(CommissionMethodLoadRequested()),
    );
    on<CommissionMethodDeleteRequested>(_delete);
  }

  Future<void> _load(_, Emitter<CommissionMethodState> emit) async {
    emit(CommissionMethodLoading());
    try {
      final card = await _repo.load();
      emit(
        card == null
            ? CommissionMethodNotConfigured()
            : CommissionMethodLoaded(card),
      );
    } catch (e) {
      emit(CommissionMethodError(e.toString()));
    }
  }

  Future<void> _setup(_, Emitter<CommissionMethodState> emit) async {
    try {
      final secret = await _repo.startSetup();
      emit(CommissionMethodSetupInProgress(secret));
    } catch (e) {
      emit(CommissionMethodError(e.toString()));
    }
  }

  Future<void> _saveAndReload(
    CommissionMethodSetupCompleted event,
    Emitter<CommissionMethodState> emit,
  ) async {
    emit(CommissionMethodLoading());
    try {
      await _repo.savePaymentMethod(event.paymentMethodId);
      final card = await _repo.load();
      emit(
        card == null
            ? CommissionMethodNotConfigured()
            : CommissionMethodLoaded(card),
      );
    } catch (e) {
      emit(CommissionMethodError(e.toString()));
    }
  }

  Future<void> _delete(_, Emitter<CommissionMethodState> emit) async {
    emit(CommissionMethodLoading());
    try {
      await _repo.remove();
      emit(CommissionMethodNotConfigured());
    } catch (e) {
      emit(CommissionMethodError(e.toString()));
    }
  }
}
