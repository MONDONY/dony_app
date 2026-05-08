import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/kyc/bloc/kyc_event.dart';
import 'package:dony/features/kyc/bloc/kyc_state.dart';
import 'package:dony/features/kyc/data/repositories/kyc_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class KycBloc extends Bloc<KycEvent, KycState> {
  final KycRepository _repository;

  KycBloc(this._repository) : super(const KycInitial()) {
    on<KycSessionRequested>(_onSessionRequested);
    on<KycStatusRefreshed>(_onStatusRefreshed);
    on<KycReset>((_, emit) => emit(const KycInitial()));
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
    if (e is UnauthorizedException) return 'Session expirée. Reconnectez-vous.';
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 401) return 'Session expirée. Reconnectez-vous.';
      if (status == 409) return 'Votre identité est déjà vérifiée.';
      if (status == 503) return 'Service de vérification indisponible. Réessayez plus tard.';
    }
    final ex = e is AppException ? e : unwrapDioError(e);
    if (ex is UnauthorizedException) return 'Session expirée. Reconnectez-vous.';
    final msg = ex.message;
    if (msg.contains('409')) return 'Votre identité est déjà vérifiée.';
    if (msg.contains('503')) return 'Service de vérification indisponible. Réessayez plus tard.';
    return 'Une erreur est survenue. Réessayez.';
  }
}
