import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class KycBloc extends Bloc<KycEvent, KycState> {
  final KycRepository _repository;

  KycBloc(this._repository) : super(const KycInitial()) {
    on<KycSessionRequested>(_onSessionRequested);
    on<KycStatusRefreshed>(_onStatusRefreshed);
  }

  Future<void> _onSessionRequested(
    KycSessionRequested event,
    Emitter<KycState> emit,
  ) async {
    emit(const KycLoading());
    try {
      final data = await _repository.createSession();
      emit(KycSessionCreated(
        stripeUrl: data['stripeUrl'] as String,
        sessionId: data['sessionId'] as String,
      ));
    } catch (e) {
      emit(KycError(_friendlyError(e)));
    }
  }

  Future<void> _onStatusRefreshed(
    KycStatusRefreshed event,
    Emitter<KycState> emit,
  ) async {
    try {
      final data = await _repository.getStatus();
      emit(KycStatusLoaded(
        kycStatus: data['kycStatus'] as String,
        verificationStatus: data['verificationStatus'] as String,
      ));
    } catch (e) {
      emit(KycError(_friendlyError(e)));
    }
  }

  String _friendlyError(Object e) =>
      e.toString().contains('503') || e.toString().contains('SERVICE_UNAVAILABLE')
          ? 'Service de vérification indisponible. Réessayez plus tard.'
          : e.toString().contains('409') || e.toString().contains('CONFLICT')
              ? 'Votre identité est déjà vérifiée.'
              : 'Une erreur est survenue. Réessayez.';
}
