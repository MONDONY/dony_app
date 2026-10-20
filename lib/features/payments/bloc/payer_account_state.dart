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

  /// Numéro reconnu sur un autre opérateur que celui que l'utilisateur a
  /// ensuite choisi lui-même : son choix est respecté, sans nouvel appel.
  overridden,

  /// Le numéro appartient à un opérateur du pays que ce paiement n'accepte
  /// pas (`rejectedOperator`) : aucune bascule, le choix de l'utilisateur est
  /// gardé et le paiement bloqué. Choisir ensuite un opérateur permis donne
  /// [overridden].
  notAllowed,

  /// Reconnaissance impossible (coupure réseau, erreur serveur) : le numéro
  /// n'est pas en cause, `retryRecognition` relance l'appel.
  failed,
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
    this.allowedOperators,
    this.rejectedOperator,
    this.currency,
    this.fixed = false,
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

  /// Codes d'opérateurs acceptés pour ce paiement ; `null` = tous.
  final Set<String>? allowedOperators;

  /// Opérateur détecté sur le numéro mais non permis ([RecognitionStatus
  /// .notAllowed]) ; `null` dans tout autre état.
  final MobileMoneyOperator? rejectedOperator;

  /// Devise imposée au catalogue (`configure`) ; `null` = aucune.
  final String? currency;

  /// Pays et opérateur imposés (changement de numéro d'un compte) : seul le
  /// numéro se saisit.
  final bool fixed;

  /// L'opérateur [o] est-il accepté ici ? En mode [fixed], seul l'opérateur
  /// imposé l'est, quelle que soit la restriction.
  bool isAllowed(MobileMoneyOperator o) {
    if (fixed) return o.code == operator?.code;
    return allowedOperators == null || allowedOperators!.contains(o.code);
  }

  bool get canProceed =>
      recognition == RecognitionStatus.recognized ||
      recognition == RecognitionStatus.autoSwitched ||
      recognition == RecognitionStatus.overridden;

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
    Object? allowedOperators = _unset,
    Object? rejectedOperator = _unset,
    Object? currency = _unset,
    bool? fixed,
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
    allowedOperators: identical(allowedOperators, _unset)
        ? this.allowedOperators
        : allowedOperators as Set<String>?,
    // L'opérateur refusé n'a de sens que dans l'état `notAllowed` : tout autre
    // état de reconnaissance l'efface, sauf mention contraire.
    rejectedOperator: identical(rejectedOperator, _unset)
        ? (recognition != null && recognition != RecognitionStatus.notAllowed
              ? null
              : this.rejectedOperator)
        : rejectedOperator as MobileMoneyOperator?,
    currency: identical(currency, _unset) ? this.currency : currency as String?,
    fixed: fixed ?? this.fixed,
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
    allowedOperators,
    rejectedOperator,
    currency,
    fixed,
  ];
}
