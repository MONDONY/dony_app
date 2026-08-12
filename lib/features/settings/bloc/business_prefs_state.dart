part of 'business_prefs_bloc.dart';

class BusinessPrefsState extends Equatable {
  final String weightUnit;
  final String currencyCode;
  final int pickupRadiusKm;
  final int defaultPackageWeightKg;
  final int minBidPriceEur;
  final String? contactMode;
  final int? responseDelayHours;
  final bool isSyncing;
  final String? errorMessage;

  const BusinessPrefsState({
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.pickupRadiusKm = 10,
    this.defaultPackageWeightKg = 23,
    this.minBidPriceEur = 0,
    this.contactMode,
    this.responseDelayHours,
    this.isSyncing = false,
    this.errorMessage,
  });

  BusinessPrefsState copyWith({
    String? weightUnit,
    String? currencyCode,
    int? pickupRadiusKm,
    int? defaultPackageWeightKg,
    int? minBidPriceEur,
    String? Function()? contactModeGetter,
    int? Function()? responseDelayHoursGetter,
    bool? isSyncing,
    String? Function()? errorMessageGetter,
  }) => BusinessPrefsState(
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
    defaultPackageWeightKg:
        defaultPackageWeightKg ?? this.defaultPackageWeightKg,
    minBidPriceEur: minBidPriceEur ?? this.minBidPriceEur,
    contactMode: contactModeGetter != null
        ? contactModeGetter()
        : this.contactMode,
    responseDelayHours: responseDelayHoursGetter != null
        ? responseDelayHoursGetter()
        : this.responseDelayHours,
    isSyncing: isSyncing ?? this.isSyncing,
    errorMessage: errorMessageGetter != null
        ? errorMessageGetter()
        : this.errorMessage,
  );

  @override
  List<Object?> get props => [
    weightUnit,
    currencyCode,
    pickupRadiusKm,
    defaultPackageWeightKg,
    minBidPriceEur,
    contactMode,
    responseDelayHours,
    isSyncing,
    errorMessage,
  ];
}
