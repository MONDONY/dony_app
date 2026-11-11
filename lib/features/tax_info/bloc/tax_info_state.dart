import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:equatable/equatable.dart';

/// Bornes alignées sur le back (`TaxInfoRequest`, 4 à 40 caractères : lettres,
/// chiffres, espace, point, tiret, barre oblique). Le serveur reste juge : ces
/// contrôles évitent seulement un aller-retour pour une faute évidente.
const int kTaxNumberMinLength = 4;
const int kTaxNumberMaxLength = 40;
const int kVatNumberMaxLength = 40;
final RegExp kTaxNumberPattern = RegExp(r'^[\p{L}\p{N} ./-]+$', unicode: true);

/// Code d'erreur du back pour un numéro refusé (422).
const String kTaxInfoInvalidCode = 'tax-info-invalid';

/// Chargement de l'écran.
///
/// [unavailable] : rien à demander ou fonction absente (404, 403, 401, ancien
/// back, ou voyageur non concerné) ; [failure] : réseau ou erreur serveur.
enum TaxInfoLoadStatus { loading, ready, unavailable, failure }

/// État de l'écran « Informations fiscales ».
///
/// Les valeurs saisies ([taxNumber], [vatNumber]) ne servent qu'au formulaire :
/// elles sont vidées dès l'enregistrement, l'écran n'affiche ensuite que les
/// formes masquées de la réponse. Elles ne sortent jamais vers l'analytique ni
/// les journaux.
class TaxInfoState extends Equatable {
  const TaxInfoState({
    this.load = TaxInfoLoadStatus.loading,
    this.info,
    this.editing = false,
    this.taxNumber = '',
    this.taxCountry,
    this.vatNumber = '',
    this.submitting = false,
    this.saved = false,
    this.errorCode,
  });

  final TaxInfoLoadStatus load;
  final TaxInfo? info;

  /// Le voyageur a déjà fourni ses informations et touche « Modifier ».
  final bool editing;
  final String taxNumber;

  /// Pays d'émission du numéro (ISO 3166-1 alpha-2).
  final String? taxCountry;
  final String vatNumber;
  final bool submitting;

  /// Enregistrement réussi : l'écran le dit puis se ferme.
  final bool saved;

  /// Dernière erreur d'envoi : `tax-info-invalid`, `network`, `unknown`.
  final String? errorCode;

  /// L'écran montre la fiche (forme masquée) plutôt que le formulaire.
  bool get showsSummary => (info?.provided ?? false) && !editing;

  bool get isTaxNumberValid {
    final number = taxNumber.trim();
    return number.length >= kTaxNumberMinLength &&
        number.length <= kTaxNumberMaxLength &&
        kTaxNumberPattern.hasMatch(number);
  }

  /// Non vide et invalide : l'erreur s'affiche dès la saisie (champ vide, aide
  /// neutre).
  bool get isTaxNumberInvalid =>
      taxNumber.trim().isNotEmpty && !isTaxNumberValid;

  bool get canSubmit =>
      load == TaxInfoLoadStatus.ready &&
      !submitting &&
      isTaxNumberValid &&
      taxCountry != null;

  TaxInfoState copyWith({
    TaxInfoLoadStatus? load,
    TaxInfo? info,
    bool? editing,
    String? taxNumber,
    String? taxCountry,
    String? vatNumber,
    bool? submitting,
    bool? saved,
    String? errorCode,
    bool clearError = false,
  }) => TaxInfoState(
    load: load ?? this.load,
    info: info ?? this.info,
    editing: editing ?? this.editing,
    taxNumber: taxNumber ?? this.taxNumber,
    taxCountry: taxCountry ?? this.taxCountry,
    vatNumber: vatNumber ?? this.vatNumber,
    submitting: submitting ?? this.submitting,
    saved: saved ?? this.saved,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );

  @override
  List<Object?> get props => [
    load,
    info,
    editing,
    taxNumber,
    taxCountry,
    vatNumber,
    submitting,
    saved,
    errorCode,
  ];
}

/// État de la ligne ou de la bannière du Profil.
class TaxInfoPromptState extends Equatable {
  const TaxInfoPromptState({this.info, this.dismissed = false});

  /// `null` tant que rien n'a été lu, ou quand la fonction est absente.
  final TaxInfo? info;

  /// « Plus tard » touché pendant cette session.
  final bool dismissed;

  /// Bannière : seulement pour un voyageur concerné, sauf « Plus tard ».
  bool get showBanner =>
      !dismissed && info?.solicitation == TaxInfoSolicitation.solliciter;

  /// Ligne discrète « Informations fiscales » : informations déjà fournies,
  /// qu'on peut relire (forme masquée) et modifier.
  bool get showRow => info?.solicitation == TaxInfoSolicitation.dejaFourni;

  @override
  List<Object?> get props => [info, dismissed];
}
