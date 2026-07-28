import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// IDs are validated as UUIDs before being embedded in routes to prevent
// path traversal from crafted notification payloads.
final RegExp _uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
bool _isUuid(String? v) => v != null && _uuidRegex.hasMatch(v);

String? routeForNotification(NotificationModel n) {
  final bidId = n.data['bidId'] as String?;
  final announcementId = n.data['announcementId'] as String?;
  final requestId = n.data['requestId'] as String?;
  final cancellationId = n.data['cancellationId'] as String?;

  return switch (n.type) {
    'BID_CREATED' when announcementId != null => '/announcements/$announcementId/bids',
    'BID_ACCEPTED' when bidId != null         => '/bids/$bidId',
    // Offre refusée → alternatives rematch si le back en a trouvé
    'BID_REJECTED' when _isUuid(cancellationId) => '/cancellations/$cancellationId/rematch',
    'BID_REJECTED' when bidId != null         => '/bids/$bidId',
    'HANDOVER_DEFINED' when bidId != null     => '/bids/$bidId',
    'DELIVERY_CONFIRMED' when bidId != null   => '/bids/$bidId',
    'PAYMENT_RELEASED' when bidId != null     => '/bids/$bidId',
    'DISPUTE_OPENED' when bidId != null       => '/bids/$bidId',
    // Expéditeur → détail du trajet qui matche son alerte corridor
    'CORRIDOR_ALERT' when announcementId != null => '/traveler/$announcementId',
    // Voyageur → détail du colis qui matche un de ses trajets
    'PACKAGE_MATCH' when requestId != null => '/package-requests/$requestId/public',
    // Trajet annulé → alternatives rematch si le back en a trouvé
    'TRIP_CANCELLED' when _isUuid(cancellationId) => '/cancellations/$cancellationId/rematch',
    _ => null,
  };
}

void showNotificationBottomSheet(BuildContext context) {
  final bloc = context.read<NotificationBloc>();
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const NotificationBottomSheet(),
    ),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: DonySpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xs,
              DonySpacing.sm,
              DonySpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                BlocBuilder<NotificationBloc, NotificationState>(
                  builder: (context, state) {
                    if (state is NotificationLoaded && state.unreadCount > 0) {
                      return TextButton(
                        onPressed: () => context
                            .read<NotificationBloc>()
                            .add(const NotificationsMarkAllReadRequested()),
                        child: Text(
                          'Tout lire',
                          style: tt.labelLarge?.copyWith(color: cs.primary),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
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
            onAction: () => context
                .read<NotificationBloc>()
                .add(const NotificationsLoadRequested()),
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

          return RefreshIndicator(
            color: cs.primary,
            onRefresh: () async => context
                .read<NotificationBloc>()
                .add(const NotificationsLoadRequested()),
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: DonySpacing.sm,
                bottom: DonySpacing.sm + MediaQuery.of(context).viewPadding.bottom,
              ),
              itemCount: state.notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: cs.outline,
                indent: DonySpacing.lg,
                endIndent: DonySpacing.lg,
              ),
              itemBuilder: (context, index) {
                final notif = state.notifications[index];
                final tile = _NotificationTile(
                  notification: notif,
                  onTap: () {
                    context
                        .read<NotificationBloc>()
                        .add(NotificationMarkReadRequested(notif.id));
                    final route = routeForNotification(notif);
                    if (route != null) {
                      Navigator.of(context, rootNavigator: true).pop();
                      if (route.startsWith('/bids/')) {
                        context.push(route);
                      } else {
                        context.go(route);
                      }
                    }
                  },
                ).animate().fadeIn(
                      delay: Duration(milliseconds: 40 * index),
                      duration: 280.ms,
                    );

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
                        DonyIcon('trash-2',
                            color: cs.onError, size: 26),
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
                  onDismissed: (_) => context
                      .read<NotificationBloc>()
                      .add(NotificationDeleteRequested(notif.id)),
                  child: tile,
                );
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasRoute = routeForNotification(notification) != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.read
            ? cs.surface
            : cs.primaryContainer.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationIcon(type: notification.type),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(left: DonySpacing.xs),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    notification.body,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    _formatDate(notification.createdAt),
                    style: tt.labelSmall?.copyWith(
                      color: cs.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasRoute) ...[
              const SizedBox(width: DonySpacing.sm),
              DonyIcon('chevron-right',
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd MMM HH:mm', 'fr').format(local);
  }
}

class _NotificationIcon extends StatelessWidget {
  final String type;
  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (Color color, String iconAsset) = switch (type) {
      'BID_CREATED'        => (cs.primary,          'package'),
      'BID_ACCEPTED'       => (cs.success,          'circle-check'),
      'BID_REJECTED'       => (cs.error,            'circle-x'),
      'HANDOVER_DEFINED'   => (cs.secondary,        'map-pin'),
      'TRIP_CANCELLED'     => (cs.error,            'ban'),
      'PAYMENT_RELEASED'   => (cs.success,          'banknote'),
      'DELIVERY_CONFIRMED' => (cs.success,          'package'),
      'DISPUTE_OPENED'     => (cs.warning,          'triangle-alert'),
      _                    => (cs.onSurfaceVariant, 'bell'),
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
