import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Construit le bouton qui appelle la contrepartie : [onPressed] est `null`
/// pendant la demande du numéro, [isLoading] permet d'afficher un indicateur.
typedef CounterpartCallButtonBuilder =
    Widget Function(
      BuildContext context,
      VoidCallback? onPressed,
      bool isLoading,
    );

/// Appelle la contrepartie du colis [bidId] : demande le numéro au serveur au
/// moment du geste (`GET /bids/{id}/contact`, qui vérifie la fenêtre de
/// contact et journalise la révélation), puis ouvre le composeur
/// ([dialPhoneNumber]). Aucune donnée nouvelle : c'est le même chemin que
/// l'appel depuis la conversation et la fiche de l'expéditeur.
///
/// L'appelant ne le pose que si la contrepartie est joignable
/// (`travelerPhoneAvailable` / `senderPhoneAvailable` du colis, calculés par
/// le back sur `BidStatus.PHONE_VISIBLE_STATUSES` et le réglage « Masquer mon
/// numéro ») : sans numéro, pas de bouton.
///
/// Porte son propre [ContactRevealBloc] (comme `RecipientConversationLauncher`
/// pour la conversation) : l'écran hôte n'a rien à fournir.
class CounterpartCallLauncher extends StatelessWidget {
  const CounterpartCallLauncher({
    super.key,
    required this.bidId,
    required this.source,
    required this.builder,
    this.status,
  });

  final String bidId;

  /// Surface mesurée par `parcel_call_tapped` (`sender_footer`,
  /// `scan_confirm`).
  final String source;

  /// Statut du colis, propriété `status` de la mesure quand il est connu.
  final String? status;
  final CounterpartCallButtonBuilder builder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ContactRevealBloc>(),
      child: BlocConsumer<ContactRevealBloc, ContactRevealState>(
        listener: (context, state) {
          if (state is ContactRevealSuccess) {
            unawaited(dialPhoneNumber(context, state.phoneNumber));
          } else if (state is ContactRevealError) {
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) {
          final isLoading = state is ContactRevealLoading;
          return builder(
            context,
            isLoading ? null : () => _call(context),
            isLoading,
          );
        },
      ),
    );
  }

  void _call(BuildContext context) {
    unawaited(
      getItSafe<AnalyticsService>()?.logEvent(
        AnalyticsEvents.parcelCallTapped,
        properties: {'source': source, 'status': ?status},
      ),
    );
    context.read<ContactRevealBloc>().add(ContactRevealRequested(bidId));
  }
}
