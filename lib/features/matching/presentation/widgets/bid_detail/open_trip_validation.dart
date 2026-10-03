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
  final trip = bid.announcementId;
  final location = Uri(
    path: '/tracking/validate',
    queryParameters: trip.isEmpty ? null : {'trip': trip},
  ).toString();
  final bloc = _bidBlocOf(context);
  await context.push<void>(location);
  if (bloc != null && !bloc.isClosed) bloc.add(BidDetailRequested(bid.id));
}

BidBloc? _bidBlocOf(BuildContext context) {
  try {
    return context.read<BidBloc>();
  } on ProviderNotFoundException {
    return null;
  }
}
