import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:flutter/widgets.dart';

/// Échec du lancement d'un paiement de négociation sur une 409 (FLUTTER-F9).
///
/// Le fil n'attend plus de paiement (offre retirée par le voyageur, délai
/// écoulé) : au lieu d'un message générique laissé sur une feuille de paiement
/// périmée, on ferme la feuille, on explique la situation (catalogue
/// d'erreurs : `thread/not-awaiting-payment`…) et on recharge le fil.
///
/// Renvoie `false` sans rien faire pour toute autre erreur : l'appelant garde
/// alors son traitement habituel.
bool handleNegotiationPaymentConflict({
  required BuildContext sheetContext,
  required BuildContext callerContext,
  required NegotiationBloc bloc,
  required String threadId,
  required Object error,
}) {
  final appErr = unwrapDioError(error);
  if (appErr is! ConflictException) return false;
  if (sheetContext.mounted) {
    Navigator.of(sheetContext, rootNavigator: true).pop();
  }
  bloc.add(NegotiationFetchRequested(threadId));
  if (callerContext.mounted) {
    unawaited(ErrorPresenter.show(callerContext, appErr));
  }
  return true;
}
