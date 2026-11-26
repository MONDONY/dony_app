import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// La vérification d'identité ne peut pas démarrer pour une raison qui n'est
/// pas celle de l'utilisateur : fournisseur injoignable (503
/// `problem.kyc.session-creation-failed`, solde du fournisseur épuisé en
/// novembre), serveur en panne, délai dépassé, hors ligne.
bool isKycServiceUnavailable(AppException error) =>
    error is ServerException ||
    error is OfflineException ||
    error is TimeoutException ||
    error is NetworkException;

/// Texte à montrer pour une erreur de la vérification d'identité.
///
/// Indisponibilité : un message dédié, qui rassure sur la saisie quand elle
/// a été gardée en brouillon ([draftSaved], vérification demandée au clic sur
/// « Publier »). Sinon, le texte du catalogue d'erreurs. Jamais le texte
/// technique de l'exception.
String kycErrorMessage(
  AppLocalizations l10n,
  AppException error, {
  bool draftSaved = false,
}) {
  if (isKycServiceUnavailable(error)) {
    return draftSaved
        ? l10n.kycSessionUnavailableDraftSaved
        : l10n.kycSessionUnavailable;
  }
  return ErrorPresenter.resolve(error, l10n: l10n).message;
}

/// Montre une erreur de la vérification d'identité : indisponibilité en
/// avertissement avec le message dédié, le reste par [ErrorPresenter].
void showKycError(
  BuildContext context,
  AppException error, {
  bool draftSaved = false,
}) {
  if (!isKycServiceUnavailable(error)) {
    unawaited(ErrorPresenter.show(context, error));
    return;
  }
  DonySnackbar.show(
    context,
    message: kycErrorMessage(context.l10n, error, draftSaved: draftSaved),
    type: DonySnackbarType.warning,
  );
}
