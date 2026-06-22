import 'dart:async';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/local_auth_event.dart';
import 'package:dony/features/auth/bloc/local_auth_state.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalAuthBloc extends Bloc<LocalAuthEvent, LocalAuthState> {
  final LocalAuthService _service;
  final Box _userPrefs;
  final FlutterSecureStorage _secureStorage;
  int _attemptsLeft = 3;

  static const _keyAttemptsLeft = 'pin_attempts_left';
  static const _keyLockoutUntil = 'pin_lockout_until';
  static const _maxAttempts = 3;
  static const _lockoutSeconds = 30;

  LocalAuthBloc(
    this._service,
    this._userPrefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       super(const LocalAuthInitial()) {
    on<LocalAuthStarted>(_onStarted);
    on<LocalAuthBiometricRequested>(_onBiometricRequested);
    on<LocalAuthPinSubmitted>(_onPinSubmitted);
    on<LocalAuthLockExpired>(_onLockExpired);
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  Future<void> _persistAttempts(int attempts) async {
    await _secureStorage.write(
      key: _keyAttemptsLeft,
      value: attempts.toString(),
    );
  }

  Future<int> _loadAttempts() async {
    final raw = await _secureStorage.read(key: _keyAttemptsLeft);
    if (raw == null) return _maxAttempts;
    return int.tryParse(raw) ?? _maxAttempts;
  }

  Future<void> _persistLockoutUntil(DateTime until) async {
    await _secureStorage.write(
      key: _keyLockoutUntil,
      value: until.toIso8601String(),
    );
  }

  Future<DateTime?> _loadLockoutUntil() async {
    final raw = await _secureStorage.read(key: _keyLockoutUntil);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _clearLockout() async {
    await _secureStorage.delete(key: _keyLockoutUntil);
  }

  Future<void> _resetAttemptsAndPersist() async {
    _attemptsLeft = _maxAttempts;
    await _persistAttempts(_maxAttempts);
    await _clearLockout();
  }

  // ── Event handlers ─────────────────────────────────────────────────────────

  Future<void> _onStarted(
    LocalAuthStarted event,
    Emitter<LocalAuthState> emit,
  ) async {
    emit(const LocalAuthChecking());

    // Check for active lockout from a previous session.
    final lockoutUntil = await _loadLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      final secondsLeft = lockoutUntil.difference(DateTime.now()).inSeconds;
      _attemptsLeft = 0;
      emit(LocalAuthLocked(secondsLeft > 0 ? secondsLeft : _lockoutSeconds));
      return;
    }
    // Lockout expired — clear it.
    if (lockoutUntil != null) {
      await _clearLockout();
    }

    // Load persisted attempt counter.
    _attemptsLeft = await _loadAttempts();
    // Clamp to valid range.
    if (_attemptsLeft <= 0 || _attemptsLeft > _maxAttempts) {
      _attemptsLeft = _maxAttempts;
      await _persistAttempts(_maxAttempts);
    }

    // Si aucun PIN n'est configuré → demander de le créer.
    final pinSet = await _service.isPinSet();
    if (!pinSet) {
      emit(const LocalAuthNoPinSet());
      return;
    }

    final appLockEnabled =
        _userPrefs.get(HiveService.kAppLockBiometric, defaultValue: true)
            as bool;
    final biometricAvailable = await _service.isBiometricAvailable();

    // E2E_SKIP_BIOMETRIC (dart-define, jamais en release) : saute le prompt
    // biométrique natif pour que le keypad PIN s'affiche direct dans les tests
    // integration_test (qui ne peuvent pas annuler un dialogue système natif).
    if (biometricAvailable &&
        appLockEnabled &&
        !const bool.fromEnvironment('E2E_SKIP_BIOMETRIC')) {
      final success = await _service.authenticateWithBiometric();
      if (!isClosed && !emit.isDone) {
        if (success) {
          await _resetAttemptsAndPersist();
          emit(const LocalAuthSuccess());
          return;
        }
      }
    }

    if (!emit.isDone) {
      emit(
        LocalAuthPinRequired(
          attemptsLeft: _attemptsLeft,
          biometricAvailable: biometricAvailable && appLockEnabled,
        ),
      );
    }
  }

  Future<void> _onBiometricRequested(
    LocalAuthBiometricRequested event,
    Emitter<LocalAuthState> emit,
  ) async {
    final appLockEnabled =
        _userPrefs.get(HiveService.kAppLockBiometric, defaultValue: true)
            as bool;
    if (!appLockEnabled) {
      return;
    }

    // E2E_SKIP_BIOMETRIC (dart-define, jamais en release) : ne déclenche pas le
    // prompt biométrique natif si l'event est reçu pendant un test (sinon le
    // dialogue système non annulable bloque le harness integration_test).
    if (const bool.fromEnvironment('E2E_SKIP_BIOMETRIC')) {
      return;
    }

    final success = await _service.authenticateWithBiometric();
    if (success && !emit.isDone) {
      await _resetAttemptsAndPersist();
      emit(const LocalAuthSuccess());
    }
  }

  Future<void> _onPinSubmitted(
    LocalAuthPinSubmitted event,
    Emitter<LocalAuthState> emit,
  ) async {
    final valid = await _service.validatePin(event.pin);
    if (valid) {
      await _resetAttemptsAndPersist();
      emit(const LocalAuthSuccess());
      return;
    }

    _attemptsLeft--;
    if (_attemptsLeft <= 0) {
      _attemptsLeft = 0;
      await _persistAttempts(0);
      final lockoutUntil = DateTime.now().add(
        const Duration(seconds: _lockoutSeconds),
      );
      await _persistLockoutUntil(lockoutUntil);
      // Widget will manage the countdown timer and dispatch LocalAuthLockExpired.
      emit(const LocalAuthLocked(_lockoutSeconds));
      return;
    }

    await _persistAttempts(_attemptsLeft);
    final appLockEnabled =
        _userPrefs.get(HiveService.kAppLockBiometric, defaultValue: true)
            as bool;
    final biometricAvailable = await _service.isBiometricAvailable();
    if (!emit.isDone) {
      emit(
        LocalAuthPinRequired(
          attemptsLeft: _attemptsLeft,
          biometricAvailable: biometricAvailable && appLockEnabled,
        ),
      );
    }
  }

  Future<void> _onLockExpired(
    LocalAuthLockExpired event,
    Emitter<LocalAuthState> emit,
  ) async {
    await _resetAttemptsAndPersist();
    emit(const LocalAuthPinRequired());
  }
}
