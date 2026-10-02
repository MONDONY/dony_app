import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Compteurs de la ligne « Discussions de prix » de Messages, sur les deux
/// sources de l'écran `/negotiations` : fils sur une demande d'envoi et fils
/// sur le prix d'un trajet.
///
/// [open] : négociations encore ouvertes (la ligne n'apparaît qu'à partir
/// de 1). [awaitingMe] : celles où c'est à l'utilisateur de jouer, répondre
/// à une offre ou payer un accord carte — elles allument la pastille.
({int open, int awaitingMe}) negotiationsShortcutCounts(
  NegotiationListState requests,
  BidNegotiationListState trips,
) {
  final openTrips = trips.summaries.where((s) => !s.isClosed);
  return (
    open: requests.activeCount + openTrips.length,
    awaitingMe:
        requests.actionableCount +
        openTrips.where((s) => s.myTurn || s.needsMyPayment).length,
  );
}

/// Ligne épinglée « Discussions de prix » en tête de Messages (FLUTTER-44).
///
/// Les négociations vivent dans Activités › Discussions de prix ; des
/// testeurs les cherchaient dans Messages et concluaient qu'on ne les
/// retrouvait que par la notification. Cette ligne est un raccourci vers le
/// même écran, pas une fusion : les fils ne deviennent pas des conversations.
///
/// Lit les deux BLoC globaux de `/negotiations` dans GetIt et ne rend rien
/// s'ils ne sont pas enregistrés (tests de l'écran Messages) ou si aucune
/// négociation n'est ouverte.
class NegotiationsShortcutSection extends StatefulWidget {
  const NegotiationsShortcutSection({super.key});

  @override
  State<NegotiationsShortcutSection> createState() =>
      _NegotiationsShortcutSectionState();
}

class _NegotiationsShortcutSectionState
    extends State<NegotiationsShortcutSection> {
  bool get _available =>
      getIt.isRegistered<NegotiationListBloc>() &&
      getIt.isRegistered<BidNegotiationListBloc>();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Refresh silencieux : la ligne garde ses compteurs pendant l'appel au
  /// lieu de disparaître le temps du chargement.
  void _refresh() {
    if (!_available) return;
    getIt<NegotiationListBloc>().add(const NegotiationListRefreshRequested());
    getIt<BidNegotiationListBloc>().add(
      const BidNegotiationListRefreshRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    return BlocBuilder<NegotiationListBloc, NegotiationListState>(
      bloc: getIt<NegotiationListBloc>(),
      builder: (context, requests) =>
          BlocBuilder<BidNegotiationListBloc, BidNegotiationListState>(
            bloc: getIt<BidNegotiationListBloc>(),
            builder: (context, trips) {
              final counts = negotiationsShortcutCounts(requests, trips);
              if (counts.open == 0) return const SizedBox.shrink();
              return NegotiationsShortcutTile(
                openCount: counts.open,
                awaitingMeCount: counts.awaitingMe,
                onTap: () async {
                  unawaited(
                    getIt<AnalyticsService>().logEvent(
                      AnalyticsEvents.messagesNegotiationsShortcutOpened,
                      properties: {
                        'open_count': counts.open,
                        'awaiting_me_count': counts.awaitingMe,
                      },
                    ),
                  );
                  await context.push('/negotiations');
                  if (mounted) _refresh();
                },
              );
            },
          ),
    );
  }
}

/// Rendu de la ligne, sans état : mêmes dimensions et même grammaire que
/// `SupportConversationTile`, juste au-dessus.
class NegotiationsShortcutTile extends StatelessWidget {
  const NegotiationsShortcutTile({
    super.key,
    required this.openCount,
    required this.awaitingMeCount,
    required this.onTap,
  });

  final int openCount;
  final int awaitingMeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final awaiting = awaitingMeCount > 0;
    final subtitle = awaiting
        ? l.messagesNegotiationsShortcutAwaiting(awaitingMeCount)
        : l.messagesNegotiationsShortcutOpen(openCount);

    return Semantics(
      button: true,
      label: '${l.negotiationListTitle}, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: awaiting
            ? Color.alphaBlend(cs.primary.withValues(alpha: 0.06), cs.surface)
            : cs.surface,
        child: InkWell(
          key: const Key('messages-negotiations-shortcut'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                  ),
                  child: Center(
                    child: DonyIcon(
                      'arrow-left-right',
                      size: 22,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.negotiationListTitle,
                        style: tt.titleLarge?.copyWith(
                          fontWeight: awaiting
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: awaiting ? cs.onSurface : cs.onSurfaceVariant,
                          fontWeight: awaiting
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                if (awaiting)
                  _CountBadge(count: awaitingMeCount)
                else
                  DonyIcon(
                    'chevron-right',
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: const Key('messages-negotiations-shortcut-badge'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
