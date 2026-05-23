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

  BusinessPrefsBloc(this._repo, this._box)
      : super(_initialState(_box)) {
    on<BusinessPrefsSyncRequested>(_onSync);
    on<WeightUnitChanged>(_onWeightUnit);
    on<CurrencyChanged>(_onCurrency);
    on<PickupRadiusChanged>(_onPickupRadius);
    on<DefaultWeightChanged>(_onDefaultWeight);
    on<MinBidPriceChanged>(_onMinBidPrice);
    on<ContactModeChanged>(_onContactMode);
    on<ResponseDelayChanged>(_onResponseDelay);
  }

  static BusinessPrefsState _initialState(Box box) => BusinessPrefsState(
        weightUnit: box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
        currencyCode: box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
        pickupRadiusKm: box.get(HiveService.kPickupRadiusKm, defaultValue: 10) as int,
        defaultPackageWeightKg:
            box.get(HiveService.kDefaultPackageWeight, defaultValue: 23) as int,
        minBidPriceEur: box.get(HiveService.kMinBidPrice, defaultValue: 0) as int,
        contactMode: box.get(HiveService.kContactMode) as String?,
        responseDelayHours: box.get(HiveService.kResponseDelay) as int?,
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
      emit(_dtoToState(dto).copyWith(isSyncing: false));
    } catch (_) {
      emit(state.copyWith(isSyncing: false));
    }
  }

  // ── Handlers existants (+ sync API en arrière-plan) ───────────────────────

  Future<void> _onWeightUnit(WeightUnitChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    await _box.put(HiveService.kWeightUnit, e.unit);
    emit(state.copyWith(weightUnit: e.unit, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onCurrency(CurrencyChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    await _box.put(HiveService.kCurrencyCode, e.code);
    emit(state.copyWith(currencyCode: e.code, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onPickupRadius(PickupRadiusChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    await _box.put(HiveService.kPickupRadiusKm, e.km);
    emit(state.copyWith(pickupRadiusKm: e.km, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onDefaultWeight(DefaultWeightChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    await _box.put(HiveService.kDefaultPackageWeight, e.kg);
    emit(state.copyWith(defaultPackageWeightKg: e.kg, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onMinBidPrice(MinBidPriceChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    await _box.put(HiveService.kMinBidPrice, e.euros);
    emit(state.copyWith(minBidPriceEur: e.euros, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onContactMode(ContactModeChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    if (e.mode == null) {
      await _box.delete(HiveService.kContactMode);
    } else {
      await _box.put(HiveService.kContactMode, e.mode);
    }
    emit(state.copyWith(contactModeGetter: () => e.mode, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  Future<void> _onResponseDelay(ResponseDelayChanged e, Emitter<BusinessPrefsState> emit) async {
    final prev = state;
    if (e.hours == null) {
      await _box.delete(HiveService.kResponseDelay);
    } else {
      await _box.put(HiveService.kResponseDelay, e.hours);
    }
    emit(state.copyWith(responseDelayHoursGetter: () => e.hours, errorMessageGetter: () => null));
    await _putOrRollback(emit, prev);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _putOrRollback(Emitter<BusinessPrefsState> emit, BusinessPrefsState prev) async {
    try {
      await _repo.updatePrefs(_stateToDto(state));
    } catch (_) {
      await _writeToHive(_stateToDto(prev));
      emit(prev.copyWith(errorMessageGetter: () => 'Impossible de synchroniser. Réessayez.'));
    }
  }

  Future<void> _writeToHive(UserBusinessPrefsDto dto) async {
    await _box.put(HiveService.kWeightUnit, dto.weightUnit);
    await _box.put(HiveService.kCurrencyCode, dto.currencyCode);
    await _box.put(HiveService.kPickupRadiusKm, dto.pickupRadiusKm);
    await _box.put(HiveService.kDefaultPackageWeight, dto.defaultPackageWeightKg);
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
  }

  BusinessPrefsState _dtoToState(UserBusinessPrefsDto dto) => BusinessPrefsState(
        weightUnit: dto.weightUnit,
        currencyCode: dto.currencyCode,
        pickupRadiusKm: dto.pickupRadiusKm,
        defaultPackageWeightKg: dto.defaultPackageWeightKg,
        minBidPriceEur: dto.minBidPriceEur,
        contactMode: dto.contactMode,
        responseDelayHours: dto.responseDelayHours,
      );

  UserBusinessPrefsDto _stateToDto(BusinessPrefsState s) => UserBusinessPrefsDto(
        weightUnit: s.weightUnit,
        currencyCode: s.currencyCode,
        pickupRadiusKm: s.pickupRadiusKm,
        defaultPackageWeightKg: s.defaultPackageWeightKg,
        minBidPriceEur: s.minBidPriceEur,
        contactMode: s.contactMode,
        responseDelayHours: s.responseDelayHours,
      );
}
