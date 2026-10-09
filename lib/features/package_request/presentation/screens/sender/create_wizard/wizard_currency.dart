import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';

/// Devise EFFECTIVE d'une demande en cours de saisie, seule source de vérité
/// de l'assistant : celle choisie dans le formulaire ([PackageRequestFormState.currency],
/// celle qui part au backend), puis [fallback] (devise active figée par
/// l'écran), puis la devise active en cache, puis l'euro.
///
/// Partagée par l'étape 3 et la feuille d'aperçu : l'aperçu lisait la devise
/// d'affichage du compte et montrait « $6,500.00 » pour une demande saisie en
/// F CFA (FLUTTER-HB).
SupportedCurrency resolveWizardCurrency(
  PackageRequestFormState state, {
  SupportedCurrency? fallback,
}) =>
    state.currency ??
    fallback ??
    ActiveCurrency.current ??
    SupportedCurrency.eur;
