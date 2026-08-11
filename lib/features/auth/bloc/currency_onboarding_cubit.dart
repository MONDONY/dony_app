import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

sealed class CurrencyOnboardingState extends Equatable {
  const CurrencyOnboardingState();

  @override
  List<Object?> get props => const [];
}

class CurrencyOnboardingInitial extends CurrencyOnboardingState {
  const CurrencyOnboardingInitial();
}

class CurrencyOnboardingSaving extends CurrencyOnboardingState {
  const CurrencyOnboardingSaving(this.currencyCode);

  final String? currencyCode;

  @override
  List<Object?> get props => [currencyCode];
}

class CurrencyOnboardingSuccess extends CurrencyOnboardingState {
  const CurrencyOnboardingSuccess();
}

class CurrencyOnboardingError extends CurrencyOnboardingState {
  const CurrencyOnboardingError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Persiste la devise d'onboarding dans l'ordre strict backend → Hive.
///
/// Le [BusinessPrefsBloc] des réglages est volontairement optimiste. Cet
/// onboarding ne peut pas l'être : l'utilisateur ne poursuit que lorsque le
/// backend, source de vérité pour la visibilité et les paiements, a accepté
/// son choix.
class CurrencyOnboardingCubit extends Cubit<CurrencyOnboardingState> {
  CurrencyOnboardingCubit(this._repository, this._prefs, this._analytics)
    : super(const CurrencyOnboardingInitial());

  final BusinessPrefsRepository _repository;
  final Box<dynamic> _prefs;
  final AnalyticsService _analytics;

  Future<void> select(String currencyCode) async {
    if (state is CurrencyOnboardingSaving) return;

    emit(CurrencyOnboardingSaving(currencyCode));
    try {
      final current = await _repository.fetchPrefs();
      await _repository.updatePrefs(
        UserBusinessPrefsDto(
          weightUnit: current.weightUnit,
          currencyCode: currencyCode,
          pickupRadiusKm: current.pickupRadiusKm,
          defaultPackageWeightKg: current.defaultPackageWeightKg,
          minBidPriceEur: current.minBidPriceEur,
          contactMode: current.contactMode,
          responseDelayHours: current.responseDelayHours,
        ),
      );
      await _prefs.put(HiveService.kCurrencyCode, currencyCode);
      await _prefs.put(HiveService.kCurrencyOnboardingSeen, true);
      unawaited(
        _analytics.logEvent(AnalyticsEvents.currencyOnboardingSelected),
      );
      emit(const CurrencyOnboardingSuccess());
    } catch (_) {
      emit(
        const CurrencyOnboardingError(
          'Impossible d’enregistrer la devise. Réessayez.',
        ),
      );
    }
  }

  Future<void> skip() async {
    if (state is CurrencyOnboardingSaving) return;

    emit(const CurrencyOnboardingSaving(null));
    try {
      await _prefs.put(HiveService.kCurrencyOnboardingSeen, true);
      unawaited(_analytics.logEvent(AnalyticsEvents.currencyOnboardingSkipped));
      emit(const CurrencyOnboardingSuccess());
    } catch (_) {
      emit(
        const CurrencyOnboardingError(
          'Impossible d’enregistrer ce choix. Réessayez.',
        ),
      );
    }
  }
}
