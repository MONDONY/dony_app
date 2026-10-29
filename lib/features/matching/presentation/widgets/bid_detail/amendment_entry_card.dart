import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_request_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Entrée de la modification d'un colis accepté, dans le détail d'envoi de
/// l'expéditeur : règle d'affichage et ouverture de la feuille « Modifier mon
/// colis ». Le bouton vit dans le sheet de la tuile Colis et dans le menu
/// d'options.
abstract final class AmendmentEntryCard {
  /// Le serveur décide (éligibilité, drapeau, fenêtre) : l'app ne recalcule rien.
  static bool shouldShow(BidModel bid) => bid.amendmentAllowed;

  /// Ouvre la feuille puis relit le colis (`BidBloc` de l'écran, s'il est là)
  /// quand une demande a été envoyée ou n'est plus possible. Aussi appelée par
  /// l'entrée du menu d'options.
  static Future<void> open(BuildContext context, BidModel bid) async {
    BidBloc? bidBloc;
    try {
      bidBloc = context.read<BidBloc>();
    } on ProviderNotFoundException {
      bidBloc = null;
    }
    final changed = await AmendmentRequestSheet.show(context, bid: bid);
    if (changed) bidBloc?.add(BidDetailRequested(bid.id));
  }
}
