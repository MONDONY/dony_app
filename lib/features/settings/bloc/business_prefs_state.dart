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

  /// Code ISO 3166-1 alpha-2, ou `null` tant que l'utilisateur ne l'a pas
  /// renseigné. La devise ([currencyCode]) est désormais dérivée de ce champ
  /// côté serveur — jamais recalculée ici.
  final String? country;

  /// Même mécanisme que [currencyLocked] (lot pays-onboarding-devise-dérivée) :
  /// renseigné par le serveur, jamais dérivé localement.
  final bool countryLocked;

  /// Devise d'affichage (presentment, lot 8) : `'AUTO'` = suivre la devise
  /// active, sinon une des 7 devises. Jamais verrouillée : préférence purement
  /// visuelle, les montants transactionnels restent dans leur devise d'origine.
  final String displayCurrencyCode;

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
    this.country,
    this.countryLocked = false,
    this.displayCurrencyCode = 'AUTO',
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
    String? Function()? countryGetter,
    bool? countryLocked,
    String? displayCurrencyCode,
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
    country: countryGetter != null ? countryGetter() : country,
    countryLocked: countryLocked ?? this.countryLocked,
    displayCurrencyCode: displayCurrencyCode ?? this.displayCurrencyCode,
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
    country,
    countryLocked,
    displayCurrencyCode,
  ];
}
