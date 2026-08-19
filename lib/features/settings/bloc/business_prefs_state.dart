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

  /// Lot 2 : gel de la devise au premier mouvement d'argent. Renseigné par le
  /// serveur à chaque synchro (`GET`/`PUT`), jamais dérivé localement — seul
  /// le backend voit le portefeuille et les envois engagés.
  final bool currencyLocked;

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
    this.currencyLocked = false,
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
    bool? currencyLocked,
  }) => BusinessPrefsState(
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
    defaultPackageWeightKg:
        defaultPackageWeightKg ?? this.defaultPackageWeightKg,
    minBidPriceEur: minBidPriceEur ?? this.minBidPriceEur,
    contactMode: contactModeGetter != null ? contactModeGetter() : contactMode,
    responseDelayHours: responseDelayHoursGetter != null
        ? responseDelayHoursGetter()
        : responseDelayHours,
    isSyncing: isSyncing ?? this.isSyncing,
    errorMessage: errorMessageGetter != null
        ? errorMessageGetter()
        : errorMessage,
    currencyLocked: currencyLocked ?? this.currencyLocked,
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
    currencyLocked,
  ];
}
