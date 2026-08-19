import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

sealed class CountryOnboardingState extends Equatable {
  const CountryOnboardingState();

  @override
  List<Object?> get props => const [];
}

class CountryOnboardingInitial extends CountryOnboardingState {
  const CountryOnboardingInitial();
}

class CountryOnboardingSaving extends CountryOnboardingState {
  const CountryOnboardingSaving(this.countryCode);

  final String? countryCode;

  @override
  List<Object?> get props => [countryCode];
}

class CountryOnboardingSuccess extends CountryOnboardingState {
  const CountryOnboardingSuccess();
}

class CountryOnboardingError extends CountryOnboardingState {
  const CountryOnboardingError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Persiste le pays d'onboarding dans l'ordre strict backend → Hive.
///
/// Le [BusinessPrefsBloc] des réglages est volontairement optimiste. Cet
/// onboarding ne peut pas l'être : l'utilisateur ne poursuit que lorsque le
/// backend, source de vérité pour la devise dérivée et les paiements, a
/// accepté son choix.
///
/// Le pays a le droit de rester vide : c'est un état normal signifiant « pas
/// encore renseigné », complétable plus tard dans les Réglages. Contrairement
/// à l'ancienne devise obligatoire, [skip] ne relit donc aucune valeur
/// backend : il se contente de mémoriser que l'étape a été vue.
class CountryOnboardingCubit extends Cubit<CountryOnboardingState> {
  CountryOnboardingCubit(this._repository, this._prefs, this._analytics)
    : super(const CountryOnboardingInitial());

  final BusinessPrefsRepository _repository;
  final Box<dynamic> _prefs;
  final AnalyticsService _analytics;

  Future<void> select(String countryCode) async {
    if (state is CountryOnboardingSaving) return;

    emit(CountryOnboardingSaving(countryCode));
    try {
      final current = await _repository.fetchPrefs();
      await _repository.updatePrefs(current.copyWith(country: countryCode));
      await _prefs.put(HiveService.kCountryCode, countryCode);
      await _prefs.put(HiveService.kCountryOnboardingSeen, true);
      unawaited(_analytics.logEvent(AnalyticsEvents.countryOnboardingSelected));
      emit(const CountryOnboardingSuccess());
    } catch (_) {
      emit(
        const CountryOnboardingError(
          'Impossible d’enregistrer le pays. Réessayez.',
        ),
      );
    }
  }

  Future<void> skip() async {
    if (state is CountryOnboardingSaving) return;

    emit(const CountryOnboardingSaving(null));
    try {
      await _prefs.put(HiveService.kCountryOnboardingSeen, true);
      unawaited(_analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped));
      emit(const CountryOnboardingSuccess());
    } catch (_) {
      emit(
        const CountryOnboardingError(
          'Impossible d’enregistrer ce choix. Réessayez.',
        ),
      );
    }
  }
}
