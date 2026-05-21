import 'package:dony/core/storage/hive_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'business_prefs_event.dart';
part 'business_prefs_state.dart';

class BusinessPrefsBloc extends Bloc<BusinessPrefsEvent, BusinessPrefsState> {
  final Box _box;

  BusinessPrefsBloc(this._box)
      : super(BusinessPrefsState(
          weightUnit:
              _box.get(HiveService.kWeightUnit, defaultValue: 'kg') as String,
          currencyCode:
              _box.get(HiveService.kCurrencyCode, defaultValue: 'EUR') as String,
          pickupRadiusKm:
              _box.get(HiveService.kPickupRadiusKm, defaultValue: 10) as int,
        )) {
    on<WeightUnitChanged>((e, emit) {
      _box.put(HiveService.kWeightUnit, e.unit);
      emit(state.copyWith(weightUnit: e.unit));
    });
    on<CurrencyChanged>((e, emit) {
      _box.put(HiveService.kCurrencyCode, e.code);
      emit(state.copyWith(currencyCode: e.code));
    });
    on<PickupRadiusChanged>((e, emit) {
      _box.put(HiveService.kPickupRadiusKm, e.km);
      emit(state.copyWith(pickupRadiusKm: e.km));
    });
  }
}
