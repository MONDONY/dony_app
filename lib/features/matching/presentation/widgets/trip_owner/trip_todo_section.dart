import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_detail_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/close_sheet_when_resolved.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_actions.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_labels.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_todo_live.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lignes de la file sous la grosse carte ; au-delà, « + N autres à
/// traiter » ouvre toute la liste ([openTripTodoListSheet]).
const kTripTodoQueueRows = 3;

/// Geste d'une action « À traiter » ([item]) depuis [source].
typedef TripTodoActCallback =
    void Function(TripTodoItem item, TripTodoSource source);

/// Colis de [bids] dont la demande se traite depuis la carte de réponse
/// directe : sans les cartes pas encore payées par l'expéditeur
/// ([BidModel.isAwaitingSenderCardPayment], « Accepter » répondrait 409),
/// comme l'action « À traiter » des demandes (`tripTodoFor`) : « Demande 1
/// sur N » et la pastille du billet comptent les mêmes demandes.
List<BidModel>? tripAnswerableBids(List<BidModel>? bids) =>
    bids?.where((b) => !b.isAwaitingSenderCardPayment).toList(growable: false);

/// Section « À traiter » de l'écran du trajet vu par son voyageur, rangée en
/// « Prochaine action » (décision du 31/10) : la grosse carte de l'action la
/// plus urgente ([items] est déjà trié, [tripTodoFor]), puis une carte-liste
/// des [kTripTodoQueueRows] suivantes et, s'il en reste, « + N autres à
/// traiter » ([onShowAll], qui ouvre toute la liste).
///
/// Quand les demandes sont en tête, la grosse carte est la carte de réponse
/// directe ([TripDirectRequestCard] : « Demande 1 sur N », Refuser |
/// Accepter, « Voir les N demandes ») ; sinon [TripTodoNextCard]. Ne rend
/// rien sans action.
///
/// Mesure l'affichage de chaque action visible (`bid_detail_todo_tile_shown`,
/// [tripTodoItemShown]) dans [views], le journal du corps ; celles cachées
/// derrière « + N autres » le sont à l'ouverture de toute la liste.
class TripTodoSection extends StatelessWidget {
  const TripTodoSection({
    super.key,
    required this.live,
    required this.items,
    required this.views,
    required this.onAct,
    required this.onShowAll,
  });

  final TripTodoLiveData live;
  final List<TripTodoItem> items;
  final TodoTileViewLog views;
  final TripTodoActCallback onAct;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final first = items.first;
    final queue = items.skip(1).take(kTripTodoQueueRows).toList();
    final hidden = items.length - 1 - queue.length;
    views.logAll(context, live.trip.id, [
      for (final item in [first, ...queue]) tripTodoItemShown(item, live.trip),
    ]);
    return BidDetailSection(
      key: const Key('trip-todo-section'),
      title: context.l10n.bidDetailSectionTodo,
      spacing: DonySpacing.md,
      children: [
        if (first.kind == TripTodoKind.requests)
          TripDirectRequestCard(
            bids: tripAnswerableBids(live.bids),
            onSeeAll: () => onAct(first, TripTodoSource.card),
          )
        else
          TripTodoNextCard(
            live: live,
            item: first,
            onPressed: () => onAct(first, TripTodoSource.card),
          ),
        if (queue.isNotEmpty)
          TripTodoQueue(
            live: live,
            items: queue,
            hidden: hidden,
            onOpen: (item) => onAct(item, TripTodoSource.list),
            onShowAll: onShowAll,
          ),
      ],
    );
  }
}

/// Grosse carte « Prochaine action » : étiquette « Urgent » (orange) ou
/// « Prochaine action », échéance en orange quand elle est connue
/// ([tripTodoDueLabel]), icône du type en pastille, titre, sous-titre, puis
/// le bouton pleine largeur du type ([tripTodoButton], le même que celui du
/// pied collant).
class TripTodoNextCard extends StatelessWidget {
  const TripTodoNextCard({
    super.key,
    required this.live,
    required this.item,
    required this.onPressed,
  });

  final TripTodoLiveData live;
  final TripTodoItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urgent = item.urgency == TripTodoUrgency.urgent;
    final due = tripTodoDueLabel(
      l,
      item.dueAt,
      now: tripTodoNow(),
      trip: live.trip,
    );
    final title = tripTodoTitle(l, item, cardReady: live.cardReady);
    final subtitle = tripTodoSubtitle(l, item, cardReady: live.cardReady);
    final radius = BorderRadius.circular(DonyRadius.card);
    return Container(
      key: Key('trip-todo-next-${item.kind.name}'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: radius,
        border: Border.all(
          color: urgent ? cs.warning.withValues(alpha: 0.45) : cs.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: DonySpacing.sm,
                  runSpacing: DonySpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TripTodoPill(
                      key: const Key('trip-todo-next-label'),
                      label: tripTodoUrgencyLabel(l, item.urgency),
                      tone: urgent
                          ? TripTodoPillTone.warning
                          : TripTodoPillTone.info,
                    ),
                    if (due != null)
                      Text(
                        due,
                        key: const Key('trip-todo-next-due'),
                        style: tt.labelMedium?.copyWith(
                          color: cs.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DonySpacing.md),
                Row(
                  children: [
                    _KindIcon(kind: item.kind, urgent: urgent),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('trip-todo-next-button'),
            label: tripTodoButton(l, item, cardReady: live.cardReady),
            flat: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// File « À traiter » : une carte-liste, une ligne par action
/// ([TripTodoQueueRow]), puis « + N autres à traiter » quand [hidden] > 0.
class TripTodoQueue extends StatelessWidget {
  const TripTodoQueue({
    super.key,
    required this.live,
    required this.items,
    required this.hidden,
    required this.onOpen,
    required this.onShowAll,
  });

  final TripTodoLiveData live;
  final List<TripTodoItem> items;

  /// Actions qui ne tiennent pas dans la file.
  final int hidden;
  final ValueChanged<TripTodoItem> onOpen;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return TripTodoListCard(
      key: const Key('trip-todo-queue'),
      children: [
        for (final item in items)
          TripTodoQueueRow(live: live, item: item, onTap: () => onOpen(item)),
        if (hidden > 0)
          _Row(
            key: const Key('trip-todo-more'),
            leading: DonyIconContainer(
              iconAsset: 'ellipsis',
              size: DonyIconContainerSize.sm,
              backgroundColor: cs.surfaceContainerHighest,
              iconColor: cs.onSurfaceVariant,
            ),
            title: l.tripTodoMoreRow(hidden),
            subtitle: l.tripTodoMoreRowSubtitle,
            onTap: onShowAll,
          ),
      ],
    );
  }
}

/// Carte-liste (surface, bordure, séparateurs) des lignes « À traiter ».
class TripTodoListCard extends StatelessWidget {
  const TripTodoListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    return Material(
      color: cs.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(height: 1, color: cs.outline),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// Une action de la file : icône du type, titre, sous-titre (et échéance en
/// orange), compteur quand plusieurs demandes ou colis sont concernés,
/// chevron. Clé `trip-todo-row-<type>`.
class TripTodoQueueRow extends StatelessWidget {
  const TripTodoQueueRow({
    super.key,
    required this.live,
    required this.item,
    required this.onTap,
  });

  final TripTodoLiveData live;
  final TripTodoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urgent = item.urgency == TripTodoUrgency.urgent;
    final due = tripTodoDueLabel(
      l,
      item.dueAt,
      now: tripTodoNow(),
      trip: live.trip,
    );
    return _Row(
      key: Key('trip-todo-row-${item.kind.name}'),
      leading: _KindIcon(kind: item.kind, urgent: urgent, small: true),
      title: tripTodoTitle(l, item, cardReady: live.cardReady),
      subtitle: tripTodoSubtitle(l, item, cardReady: live.cardReady),
      due: due,
      trailing: item.count > 1
          ? Container(
              key: Key('trip-todo-row-count-${item.kind.name}'),
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: urgent ? cs.warningLight : cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Text(
                '${item.count}',
                textAlign: TextAlign.center,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: urgent ? cs.warning : cs.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Ligne tappable lue d'un seul tenant : [leading], titre, sous-titre,
/// échéance facultative en orange, [trailing] facultatif, chevron.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.due,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? due;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final due = this.due;
    return Semantics(
      button: true,
      label: [title, subtitle, ?due].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (due != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          due,
                          style: tt.labelMedium?.copyWith(
                            color: cs.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing case final trailing?) ...[
                  const SizedBox(width: DonySpacing.sm),
                  trailing,
                ],
                const SizedBox(width: DonySpacing.sm),
                DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône du type en pastille : tons orange pour une action urgente, ceux du
/// thème sinon.
class _KindIcon extends StatelessWidget {
  const _KindIcon({
    required this.kind,
    required this.urgent,
    this.small = false,
  });

  final TripTodoKind kind;
  final bool urgent;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DonyIconContainer(
      iconAsset: tripTodoIcon(kind),
      size: small ? DonyIconContainerSize.sm : DonyIconContainerSize.md,
      backgroundColor: urgent ? cs.warningLight : null,
      iconColor: urgent ? cs.warning : null,
    );
  }
}

/// Tons de [TripTodoPill].
enum TripTodoPillTone {
  /// Orange : action urgente, pastille « À traiter · N » du billet.
  warning,

  /// Bleu : « Prochaine action ».
  info,
}

/// Petite pastille de texte, contraste au moins 4,5:1 dans les deux thèmes
/// (texte `warning`/`info` sur leur fond clair).
class TripTodoPill extends StatelessWidget {
  const TripTodoPill({super.key, required this.label, required this.tone});

  final String label;
  final TripTodoPillTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      TripTodoPillTone.warning => (cs.warningLight, cs.warning),
      TripTodoPillTone.info => (cs.infoLight, cs.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Pastille « À traiter · N » de l'en-tête du billet ([count] =
/// [tripTodoCount]), lue « N choses à traiter ». Rien à 0.
class TripTodoBadge extends StatelessWidget {
  const TripTodoBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final l = context.l10n;
    return Semantics(
      label: l.tripTodoBadgeSemantics(count),
      excludeSemantics: true,
      child: TripTodoPill(
        key: const Key('trip-todo-badge'),
        label: l.tripTodoBadge(count),
        tone: TripTodoPillTone.warning,
      ),
    );
  }
}

/// Ouvre toute la liste « À traiter » du trajet [trip] (« + N autres à
/// traiter ») : un sheet nommé `trip-owner/todo-all`, titré « À traiter ·
/// N », une ligne par action dans l'ordre de la file. Une ligne ferme le
/// sheet puis ouvre son geste depuis [context] (l'écran,
/// [openTripTodoAction], source `list`). Le sheet suit les mêmes données que la section
/// ([TripTodoLive], demandes traitées depuis l'écran comprises) et se ferme
/// seul quand il ne reste plus rien. L'affichage de chaque ligne est mesuré
/// dans [views], le journal du corps (dédoublonné avec la section).
Future<void> openTripTodoListSheet(
  BuildContext context,
  AnnouncementModel trip, {
  required TodoTileViewLog views,
  List<BidModel>? bids,
}) {
  final blocs = TripTodoBlocs.of(context);
  final answered = TripBidAnswerScope.maybeOf(context)?.answered;

  Widget follow(
    Widget Function(BuildContext, TripTodoLiveData, List<TripTodoItem>) builder,
  ) => TripTodoLive(
    trip: trip,
    blocs: blocs,
    initialBids: bids,
    builder: (context, live) => answered == null
        ? builder(context, live, live.todo())
        : ValueListenableBuilder<Set<String>>(
            valueListenable: answered,
            builder: (context, ids, _) =>
                builder(context, live, live.todo(answered: ids)),
          ),
  );

  return DonyBottomSheet.show<void>(
    context,
    titleWidget: follow(
      (sheetContext, live, items) =>
          Text(sheetContext.l10n.tripTodoBadge(tripTodoCount(items))),
    ),
    analyticsName: 'trip-owner/todo-all',
    wrapper: (content) {
      final providers = [
        if (blocs.announcement case final b?)
          BlocProvider<AnnouncementBloc>.value(value: b),
        if (blocs.bids case final b?) BlocProvider<BidBloc>.value(value: b),
        if (blocs.stripe case final b?)
          BlocProvider<StripeAccountBloc>.value(value: b),
        if (blocs.depart case final b?)
          BlocProvider<TripDepartCubit>.value(value: b),
      ];
      return providers.isEmpty
          ? content
          : MultiBlocProvider(providers: providers, child: content);
    },
    child: follow((sheetContext, live, items) {
      views.logAll(sheetContext, live.trip.id, [
        for (final item in items) tripTodoItemShown(item, live.trip),
      ]);
      return CloseTripSheetWhenGone(
        gone: items.isEmpty,
        child: Padding(
          key: const Key('trip-todo-all'),
          padding: const EdgeInsets.only(bottom: DonySpacing.base),
          child: TripTodoListCard(
            children: [
              for (final item in items)
                TripTodoQueueRow(
                  live: live,
                  item: item,
                  onTap: () {
                    if (!closeSheetIfOnTop(sheetContext) || !context.mounted) {
                      return;
                    }
                    unawaited(
                      openTripTodoAction(
                        context,
                        live,
                        item,
                        source: TripTodoSource.list,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }),
  );
}
