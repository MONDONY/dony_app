import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:equatable/equatable.dart';

/// Chargement du catalogue des pays.
enum PayerAccountStatus {
  loading,

  /// Back ancien sans catalogue : l'appelant se rabat sur l'écran d'avant.
  legacy,

  ready,
  error,
}

/// Reconnaissance du numéro saisi par pawaPay.
enum RecognitionStatus {
  /// Numéro incomplet ou pas encore soumis.
  idle,
  checking,

  /// Numéro valide, sur l'opérateur choisi.
  recognized,

  /// Numéro valide, mais sur un autre opérateur : on a basculé dessus.
  autoSwitched,

  /// Numéro refusé ou inconnu des opérateurs du pays.
  unrecognized,
}

const Object _unset = Object();

/// État du composant « compte qui paie » (pays, opérateur, numéro).
class PayerAccountState extends Equatable {
  const PayerAccountState({
    this.status = PayerAccountStatus.loading,
    this.countries,
    this.country,
    this.unavailableCountry,
    this.operator,
    this.localNumber = '',
    this.e164,
    this.recognition = RecognitionStatus.idle,
    this.switchedFrom,
  });

  final PayerAccountStatus status;
  final MobileMoneyCountries? countries;

  /// Pays servi choisi.
  final MobileMoneyCountry? country;

  /// Pays « Bientôt » choisi (code ISO) : aucun opérateur à proposer.
  final String? unavailableCountry;

  final MobileMoneyOperator? operator;

  /// Saisie de l'utilisateur, sans séparateur.
  final String localNumber;

  /// Numéro complet au format E.164 envoyé au back.
  final String? e164;

  final RecognitionStatus recognition;

  /// Code de l'opérateur quitté lors d'un basculement automatique.
  final String? switchedFrom;

  bool get canProceed =>
      recognition == RecognitionStatus.recognized ||
      recognition == RecognitionStatus.autoSwitched;

  PayerAccountState copyWith({
    PayerAccountStatus? status,
    Object? countries = _unset,
    Object? country = _unset,
    Object? unavailableCountry = _unset,
    Object? operator = _unset,
    String? localNumber,
    Object? e164 = _unset,
    RecognitionStatus? recognition,
    Object? switchedFrom = _unset,
  }) => PayerAccountState(
    status: status ?? this.status,
    countries: identical(countries, _unset)
        ? this.countries
        : countries as MobileMoneyCountries?,
    country: identical(country, _unset)
        ? this.country
        : country as MobileMoneyCountry?,
    unavailableCountry: identical(unavailableCountry, _unset)
        ? this.unavailableCountry
        : unavailableCountry as String?,
    operator: identical(operator, _unset)
        ? this.operator
        : operator as MobileMoneyOperator?,
    localNumber: localNumber ?? this.localNumber,
    e164: identical(e164, _unset) ? this.e164 : e164 as String?,
    recognition: recognition ?? this.recognition,
    switchedFrom: identical(switchedFrom, _unset)
        ? this.switchedFrom
        : switchedFrom as String?,
  );

  @override
  List<Object?> get props => [
    status,
    countries,
    country,
    unavailableCountry,
    operator,
    localNumber,
    e164,
    recognition,
    switchedFrom,
  ];
}
