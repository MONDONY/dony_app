import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/notification_route_resolver.dart';
import 'package:dony/features/subscriptions/data/subscription_badge_consumer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Résout la route d'une ligne.
///
/// Une ligne agrégée va là où le serveur l'envoie (les offres de l'annonce,
/// les correspondances de l'alerte) : c'est sa `deeplink`, qui vise la
/// ressource commune et non la dernière notification. Une ligne seule passe
/// par le resolver partagé avec le tap sur push, pour que la boîte de
/// réception et les push mènent toujours au même endroit.
String? routeForNotification(NotificationModel n) {
  if (n.isAggregate) {
    return n.deeplinkRoute ?? resolveNotificationRoute(n.type, n.data);
  }
  return resolveNotificationRoute(n.type, n.data);
}

/// Sections temporelles du feed. Une section vide ne s'affiche pas.
enum NotificationSection {
  nouveau('Nouveau'),
  cetteSemaine('Cette semaine'),
  plusTot('Plus tôt');

  const NotificationSection(this.label);

  final String label;

  /// Moins de 24 h : nouveau ; moins de 7 jours : cette semaine ; sinon plus tôt.
  static NotificationSection of(DateTime createdAt, DateTime now) {
    final age = now.difference(createdAt);
    if (age < const Duration(hours: 24)) return nouveau;
    if (age < const Duration(days: 7)) return cetteSemaine;
    return plusTot;
  }
}

/// Horodatage compact d'une ligne : « 2 min », « 3 h », « 2 j », « 28 août ».
/// Il ne se comprime jamais, c'est le titre qui cède.
String formatNotificationAge(DateTime createdAt, DateTime now) {
  final local = createdAt.isUtc ? createdAt.toLocal() : createdAt;
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} j';
  final pattern = local.year == now.year ? 'd MMM' : 'd MMM yyyy';
  return DateFormat(pattern, 'fr').format(local);
}

void showNotificationBottomSheet(BuildContext context) {
  final bloc = context.read<NotificationBloc>();
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const NotificationBottomSheet()),
  );
}

class NotificationBottomSheet extends StatefulWidget {
  const NotificationBottomSheet({super.key});

  @override
  State<NotificationBottomSheet> createState() =>
      _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(const NotificationsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: DonySpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.base,
              DonySpacing.base,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Notifications',
                    style: tt.headlineSmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                BlocBuilder<NotificationBloc, NotificationState>(
                  builder: (context, state) {
                    if (state is NotificationLoaded && state.unreadCount > 0) {
                      return TextButton(
                        onPressed: () => context.read<NotificationBloc>().add(
                          const NotificationsMarkAllReadRequested(),
                        ),
                        child: Text(
                          'Tout lire',
                          style: tt.titleMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 40);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Expanded(child: _NotificationList()),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        if (state is NotificationLoading || state is NotificationInitial) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        if (state is NotificationError) {
          return DonyEmptyState(
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            iconAsset: 'wifi-off',
            title: 'Erreur de chargement',
            description: 'Impossible de charger vos notifications.',
            actionLabel: 'Réessayer',
            onAction: () => context.read<NotificationBloc>().add(
              const NotificationsLoadRequested(),
            ),
          );
        }

        if (state is NotificationLoaded) {
          if (state.notifications.isEmpty) {
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune notification',
              description: 'Vos notifications apparaîtront ici.',
            );
          }

          final rows = _sectioned(state.notifications, DateTime.now());
          return RefreshIndicator(
            color: cs.primary,
            onRefresh: () async => context.read<NotificationBloc>().add(
              const NotificationsLoadRequested(),
            ),
            child: ListView.builder(
              padding: EdgeInsets.only(
                bottom:
                    DonySpacing.sm + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is _SectionRow) {
                  return _SectionHeader(section: row.section);
                }
                final entry = row as _NotificationRow;
                return _buildTile(context, entry, index);
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTile(BuildContext context, _NotificationRow row, int index) {
    final cs = Theme.of(context).colorScheme;
    final notif = row.notification;
    final tile =
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!row.first)
              Divider(
                height: 1,
                color: cs.outline,
                indent: _NotificationTile.textIndent,
                endIndent: DonySpacing.lg,
              ),
            _NotificationTile(
              notification: notif,
              onTap: () => _open(context, notif),
            ),
          ],
        ).animate().fadeIn(
          delay: Duration(milliseconds: 40 * index),
          duration: 280.ms,
        );

    // Une ligne agrégée recouvre plusieurs notifications : pas de suppression
    // d'un geste, l'utilisateur la lit et le groupe se défait tout seul.
    if (notif.isAggregate) return tile;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DonySpacing.xl),
        color: cs.error,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon('trash-2', color: cs.onError, size: 26),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Supprimer',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => context.read<NotificationBloc>().add(
        NotificationDeleteRequested(notif.id),
      ),
      child: tile,
    );
  }

  /// Marque lue, puis navigue. La lecture part avant la navigation et ne
  /// dépend pas de son succès. Le sheet se ferme avant de pousser la route.
  void _open(BuildContext context, NotificationModel notif) {
    context.read<NotificationBloc>().add(
      NotificationMarkReadRequested(notif.id),
    );
    unawaited(consumeSubscriptionBadge(notif.type, notif.data));
    final route = routeForNotification(notif);
    if (route == null) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (isShellTabRoute(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  /// Intercale un en-tête devant la première ligne de chaque section, en
  /// gardant l'ordre du serveur (plus récente en tête).
  static List<_Row> _sectioned(List<NotificationModel> items, DateTime now) {
    final rows = <_Row>[];
    NotificationSection? current;
    for (final n in items) {
      final section = NotificationSection.of(n.createdAt, now);
      final opens = section != current;
      if (opens) {
        rows.add(_SectionRow(section));
        current = section;
      }
      rows.add(_NotificationRow(n, first: opens));
    }
    return rows;
  }
}

sealed class _Row {
  const _Row();
}

class _SectionRow extends _Row {
  final NotificationSection section;
  const _SectionRow(this.section);
}

class _NotificationRow extends _Row {
  final NotificationModel notification;

  /// Première ligne de sa section : pas de séparateur au-dessus.
  final bool first;
  const _NotificationRow(this.notification, {required this.first});
}

class _SectionHeader extends StatelessWidget {
  final NotificationSection section;
  const _SectionHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Text(
        section.label.toUpperCase(),
        style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  /// Gouttière fixe de la pastille non-lu : les titres restent alignés qu'une
  /// ligne soit lue ou non.
  static const double gutter = 16;

  /// Où commence le texte : gouttière + icône + gap.
  static const double textIndent =
      DonySpacing.xs + gutter + DonySpacing.icon + DonySpacing.md;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasRoute = routeForNotification(notification) != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.xs,
          DonySpacing.md,
          DonySpacing.lg,
          DonySpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gutter,
              height: DonySpacing.icon,
              child: notification.read
                  ? null
                  : Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            _NotificationIcon(type: notification.type),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: notification.read
                                ? FontWeight.w600
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        formatNotificationAge(
                          notification.createdAt,
                          DateTime.now(),
                        ),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (hasRoute) ...[
              const SizedBox(width: DonySpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: DonyIcon(
                  'chevron-right',
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final String type;
  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Une famille = une couleur, pour que la liste se lise en diagonale sans
    // rien lire : vert ce qui a abouti, rouge ce qui est perdu, ambre ce qui
    // réclame une action, bleu ce qui informe, gris ce qui s'est éteint tout
    // seul. Seuls les types réellement émis par le backend figurent ici ;
    // le reste tombe sur la cloche neutre.
    final (Color color, String iconAsset) = switch (type) {
      // Abouti
      'BID_ACCEPTED' => (cs.success, 'circle-check'),
      'request_accepted' => (cs.success, 'circle-check'),
      'negotiation_awaiting_trip' => (cs.success, 'circle-check'),
      'PAYMENT_RELEASED' => (cs.success, 'banknote'),
      'DELIVERY_CONFIRMED' => (cs.success, 'package'),

      // Perdu
      'BID_REJECTED' => (cs.error, 'circle-x'),
      'PARCEL_REFUSED' => (cs.error, 'circle-x'),
      'negotiation_commission_declined' => (cs.error, 'circle-x'),
      'TRIP_CANCELLED' => (cs.error, 'ban'),
      'ACCOUNT_SUSPENDED' => (cs.error, 'shield'),

      // Réclame une action
      'negotiation_awaiting_payment' => (cs.warning, 'credit-card'),
      'negotiation_commission_pending' => (cs.warning, 'wallet'),
      'MM_PAYMENT_PENDING' => (cs.warning, 'credit-card'),
      'CARD_EXPIRING' => (cs.warning, 'credit-card'),
      'DISPUTE_OPENED' => (cs.warning, 'triangle-alert'),
      'DELIVERY_NOSHOW_REPORTED' => (cs.warning, 'user-x'),
      'CONFIRMATION_CODE_READY' => (cs.warning, 'qr-code'),

      // Informe / met en relation
      'BID_CREATED' => (cs.primary, 'package'),
      'PACKAGE_MATCH' => (cs.primary, 'package'),
      'NEW_MESSAGE' => (cs.primary, 'message-circle'),
      'TRIP_IN_PROGRESS' => (cs.primary, 'plane-takeoff'),
      'negotiation_started' => (cs.info, 'arrow-left-right'),
      'negotiation_counter' => (cs.info, 'arrow-left-right'),
      'negotiation' => (cs.info, 'arrow-left-right'),
      'TRAVELER_INVITE' => (cs.info, 'handshake'),
      'CORRIDOR_ALERT' => (cs.info, 'plane'),
      'TRAVELER_NEW_ANNOUNCEMENT' => (cs.info, 'plane'),
      'automation_capacity_free' => (cs.info, 'zap'),
      'automation_last_minute' => (cs.info, 'zap'),
      'automation_loyal_sender' => (cs.info, 'zap'),

      // Éteint tout seul, sans action possible
      'BID_EXPIRED' => (cs.onSurfaceVariant, 'timer-off'),
      'request_expired' => (cs.onSurfaceVariant, 'timer-off'),
      'negotiation_expired' => (cs.onSurfaceVariant, 'timer-off'),
      'negotiation_commission_expired' => (cs.onSurfaceVariant, 'timer-off'),

      _ => (cs.onSurfaceVariant, 'bell'),
    };

    return Container(
      width: DonySpacing.icon,
      height: DonySpacing.icon,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: iconAsset == 'package'
          ? const DonyEmoji.parcel(size: DonySpacing.iconSm)
          : DonyIcon(iconAsset, size: DonySpacing.iconSm, color: color),
    );
  }
}
