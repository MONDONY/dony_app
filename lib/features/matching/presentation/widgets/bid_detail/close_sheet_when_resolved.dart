import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ferme le sheet de [context] s'il est au premier plan : une confirmation ou
/// une erreur ouverte par-dessus n'est jamais refermée à sa place.
///
/// Rend `true` si le sheet a été fermé par cet appel : un bouton du pied qui
/// enchaîne une action après la fermeture s'arrête sur `false` (second appui
/// pendant l'animation de sortie, sheet déjà quitté).
bool closeSheetIfOnTop(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return false;
  Navigator.of(context).pop();
  return true;
}

/// Ferme le sheet d'une tuile « À traiter » dès que le colis courant (dernier
/// [BidDetailLoaded] du `BidBloc` de l'écran pour [bidId]) ne justifie plus
/// la tuile ([stillNeeded] faux) et que le sheet est au premier plan.
///
/// Reconstruit à chaque colis relu et à chaque retour du sheet au premier
/// plan (`ModalRoute.isCurrentOf`) : un rechargement arrivé pendant qu'une
/// confirmation ou une erreur couvrait le sheet le referme dès qu'elle se
/// ferme, sans jamais la refermer à sa place. Requiert un `BidBloc` ambiant.
class CloseSheetWhenResolved extends StatelessWidget {
  const CloseSheetWhenResolved({
    super.key,
    required this.bidId,
    required this.stillNeeded,
    required this.child,
  });

  final String bidId;
  final bool Function(BidModel bid) stillNeeded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTop = ModalRoute.isCurrentOf(context) ?? false;
    final state = context.watch<BidBloc>().state;
    if (onTop &&
        state is BidDetailLoaded &&
        state.bid.id == bidId &&
        !stillNeeded(state.bid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) closeSheetIfOnTop(context);
      });
    }
    return child;
  }
}
