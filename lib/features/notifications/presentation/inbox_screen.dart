import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Returns the GoRouter path to navigate to when tapping a notification,
/// or null if the notification has no actionable destination.
String? _routeForNotification(NotificationModel n) {
  final type = n.type;
  final bidId = n.data['bidId'] as String?;
  final announcementId = n.data['announcementId'] as String?;

  return switch (type) {
    // Voyageur → liste des offres sur son annonce
    'BID_CREATED' when announcementId != null => '/announcements/$announcementId/bids',
    // Expéditeur ou voyageur → détail de l'offre
    'BID_ACCEPTED' when bidId != null        => '/bids/$bidId',
    'BID_REJECTED' when bidId != null        => '/bids/$bidId',
    'HANDOVER_DEFINED' when bidId != null    => '/bids/$bidId',
    'DELIVERY_CONFIRMED' when bidId != null  => '/bids/$bidId',
    'PAYMENT_RELEASED' when bidId != null    => '/bids/$bidId',
    'DISPUTE_OPENED' when bidId != null      => '/bids/$bidId',
    // Trajet annulé → pas de trajet cible
    _ => null,
  };
}

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<NotificationBloc>().add(const NotificationsLoadRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: DonyAppBar(
        title: 'Boîte de réception',
        showBackButton: false,
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          labelStyle: tt.labelLarge,
          unselectedLabelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          tabs: [
            Tab(
              child: BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, state) {
                  final unread = state is NotificationLoaded ? state.unreadCount : 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Notifications'),
                      if (unread > 0) ...[
                        const SizedBox(width: DonySpacing.xs),
                        _UnreadBadge(count: unread, cs: cs, tt: tt),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NotificationsTab(),
          _MessagesTab(),
        ],
      ),
    );
  }
}

// ── Notifications tab ──────────────────────────────────────────────────────────

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        if (state is NotificationLoading || state is NotificationInitial) {
          return Center(
            child: CircularProgressIndicator(color: cs.primary),
          );
        }

        if (state is NotificationError) {
          return DonyEmptyState(
            type: DonyEmptyStateType.error,
            icon: Icons.wifi_off_rounded,
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
              icon: Icons.notifications_none_rounded,
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
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
              itemCount: state.notifications.length,
              separatorBuilder: (context, index) => Divider(
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
                    context.read<NotificationBloc>().add(
                          NotificationMarkReadRequested(notif.id),
                        );
                    final route = _routeForNotification(notif);
                    if (route != null) {
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
                        Icon(Icons.delete_outline_rounded,
                            color: cs.onError, size: 26),
                        const SizedBox(height: DonySpacing.xs),
                        Text(
                          'Supprimer',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.onError,
                              fontWeight: FontWeight.w600),
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

// ── Messages tab (placeholder) ────────────────────────────────────────────────

class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    return const DonyEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Messagerie bientôt disponible',
      description: 'Vous pourrez contacter votre\nvoyageur ou expéditeur ici.',
    );
  }
}

// ── Notification tile ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasRoute = _routeForNotification(notification) != null;

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
                          margin: const EdgeInsets.only(left: DonySpacing.xs),
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
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return 'À l\'instant';
    }
    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    }
    return DateFormat('dd MMM HH:mm', 'fr').format(dt);
  }
}

class _NotificationIcon extends StatelessWidget {
  final String type;
  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, color) = switch (type) {
      'BID_CREATED'        => (Icons.inbox_rounded,          cs.primary),
      'BID_ACCEPTED'       => (Icons.check_circle_rounded,   DonyColors.success),
      'BID_REJECTED'       => (Icons.cancel_rounded,         cs.error),
      'HANDOVER_DEFINED'   => (Icons.location_on_rounded,    cs.secondary),
      'TRIP_CANCELLED'     => (Icons.block_rounded,          cs.error),
      'PAYMENT_RELEASED'   => (Icons.payments_rounded,       DonyColors.success),
      'DELIVERY_CONFIRMED' => (Icons.local_shipping_rounded, DonyColors.success),
      'DISPUTE_OPENED'     => (Icons.warning_amber_rounded,  DonyColors.warning),
      _                    => (Icons.notifications_rounded,  cs.onSurfaceVariant),
    };

    return Container(
      width: DonySpacing.icon,
      height: DonySpacing.icon,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Icon(icon, size: DonySpacing.iconSm, color: color),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  final TextTheme tt;
  const _UnreadBadge({required this.count, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.xs,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onError,
        ),
      ),
    );
  }
}
