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
/// encore renseigné », complétable plus tard dans les Réglages. [skip] ne
/// bloque donc jamais sur le réseau : il relit les préférences au mieux, pour
/// poser la devise par défaut du serveur en cache, sans échouer si cette
/// lecture échoue.
///
/// Les deux chemins écrivent [HiveService.kCurrencyCode] avec la devise
/// **renvoyée par le serveur** : sans ce cache, `ActiveCurrency.current` rend
/// `null` et tout le calcul de prix retombe sur les plafonds EUR pour un
/// utilisateur qui n'ouvrirait jamais Réglages › Préférences.
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
      final saved = await _repository.updatePrefs(
        current.copyWith(country: countryCode),
      );
      await _prefs.put(HiveService.kCountryCode, countryCode);
      // Devise du serveur, jamais `CountryCatalog.byCode(...).currency` : la
      // table locale n'est qu'un miroir d'affichage, le backend tranche.
      await _prefs.put(HiveService.kCurrencyCode, saved.currencyCode);
      await _prefs.put(HiveService.kTravelerCountryUnsupported, false);
      unawaited(_analytics.logEvent(AnalyticsEvents.countryOnboardingSelected));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.onboardingStepCompleted,
          properties: {'step': 'country'},
        ),
      );
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
      // Au mieux : poser en cache la devise par défaut du serveur. Un échec
      // réseau ne doit pas empêcher de passer l'étape, l'utilisateur n'a rien
      // à enregistrer ici.
      try {
        final current = await _repository.fetchPrefs();
        await _prefs.put(HiveService.kCurrencyCode, current.currencyCode);
      } catch (_) {
        // Ignoré volontairement : la devise sera posée à la première synchro.
      }
      unawaited(_analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.onboardingStepSkipped,
          properties: {'step': 'country'},
        ),
      );
      emit(const CountryOnboardingSuccess());
    } catch (_) {
      emit(
        const CountryOnboardingError(
          'Impossible d’enregistrer ce choix. Réessayez.',
        ),
      );
    }
  }

  Future<void> continueAsSenderOnly() async {
    if (state is CountryOnboardingSaving) return;

    emit(const CountryOnboardingSaving(null));
    try {
      await _prefs.put(HiveService.kTravelerCountryUnsupported, true);
      unawaited(_analytics.logEvent(AnalyticsEvents.countryOnboardingSkipped));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.onboardingStepSkipped,
          properties: {'step': 'country'},
        ),
      );
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
