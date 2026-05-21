part of 'business_prefs_bloc.dart';

abstract class BusinessPrefsEvent extends Equatable {
  const BusinessPrefsEvent();
  @override
  List<Object?> get props => [];
}

class WeightUnitChanged extends BusinessPrefsEvent {
  final String unit; // 'kg' | 'lbs'
  const WeightUnitChanged(this.unit);
  @override
  List<Object?> get props => [unit];
}

class CurrencyChanged extends BusinessPrefsEvent {
  final String code; // 'EUR' | 'XOF' | 'XAF'
  const CurrencyChanged(this.code);
  @override
  List<Object?> get props => [code];
}

class PickupRadiusChanged extends BusinessPrefsEvent {
  final int km;
  const PickupRadiusChanged(this.km);
  @override
  List<Object?> get props => [km];
}
