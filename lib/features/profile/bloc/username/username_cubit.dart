import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/data/models/username_availability.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum UsernameStatus {
  /// Rien à vérifier : champ vide ou format local invalide.
  idle,
  checking,
  available,
  unavailable,

  /// Un changement a déjà eu lieu dans les 30 derniers jours.
  tooSoon,
  saving,
  saved,

  /// `429` : trop de vérifications ou de changements.
  quota,
  error,

  /// Route absente (back pas encore déployé) : « Indisponible pour le
  /// moment », enregistrement désactivé.
  unsupported,

  /// `403` : un invité n'a pas d'identifiant à choisir.
  guest,
}

class UsernameState extends Equatable {
  const UsernameState({
    this.input = '',
    this.status = UsernameStatus.idle,
    this.reason,
    this.suggestions = const [],
    this.nextChangeAt,
    this.savedUser,
  });

  /// Saisie normalisée (minuscules, sans espaces autour).
  final String input;
  final UsernameStatus status;
  final UsernameReason? reason;
  final List<String> suggestions;

  /// Date à partir de laquelle un nouveau changement est possible.
  final DateTime? nextChangeAt;

  /// Compte mis à jour, une fois [UsernameStatus.saved].
  final UserModel? savedUser;

  /// Saisie commencée mais pas au format : le champ affiche l'astuce locale.
  bool get showsFormatHint =>
      status == UsernameStatus.idle &&
      input.isNotEmpty &&
      !UsernameCubit.isValidFormat(input);

  bool get canSave => status == UsernameStatus.available;

  @override
  List<Object?> get props => [
    input,
    status,
    reason,
    suggestions,
    nextChangeAt,
    savedUser,
  ];
}

/// Feuille « Mon identifiant » : vérifie la disponibilité pendant la frappe
/// puis enregistre.
///
/// Le contrôle de format local sert seulement à éviter des appels inutiles
/// (moins de 3 caractères, caractères interdits) : le serveur reste l'autorité
/// et son verdict est affiché tel quel.
class UsernameCubit extends Cubit<UsernameState> {
  UsernameCubit(this._repository, {this.debounce = defaultDebounce})
    : super(const UsernameState());

  static const defaultDebounce = Duration(milliseconds: 400);

  /// 3 à 20 caractères `a-z 0-9 . _`, sans séparateur en début, en fin ni
  /// doublé.
  static final _format = RegExp(r'^[a-z0-9]+(?:[._][a-z0-9]+)*$');

  static bool isValidFormat(String value) =>
      value.length >= 3 && value.length <= 20 && _format.hasMatch(value);

  final ProfileRepository _repository;
  final Duration debounce;

  Timer? _timer;
  CancelToken? _cancelToken;
  var _generation = 0;

  void inputChanged(String raw) {
    if (state.status == UsernameStatus.saving) return;
    final value = raw.trim().toLowerCase();
    _cancelPending();
    if (value.isEmpty || !isValidFormat(value)) {
      emit(UsernameState(input: value));
      return;
    }
    emit(UsernameState(input: value, status: UsernameStatus.checking));
    final generation = _generation;
    _timer = Timer(debounce, () => _check(value, generation));
  }

  /// Puce de suggestion touchée : remplit la saisie et revérifie sans délai.
  void suggestionTapped(String suggestion) {
    if (state.status == UsernameStatus.saving) return;
    final value = suggestion.trim().toLowerCase();
    _cancelPending();
    if (!isValidFormat(value)) {
      emit(UsernameState(input: value));
      return;
    }
    emit(UsernameState(input: value, status: UsernameStatus.checking));
    unawaited(_check(value, _generation));
  }

  Future<void> submit() async {
    if (!state.canSave) return;
    final value = state.input;
    _cancelPending();
    emit(UsernameState(input: value, status: UsernameStatus.saving));
    try {
      final user = await _repository.changeUsername(value);
      if (isClosed) return;
      emit(
        UsernameState(
          input: value,
          status: UsernameStatus.saved,
          savedUser: user,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(_stateFromSubmitError(value, unwrapDioError(e)));
    }
  }

  void _cancelPending() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  Future<void> _check(String value, int generation) async {
    final token = CancelToken();
    _cancelToken = token;
    try {
      final result = await _repository.checkUsername(value, cancelToken: token);
      if (isClosed || generation != _generation) return;
      emit(
        result.available
            ? UsernameState(input: value, status: UsernameStatus.available)
            : UsernameState(
                input: value,
                status: UsernameStatus.unavailable,
                reason: result.reason ?? UsernameReason.unknown,
                suggestions: result.suggestions,
              ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final error = unwrapDioError(e);
      emit(UsernameState(input: value, status: _statusFor(error)));
    }
  }

  /// État commun aux erreurs de vérification et d'envoi qui ne portent pas de
  /// verdict sur l'identifiant lui-même.
  static UsernameStatus _statusFor(AppException error) {
    if (error is RateLimitException) return UsernameStatus.quota;
    if (error is ForbiddenException) return UsernameStatus.guest;
    // Un 404 `user-not-found` n'a pas de sens ici ; tout autre 404 est une
    // route absente (ancien back).
    if (error is NotFoundException &&
        !(usernameProblemSlug(error)?.endsWith('user-not-found') ?? false)) {
      return UsernameStatus.unsupported;
    }
    return UsernameStatus.error;
  }

  UsernameState _stateFromSubmitError(String value, AppException error) {
    final common = _statusFor(error);
    if (common != UsernameStatus.error) {
      return UsernameState(input: value, status: common);
    }
    UsernameState unavailable(
      UsernameReason reason, [
      List<String> suggestions = const [],
    ]) => UsernameState(
      input: value,
      status: UsernameStatus.unavailable,
      reason: reason,
      suggestions: suggestions,
    );
    switch (usernameProblemSlug(error)) {
      case 'username-taken':
        final ext = error is ConflictException ? error.extensions : null;
        final raw = ext?['suggestions'];
        return unavailable(
          UsernameReason.taken,
          raw is List ? raw.whereType<String>().toList() : const [],
        );
      case 'username-change-too-soon':
        final ext = error is ConflictException ? error.extensions : null;
        final at = ext?['nextChangeAt'];
        return UsernameState(
          input: value,
          status: UsernameStatus.tooSoon,
          nextChangeAt: at is String ? DateTime.tryParse(at) : null,
        );
      case 'username-reserved':
        return unavailable(UsernameReason.reserved);
      case 'username-looks-like-phone':
        return unavailable(UsernameReason.looksLikePhone);
      case 'username-invalid':
        return unavailable(UsernameReason.invalidFormat);
    }
    return UsernameState(input: value, status: UsernameStatus.error);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _cancelToken?.cancel();
    return super.close();
  }
}
