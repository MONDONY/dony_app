part of 'business_prefs_bloc.dart';

class BusinessPrefsState extends Equatable {
  final String weightUnit;
  final String currencyCode;
  final int pickupRadiusKm;

  const BusinessPrefsState({
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.pickupRadiusKm = 10,
  });

  BusinessPrefsState copyWith({
    String? weightUnit,
    String? currencyCode,
    int? pickupRadiusKm,
  }) =>
      BusinessPrefsState(
        weightUnit: weightUnit ?? this.weightUnit,
        currencyCode: currencyCode ?? this.currencyCode,
        pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
      );

  @override
  List<Object?> get props => [weightUnit, currencyCode, pickupRadiusKm];
}
