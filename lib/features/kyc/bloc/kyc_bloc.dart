import 'package:dio/dio.dart';
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

  String _friendlyError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 409) {
        return 'Votre identité est déjà vérifiée.';
      }
      if (status == 503) {
        return 'Service de vérification indisponible. Réessayez plus tard.';
      }
      if (status == 401) {
        return 'Session expirée. Reconnectez-vous.';
      }
    }
    final s = e.toString();
    if (s.contains('503') || s.contains('SERVICE_UNAVAILABLE')) {
      return 'Service de vérification indisponible. Réessayez plus tard.';
    }
    if (s.contains('409') || s.contains('CONFLICT')) {
      return 'Votre identité est déjà vérifiée.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
