import 'dart:async';

import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocalAuthBloc extends Bloc<LocalAuthEvent, LocalAuthState> {
  final LocalAuthService _service;
  int _attemptsLeft = 3;

  LocalAuthBloc(this._service) : super(const LocalAuthInitial()) {
    on<LocalAuthStarted>(_onStarted);
    on<LocalAuthBiometricRequested>(_onBiometricRequested);
    on<LocalAuthPinSubmitted>(_onPinSubmitted);
    on<LocalAuthLockExpired>(_onLockExpired);
  }

  Future<void> _onStarted(LocalAuthStarted event, Emitter<LocalAuthState> emit) async {
    emit(const LocalAuthChecking());
    _attemptsLeft = 3;
    final biometricAvailable = await _service.isBiometricAvailable();

    if (biometricAvailable) {
      final success = await _service.authenticateWithBiometric();
      if (!isClosed && !emit.isDone) {
        if (success) {
          emit(const LocalAuthSuccess());
          return;
        }
      }
    }

    if (!emit.isDone) {
      emit(LocalAuthPinRequired(
        attemptsLeft: _attemptsLeft,
        biometricAvailable: biometricAvailable,
      ));
    }
  }

  Future<void> _onBiometricRequested(
    LocalAuthBiometricRequested event,
    Emitter<LocalAuthState> emit,
  ) async {
    final success = await _service.authenticateWithBiometric();
    if (success && !emit.isDone) {
      emit(const LocalAuthSuccess());
    }
  }

  Future<void> _onPinSubmitted(LocalAuthPinSubmitted event, Emitter<LocalAuthState> emit) async {
    final valid = await _service.validatePin(event.pin);
    if (valid) {
      _attemptsLeft = 3;
      emit(const LocalAuthSuccess());
      return;
    }

    _attemptsLeft--;
    if (_attemptsLeft <= 0) {
      _attemptsLeft = 0;
      // Widget will manage the countdown timer and dispatch LocalAuthLockExpired
      emit(const LocalAuthLocked(30));
      return;
    }

    final biometricAvailable = await _service.isBiometricAvailable();
    if (!emit.isDone) {
      emit(LocalAuthPinRequired(
        attemptsLeft: _attemptsLeft,
        biometricAvailable: biometricAvailable,
      ));
    }
  }

  void _onLockExpired(LocalAuthLockExpired event, Emitter<LocalAuthState> emit) {
    _attemptsLeft = 3;
    emit(const LocalAuthPinRequired());
  }
}
