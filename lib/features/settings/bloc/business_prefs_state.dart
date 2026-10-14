part of 'business_prefs_bloc.dart';

class BusinessPrefsState extends Equatable {
  final String weightUnit;
  final String currencyCode;
  final int defaultPackageWeightKg;
  final int minBidPriceEur;
  final String? contactMode;
  final int? responseDelayHours;
  final bool isSyncing;

  /// La dernière synchro serveur a échoué et le champ a été remis à sa
  /// valeur précédente. L'écran choisit lui-même le texte (`settingsSyncFailed`) :
  /// aucun message n'est gardé ici.
  final bool hasSyncError;

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

  /// Renseigné par le serveur (yadony-back #530) : changer de pays annulerait
  /// une activation des paiements par carte commencée mais pas terminée.
  /// L'écran demande confirmation avant d'envoyer [CountryChanged].
  final bool countryChangeResetsPayoutSetup;

  /// Raison du dernier refus d'enregistrer le pays (`country-locked`, hors
  /// ligne…), affichée par l'écran via `ErrorPresenter` au lieu d'un retour
  /// silencieux à l'ancien pays. Détail de [hasSyncError] : remettre
  /// [hasSyncError] à `false` dans [copyWith] l'efface aussi.
  final AppException? countryChangeError;

  /// Nombre de changements de pays enregistrés par le serveur depuis le
  /// démarrage. L'écran l'écoute pour redemander le statut Connect, qui
  /// dépend du pays côté serveur.
  final int countrySavedCount;

  /// Devise d'affichage (presentment, lot 8) : `'AUTO'` = suivre la devise
  /// active, sinon une des 7 devises. Jamais verrouillée : préférence purement
  /// visuelle, les montants transactionnels restent dans leur devise d'origine.
  final String displayCurrencyCode;

  const BusinessPrefsState({
    this.weightUnit = 'kg',
    this.currencyCode = 'EUR',
    this.defaultPackageWeightKg = 23,
    this.minBidPriceEur = 0,
    this.contactMode,
    this.responseDelayHours,
    this.isSyncing = false,
    this.hasSyncError = false,
    this.currencyLocked = false,
    this.country,
    this.countryLocked = false,
    this.countryChangeResetsPayoutSetup = false,
    this.countryChangeError,
    this.countrySavedCount = 0,
    this.displayCurrencyCode = 'AUTO',
  });

  BusinessPrefsState copyWith({
    String? weightUnit,
    String? currencyCode,
    int? defaultPackageWeightKg,
    int? minBidPriceEur,
    String? Function()? contactModeGetter,
    int? Function()? responseDelayHoursGetter,
    bool? isSyncing,
    bool? hasSyncError,
    bool? currencyLocked,
    String? Function()? countryGetter,
    bool? countryLocked,
    bool? countryChangeResetsPayoutSetup,
    AppException? countryChangeError,
    int? countrySavedCount,
    String? displayCurrencyCode,
  }) => BusinessPrefsState(
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    defaultPackageWeightKg:
        defaultPackageWeightKg ?? this.defaultPackageWeightKg,
    minBidPriceEur: minBidPriceEur ?? this.minBidPriceEur,
    contactMode: contactModeGetter != null ? contactModeGetter() : contactMode,
    responseDelayHours: responseDelayHoursGetter != null
        ? responseDelayHoursGetter()
        : responseDelayHours,
    isSyncing: isSyncing ?? this.isSyncing,
    hasSyncError: hasSyncError ?? this.hasSyncError,
    currencyLocked: currencyLocked ?? this.currencyLocked,
    country: countryGetter != null ? countryGetter() : country,
    countryLocked: countryLocked ?? this.countryLocked,
    countryChangeResetsPayoutSetup:
        countryChangeResetsPayoutSetup ?? this.countryChangeResetsPayoutSetup,
    countryChangeError:
        countryChangeError ??
        (hasSyncError == false ? null : this.countryChangeError),
    countrySavedCount: countrySavedCount ?? this.countrySavedCount,
    displayCurrencyCode: displayCurrencyCode ?? this.displayCurrencyCode,
  );

  @override
  List<Object?> get props => [
    weightUnit,
    currencyCode,
    defaultPackageWeightKg,
    minBidPriceEur,
    contactMode,
    responseDelayHours,
    isSyncing,
    hasSyncError,
    currencyLocked,
    country,
    countryLocked,
    countryChangeResetsPayoutSetup,
    countryChangeError,
    countrySavedCount,
    displayCurrencyCode,
  ];
}
