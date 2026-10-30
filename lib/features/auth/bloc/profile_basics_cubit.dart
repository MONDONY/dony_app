import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/repositories/auth_repository.dart';
import 'package:dony/features/auth/data/services/residence_country_writer.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

sealed class ProfileBasicsState extends Equatable {
  const ProfileBasicsState();

  @override
  List<Object?> get props => const [];
}

class ProfileBasicsInitial extends ProfileBasicsState {
  const ProfileBasicsInitial();
}

class ProfileBasicsSaving extends ProfileBasicsState {
  const ProfileBasicsSaving();
}

/// L'écran peut partir. [refreshProfile] vaut `true` quand quelque chose a
/// été écrit au serveur pendant la vie de l'écran : le `UserModel` en cache
/// d'`AuthBloc` est alors périmé.
class ProfileBasicsSuccess extends ProfileBasicsState {
  const ProfileBasicsSuccess({required this.refreshProfile});

  final bool refreshProfile;

  @override
  List<Object?> get props => [refreshProfile];
}

class ProfileBasicsError extends ProfileBasicsState {
  const ProfileBasicsError();
}

/// Écran facultatif « Faisons connaissance » : prénom, nom et pays de
/// résidence, rien d'obligatoire.
///
/// [submit] n'écrit que ce qui est saisi : le nom si au moins un des deux
/// champs n'est pas vide (espaces retirés), puis le pays s'il est choisi. Si
/// le nom échoue, le pays n'est pas tenté : l'utilisateur réessaie ou passe.
/// [skip] n'appelle aucun repository et ne peut pas échouer.
class ProfileBasicsCubit extends Cubit<ProfileBasicsState> {
  ProfileBasicsCubit(
    this._authRepository,
    this._businessPrefsRepository,
    this._prefs,
    this._analytics,
  ) : super(const ProfileBasicsInitial());

  final AuthRepository _authRepository;
  final BusinessPrefsRepository _businessPrefsRepository;
  final Box<dynamic> _prefs;
  final AnalyticsService _analytics;

  /// Un nom écrit avant un échec du pays reste écrit : passer ensuite doit
  /// quand même rafraîchir le profil.
  bool _wroteSomething = false;

  /// Vue de l'écran, appelée par l'écran à sa première image.
  void trackViewed() {
    unawaited(_analytics.logEvent(AnalyticsEvents.profileBasicsViewed));
  }

  Future<void> submit({
    String firstName = '',
    String lastName = '',
    String? countryCode,
  }) async {
    if (state is ProfileBasicsSaving) return;

    final first = firstName.trim();
    final last = lastName.trim();
    final hasName = first.isNotEmpty || last.isNotEmpty;
    final country = countryCode?.trim() ?? '';
    final hasCountry = country.isNotEmpty;

    if (hasName || hasCountry) {
      emit(const ProfileBasicsSaving());
      if (hasName && !await _write('name', () => _writeName(first, last))) {
        return;
      }
      if (hasCountry &&
          !await _write(
            'country',
            () => writeResidenceCountry(
              _businessPrefsRepository,
              _prefs,
              country,
            ),
          )) {
        return;
      }
    }

    // Aucune PII : seulement ce qui a été renseigné.
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.profileBasicsCompleted,
        properties: {'has_name': hasName, 'has_country': hasCountry},
      ),
    );
    emit(ProfileBasicsSuccess(refreshProfile: _wroteSomething));
  }

  Future<void> skip() async {
    if (state is ProfileBasicsSaving) return;
    unawaited(_analytics.logEvent(AnalyticsEvents.profileBasicsSkipped));
    emit(ProfileBasicsSuccess(refreshProfile: _wroteSomething));
  }

  // Un champ vide part en `null` : le serveur garde alors sa valeur.
  Future<void> _writeName(String first, String last) =>
      _authRepository.updateProfile(
        firstName: first.isEmpty ? null : first,
        lastName: last.isEmpty ? null : last,
      );

  /// Rend `false` après avoir émis l'erreur et son événement d'échec.
  Future<bool> _write(String step, Future<void> Function() write) async {
    try {
      await write();
      _wroteSomething = true;
      return true;
    } catch (e) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.profileBasicsFailed,
          properties: {
            'step': step,
            'error_code': (e is AppException ? e.code : null) ?? 'unknown',
          },
        ),
      );
      emit(const ProfileBasicsError());
      return false;
    }
  }
}
