import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Ouvre le mode « Valider une étape » sur le trajet de [bid], par-dessus
/// son détail (FLUTTER-9N) : le retour ramène au colis, rechargé puisque
/// son statut a pu avancer pendant le scan.
Future<void> openTripValidation(BuildContext context, BidModel bid) async {
  final bloc = _bidBlocOf(context);
  await pushTripValidation(context, bid.announcementId);
  if (bloc != null && !bloc.isClosed) bloc.add(BidDetailRequested(bid.id));
}

/// Pousse Suivi › Valider sur le trajet [tripId] (`/tracking/validate`),
/// par-dessus l'écran courant : le retour y ramène. Un [tripId] vide laisse
/// le Suivi choisir le trajet.
Future<void> pushTripValidation(BuildContext context, String tripId) {
  final location = Uri(
    path: '/tracking/validate',
    queryParameters: tripId.isEmpty ? null : {'trip': tripId},
  ).toString();
  return context.push<void>(location);
}

BidBloc? _bidBlocOf(BuildContext context) {
  try {
    return context.read<BidBloc>();
  } on ProviderNotFoundException {
    return null;
  }
}
