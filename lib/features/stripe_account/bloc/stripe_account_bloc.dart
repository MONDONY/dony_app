import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/features/stripe_account/data/stripe_account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'stripe_account_event.dart';
part 'stripe_account_state.dart';

class StripeAccountBloc extends Bloc<StripeAccountEvent, StripeAccountState> {
  final IStripeAccountRepository _repository;

  StripeAccountBloc(this._repository) : super(const StripeAccountInitial()) {
    on<StripeAccountStatusLoaded>(_onLoad);
    on<StripeAccountStatusRefreshed>(_onRefresh);
  }

  Future<void> _onLoad(
    StripeAccountStatusLoaded event,
    Emitter<StripeAccountState> emit,
  ) async {
    emit(const StripeAccountLoading());
    await _fetch(emit);
  }

  Future<void> _onRefresh(
    StripeAccountStatusRefreshed event,
    Emitter<StripeAccountState> emit,
  ) async {
    await _fetch(emit);
  }

  Future<void> _fetch(Emitter<StripeAccountState> emit) async {
    try {
      final status = await _repository.getAccountStatus();
      emit(StripeAccountReady(status));
    } catch (_) {
      emit(const StripeAccountLoadError());
    }
  }
}
