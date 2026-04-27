import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Scaffold(
      backgroundColor: DonyColors.grey50,
      appBar: AppBar(
        title: Text(
          'Boîte de réception',
          style: GoogleFonts.sora(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DonyColors.ink900,
          ),
        ),
        centerTitle: false,
        backgroundColor: DonyColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DonyColors.green400,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DonyColors.green400,
          indicatorWeight: 2,
          labelColor: DonyColors.green400,
          unselectedLabelColor: DonyColors.grey400,
          labelStyle: GoogleFonts.sora(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.sora(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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
                        const SizedBox(width: 6),
                        _UnreadBadge(count: unread),
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
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        if (state is NotificationLoading || state is NotificationInitial) {
          return const Center(
            child: CircularProgressIndicator(color: DonyColors.green400),
          );
        }

        if (state is NotificationError) {
          return _ErrorView(
            onRetry: () => context
                .read<NotificationBloc>()
                .add(const NotificationsLoadRequested()),
          );
        }

        if (state is NotificationLoaded) {
          if (state.notifications.isEmpty) {
            return const _EmptyView();
          }
          return RefreshIndicator(
            color: DonyColors.green400,
            onRefresh: () async => context
                .read<NotificationBloc>()
                .add(const NotificationsLoadRequested()),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: DonyColors.grey100, indent: 20, endIndent: 20),
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
                    padding: const EdgeInsets.only(right: 24),
                    color: DonyColors.error,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 26),
                        const SizedBox(height: 4),
                        Text(
                          'Supprimer',
                          style: GoogleFonts.sora(
                              color: Colors.white,
                              fontSize: 12,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DonyColors.green100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 32, color: DonyColors.green400),
          ),
          const SizedBox(height: 16),
          Text(
            'Messagerie bientôt disponible',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DonyColors.ink900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vous pourrez contacter votre\nvoyageur ou expéditeur ici.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 13,
              color: DonyColors.grey400,
            ),
          ),
        ],
      ),
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
    final hasRoute = _routeForNotification(notification) != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.read ? DonyColors.white : DonyColors.green100.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationIcon(type: notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: notification.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: DonyColors.ink900,
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: DonyColors.green400,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      color: DonyColors.grey400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt),
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      color: DonyColors.grey200,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasRoute) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 18, color: DonyColors.grey200),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return DateFormat('dd MMM HH:mm', 'fr').format(dt);
  }
}

class _NotificationIcon extends StatelessWidget {
  final String type;
  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'BID_CREATED' => (Icons.inbox_rounded, DonyColors.green400),
      'BID_ACCEPTED' => (Icons.check_circle_rounded, DonyColors.success),
      'BID_REJECTED' => (Icons.cancel_rounded, DonyColors.error),
      'HANDOVER_DEFINED' => (Icons.location_on_rounded, const Color(0xFFE67E22)),
      'TRIP_CANCELLED' => (Icons.block_rounded, DonyColors.error),
      'PAYMENT_RELEASED' => (Icons.payments_rounded, DonyColors.success),
      'DELIVERY_CONFIRMED' => (Icons.local_shipping_rounded, DonyColors.success),
      'DISPUTE_OPENED' => (Icons.warning_amber_rounded, DonyColors.warning),
      _ => (Icons.notifications_rounded, DonyColors.grey400),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// ── Empty / Error / Badge views ───────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DonyColors.green100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 32, color: DonyColors.green400),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DonyColors.ink900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vos notifications apparaîtront ici.',
            style: GoogleFonts.sora(
              fontSize: 13,
              color: DonyColors.grey400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: DonyColors.grey200),
          const SizedBox(height: 12),
          Text(
            'Erreur de chargement',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DonyColors.ink900,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: GoogleFonts.sora(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
