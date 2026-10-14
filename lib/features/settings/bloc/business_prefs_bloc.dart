import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';
import 'package:dony/features/settings/data/repositories/business_prefs_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'business_prefs_event.dart';
part 'business_prefs_state.dart';

class BusinessPrefsBloc extends Bloc<BusinessPrefsEvent, BusinessPrefsState> {
  final BusinessPrefsRepository _repo;
  final Box _box;

  /// Facultatif : les nombreux tests qui construisent ce bloc sans analytics
  /// restent valables. L'injection le fournit toujours.
  final AnalyticsService? _analytics;

  BusinessPrefsBloc(this._repo, this._box, {AnalyticsService? analytics})
    : _analytics = analytics,
      super(_initialState(_box)) {
    on<BusinessPrefsSyncRequested>(_onSync);
    on<BusinessPrefsReset>(_onReset);
    on<WeightUnitChanged>(_onWeightUnit);
    on<CurrencyChanged>(_onCurrency);
    on<DisplayCurrencyChanged>(_onDisplayCurrency);
    on<CountryChanged>(_onCountry);
    on<DefaultWeightChanged>(_onDefaultWeight);
    on<MinBidPriceChanged>(_onMinBidPrice);
    on<ContactModeChanged>(_onContactMode);
    on<ResponseDelayChanged>(_onResponseDelay);
  }

  static BusinessPrefsState _initialState(Box box) => BusinessPrefsState(
    weightUnit: box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
    currencyCode:
        box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
    defaultPackageWeightKg:
        box.get(HiveService.kDefaultPackageWeight, defaultValue: 23) as int,
    minBidPriceEur: box.get(HiveService.kMinBidPrice, defaultValue: 0) as int,
    contactMode: box.get(HiveService.kContactMode) as String?,
    responseDelayHours: box.get(HiveService.kResponseDelay) as int?,
    country: box.get(HiveService.kCountryCode) as String?,
    displayCurrencyCode:
        box.get(HiveService.kDisplayCurrencyCode, defaultValue: 'AUTO')
            as String,
  );

  // ── Sync depuis API ────────────────────────────────────────────────────────

  Future<void> _onSync(
    BusinessPrefsSyncRequested event,
    Emitter<BusinessPrefsState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true));
    try {
      final dto = await _repo.fetchPrefs();
      await _writeToHive(dto);
      emit(
        _dtoToState(dto).copyWith(
          isSyncing: false,
          countrySavedCount: state.countrySavedCount,
        ),
      );
    } catch (_) {
      emit(state.copyWith(isSyncing: false));
    }
  }

  // ── Reset (déconnexion / changement de compte / nouvelle inscription) ─────

  /// `AuthBloc._clearHiveAccountData()` a déjà vidé `_box` : relire Hive ici
  /// rend donc les valeurs par défaut (ou celles d'un tout nouveau compte),
  /// jamais celles du compte précédent. Voir `BusinessPrefsReset`.
  Future<void> _onReset(
    BusinessPrefsReset event,
    Emitter<BusinessPrefsState> emit,
  ) async {
    emit(_initialState(_box));
  }

  // ── Handlers existants (+ sync API en arrière-plan) ───────────────────────

  Future<void> _onWeightUnit(
    WeightUnitChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kWeightUnit, e.unit);
    emit(state.copyWith(weightUnit: e.unit, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  /// Verrouillée par le seul solde du portefeuille (`currencyLocked`,
  /// `CurrencyLockService` côté backend) — ce verrou ne dépend pas du pays et
  /// ne l'influence pas non plus. La tuile n'appelle ce handler que si
  /// `!state.currencyLocked` ; on rejoue le même schéma optimiste que les
  /// autres réglages simples, sans relecture serveur supplémentaire.
  Future<void> _onCurrency(
    CurrencyChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kCurrencyCode, e.code);
    emit(state.copyWith(currencyCode: e.code, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  /// Même schéma optimiste que [_onCurrency], sans aucun verrou : la devise
  /// d'affichage est purement visuelle (lot 8, presentment) et le backend
  /// l'exempte de `CurrencyLockService`.
  Future<void> _onDisplayCurrency(
    DisplayCurrencyChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kDisplayCurrencyCode, e.code);
    emit(state.copyWith(displayCurrencyCode: e.code, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  /// Le pays part au serveur, qui recalcule seul la devise (lot pays-
  /// onboarding-devise-dérivée) : on ne la devine jamais côté client. La
  /// réponse du `PUT` porte déjà l'état complet recalculé, devise et verrous
  /// compris : on l'adopte telle quelle, sans relecture supplémentaire.
  Future<void> _onCountry(
    CountryChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kCountryCode, e.code);
    emit(
      state.copyWith(
        isSyncing: true,
        countryGetter: () => e.code,
        hasSyncError: false,
      ),
    );
    try {
      final saved = await _repo.updatePrefs(_stateToDto(state));
      await _writeToHive(saved);
      emit(
        _dtoToState(saved).copyWith(
          isSyncing: false,
          countrySavedCount: prev.countrySavedCount + 1,
        ),
      );
      if (e.code != prev.country) {
        unawaited(
          _analytics?.logEvent(
            AnalyticsEvents.residenceCountryChanged,
            properties: {
              'reset_payout_setup': prev.countryChangeResetsPayoutSetup,
            },
          ),
        );
      }
    } catch (err) {
      // Plus de retour silencieux à l'ancien pays : la raison du refus
      // (`country-locked`, hors ligne…) part à l'écran, qui l'affiche.
      await _writeToHive(_stateToDto(prev));
      emit(
        prev.copyWith(
          isSyncing: false,
          hasSyncError: true,
          countryChangeError: unwrapDioError(err),
        ),
      );
    }
  }

  Future<void> _onDefaultWeight(
    DefaultWeightChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kDefaultPackageWeight, e.kg);
    emit(state.copyWith(defaultPackageWeightKg: e.kg, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onMinBidPrice(
    MinBidPriceChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    await _box.put(HiveService.kMinBidPrice, e.euros);
    emit(state.copyWith(minBidPriceEur: e.euros, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onContactMode(
    ContactModeChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    if (e.mode == null) {
      await _box.delete(HiveService.kContactMode);
    } else {
      await _box.put(HiveService.kContactMode, e.mode);
    }
    emit(state.copyWith(contactModeGetter: () => e.mode, hasSyncError: false));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onResponseDelay(
    ResponseDelayChanged e,
    Emitter<BusinessPrefsState> emit,
  ) async {
    final prev = state;
    if (e.hours == null) {
      await _box.delete(HiveService.kResponseDelay);
    } else {
      await _box.put(HiveService.kResponseDelay, e.hours);
    }
    emit(
      state.copyWith(
        responseDelayHoursGetter: () => e.hours,
        hasSyncError: false,
      ),
    );
    await _putOrRollback(emit, prev);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _putOrRollback(
    Emitter<BusinessPrefsState> emit,
    BusinessPrefsState prev,
  ) async {
    emit(state.copyWith(isSyncing: true));
    try {
      await _repo.updatePrefs(_stateToDto(state));
      emit(state.copyWith(isSyncing: false));
    } catch (_) {
      await _writeToHive(_stateToDto(prev));
      emit(prev.copyWith(isSyncing: false, hasSyncError: true));
    }
  }

  Future<void> _writeToHive(UserBusinessPrefsDto dto) async {
    await _box.put(HiveService.kWeightUnit, dto.weightUnit);
    await _box.put(HiveService.kCurrencyCode, dto.currencyCode);
    await _box.put(
      HiveService.kDefaultPackageWeight,
      dto.defaultPackageWeightKg,
    );
    await _box.put(HiveService.kMinBidPrice, dto.minBidPriceEur);
    if (dto.contactMode == null) {
      await _box.delete(HiveService.kContactMode);
    } else {
      await _box.put(HiveService.kContactMode, dto.contactMode);
    }
    if (dto.responseDelayHours == null) {
      await _box.delete(HiveService.kResponseDelay);
    } else {
      await _box.put(HiveService.kResponseDelay, dto.responseDelayHours);
    }
    if (dto.country == null) {
      await _box.delete(HiveService.kCountryCode);
    } else {
      await _box.put(HiveService.kCountryCode, dto.country);
    }
    await _box.put(HiveService.kDisplayCurrencyCode, dto.displayCurrencyCode);
  }

  BusinessPrefsState _dtoToState(UserBusinessPrefsDto dto) =>
      BusinessPrefsState(
        weightUnit: dto.weightUnit,
        currencyCode: dto.currencyCode,
        defaultPackageWeightKg: dto.defaultPackageWeightKg,
        minBidPriceEur: dto.minBidPriceEur,
        contactMode: dto.contactMode,
        responseDelayHours: dto.responseDelayHours,
        currencyLocked: dto.currencyLocked,
        country: dto.country,
        countryLocked: dto.countryLocked,
        countryChangeResetsPayoutSetup: dto.countryChangeResetsPayoutSetup,
        displayCurrencyCode: dto.displayCurrencyCode,
      );

  UserBusinessPrefsDto _stateToDto(BusinessPrefsState s) =>
      UserBusinessPrefsDto(
        weightUnit: s.weightUnit,
        currencyCode: s.currencyCode,
        defaultPackageWeightKg: s.defaultPackageWeightKg,
        minBidPriceEur: s.minBidPriceEur,
        contactMode: s.contactMode,
        responseDelayHours: s.responseDelayHours,
        country: s.country,
        displayCurrencyCode: s.displayCurrencyCode,
      );
}
