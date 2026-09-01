import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_bloc.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_event.dart';
import 'package:dony/features/subscriptions/bloc/subscriptions_state.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:dony/features/subscriptions/presentation/widgets/subscription_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

/// Au-delà de ce nombre d'abonnements, la recherche apparaît. En deçà, elle
/// coûterait plus de place qu'elle n'en fait gagner : la liste tient à l'écran.
const int kSubscriptionsSearchThreshold = 6;

class MesAbonnementsScreen extends StatefulWidget {
  const MesAbonnementsScreen({super.key});
  @override
  State<MesAbonnementsScreen> createState() => _MesAbonnementsScreenState();
}

class _MesAbonnementsScreenState extends State<MesAbonnementsScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsBloc>().add(const LoadSubscriptions());
  }

  /// Les voyageurs qui viennent de publier remontent, puis les plus récents.
  /// Un abonné sans trajet ouvert ferme la liste : il n'y a rien à en attendre.
  List<SubscriptionItem> _sorted(List<SubscriptionItem> items) {
    final sorted = [...items];
    sorted.sort((a, b) {
      if (a.hasNew != b.hasNew) return a.hasNew ? -1 : 1;
      final da = a.lastAnnouncement?.publishedAt;
      final db = b.lastAnnouncement?.publishedAt;
      if (da == null && db == null) {
        return a.travelerName.toLowerCase().compareTo(
          b.travelerName.toLowerCase(),
        );
      }
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return sorted;
  }

  Future<void> _confirmUnsubscribe(
    BuildContext context,
    SubscriptionItem item,
  ) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Ne plus suivre ${item.travelerName} ?',
      message:
          'Vous ne serez plus prévenu de ses nouveaux trajets. '
          'Vous pourrez vous réabonner depuis son profil.',
      confirmLabel: 'Se désabonner',
      variant: DonyDialogVariant.destructive,
      iconAsset: 'bell-off',
    );
    if ((confirmed ?? false) && context.mounted) {
      context.read<SubscriptionsBloc>().add(
        UnsubscribeTraveler(item.travelerId),
      );
    }
  }

  void _togglePush(BuildContext context, SubscriptionItem item) {
    final enabling = !item.pushEnabled;
    context.read<SubscriptionsBloc>().add(
      ToggleSubscriptionPush(item.travelerId, enabling),
    );
    DonySnackbar.show(
      context,
      message: enabling
          ? 'Alertes push activées pour ${item.travelerName}.'
          : 'Alertes push coupées. Ses nouveaux trajets resteront visibles '
                'dans vos notifications.',
      type: enabling ? DonySnackbarType.success : DonySnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: const Text('Mes abonnements'),
        actions: [
          BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
            buildWhen: (a, b) =>
                a.items.any((i) => i.hasNew) != b.items.any((i) => i.hasNew),
            builder: (context, state) {
              if (!state.items.any((i) => i.hasNew)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Tout marquer comme vu',
                icon: const DonyIcon('check-check'),
                onPressed: () => context.read<SubscriptionsBloc>().add(
                  const MarkAllSubscriptionsSeen(),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
        builder: (context, state) {
          if (state.status == SubscriptionsStatus.loading &&
              state.items.isEmpty) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.md,
                DonySpacing.base,
                DonySpacing.huge,
              ),
              itemCount: 5,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DonySpacing.sm),
              itemBuilder: (_, _) => const DonyUserCardSkeleton(),
            );
          }
          if (state.status == SubscriptionsStatus.error &&
              state.items.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.erreurLegere,
              type: DonyEmptyStateType.error,
              iconAsset: 'circle-alert',
              title: 'Erreur de chargement',
              description: state.error ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () => context.read<SubscriptionsBloc>().add(
                const LoadSubscriptions(),
              ),
            );
          }
          if (state.items.isEmpty) {
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucun abonnement',
              description:
                  'Abonnez-vous à un voyageur depuis son profil : vous serez '
                  'prévenu dès qu\'il publie un trajet.',
            );
          }

          final all = _sorted(state.items);
          final q = _query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all
                    .where((i) => i.travelerName.toLowerCase().contains(q))
                    .toList();
          final newCount = all.where((i) => i.hasNew).length;
          final showSearch = all.length >= kSubscriptionsSearchThreshold;

          return RefreshIndicator(
            onRefresh: () async => context.read<SubscriptionsBloc>().add(
              const LoadSubscriptions(),
            ),
            child: Column(
              children: [
                if (showSearch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      DonySpacing.md,
                      DonySpacing.base,
                      DonySpacing.xs,
                    ),
                    child: DonySearchField(
                      hint: 'Rechercher un voyageur…',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                _CountLine(total: all.length, newCount: newCount),
                Expanded(
                  child: filtered.isEmpty
                      ? const _NoMatch()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            DonySpacing.base,
                            DonySpacing.xs,
                            DonySpacing.base,
                            DonySpacing.huge,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: DonySpacing.sm),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _slidable(context, item)
                                .animate()
                                .fadeIn(
                                  duration: 220.ms,
                                  // Cadence décalée, plafonnée : au-delà de six
                                  // cartes l'attente se verrait plus que
                                  // l'animation.
                                  delay: (30 * (index.clamp(0, 6))).ms,
                                )
                                .slideY(
                                  begin: 0.06,
                                  curve: Curves.easeOutCubic,
                                );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _slidable(BuildContext context, SubscriptionItem item) {
    return Slidable(
      key: ValueKey(item.travelerId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          CustomSlidableAction(
            // Le balayage n'agit plus directement : se désabonner est
            // irréversible côté indicateur « nouveau », et rien ne permettait
            // de revenir en arrière.
            onPressed: (_) => _confirmUnsubscribe(context, item),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const DonyIcon('bell-off', color: Colors.white),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Désabonner',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      child: SubscriptionTile(
        item: item,
        onTap: () => context.push('/travelers/${item.travelerId}'),
        onToggleBell: () => _togglePush(context, item),
        onOpenLastTrip: item.lastAnnouncement == null
            ? null
            : () {
                unawaited(
                  getIt<AnalyticsService>().logEvent(
                    AnalyticsEvents.subscriptionLastTripOpened,
                  ),
                );
                context.push(
                  '/traveler/${item.lastAnnouncement!.announcementId}',
                );
              },
      ),
    );
  }
}

/// Récapitulatif d'une ligne, qui remplace l'ancien intitulé de section :
/// il dit combien de voyageurs sont suivis et combien ont publié, sans
/// découper la liste en deux blocs.
class _CountLine extends StatelessWidget {
  const _CountLine({required this.total, required this.newCount});

  final int total;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final suivis = total == 1 ? '1 voyageur suivi' : '$total voyageurs suivis';
    final nouveaux = newCount == 0
        ? null
        : (newCount == 1
              ? '1 a publié depuis votre dernière visite'
              : '$newCount ont publié depuis votre dernière visite');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            suivis,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (nouveaux != null) ...[
            Text(
              ' · ',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Flexible(
              child: Text(
                nouveaux,
                style: tt.labelMedium?.copyWith(
                  color: DonyColors.accent,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Text(
          'Aucun voyageur ne correspond à cette recherche.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
