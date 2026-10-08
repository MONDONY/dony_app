import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/notifications/bloc/notification_bloc.dart';
import 'package:dony/features/notifications/bloc/notification_event.dart';
import 'package:dony/features/notifications/bloc/notification_state.dart';
import 'package:dony/features/notifications/data/announcements_summary.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/notification_route_resolver.dart';
import 'package:dony/features/notifications/presentation/announcements_inbox_screen.dart';
import 'package:dony/features/notifications/presentation/notification_detail_screen.dart';
import 'package:dony/features/subscriptions/data/subscription_badge_consumer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Résout la route d'une ligne : le `deeplink` décide.
///
/// Présent, on y va : c'est le serveur qui connaît la ressource cible, et
/// pour une ligne agrégée il vise la ressource commune (les offres de
/// l'annonce, les correspondances de l'alerte) et non la dernière
/// notification. Absent, le resolver partagé avec le tap sur push prend le
/// relais pour les lignes servies avant le contrat. Sans rien, et seulement
/// alors, la ligne ouvre l'écran de détail générique : c'est le cas des
/// annonces plateforme, dont le texte complet n'existe que là.
String routeForNotification(NotificationModel n) {
  return n.deeplinkRoute ??
      resolveNotificationRoute(n.type, n.data) ??
      NotificationDetailScreen.routeFor(n.id);
}

/// Route que la ligne peut réellement ouvrir, ou `null` si aucune n'existe.
///
/// Le deeplink garde la main ; s'il vise une route que cette version de
/// l'app ne connaît pas (`/recipients` au lieu de `/profile/recipients` pour
/// RECIPIENT_INVITATION_ACCEPTED, Sentry FLUTTER-7W), le resolver partagé
/// avec le tap sur push est tenté avant de renoncer.
String? openableRouteForNotification(
  NotificationModel n,
  bool Function(String route) exists,
) {
  final primary = routeForNotification(n);
  if (exists(primary)) return primary;
  final fallback = resolveNotificationRoute(n.type, n.data);
  if (fallback != null && fallback != primary && exists(fallback)) {
    return fallback;
  }
  return null;
}

/// `true` si [route] est connue du routeur : un deeplink périmé ou malformé
/// n'ouvre pas la page d'erreur par défaut, le sheet le dit et reste ouvert.
bool notificationRouteExists(GoRouter router, String route) {
  final uri = Uri.tryParse(route);
  if (uri == null) return false;
  return !router.configuration.findMatch(uri).isError;
}

/// Sections temporelles du feed. Une section vide ne s'affiche pas.
enum NotificationSection {
  nouveau,
  cetteSemaine,
  plusTot;

  /// Moins de 24 h : nouveau ; moins de 7 jours : cette semaine ; sinon plus tôt.
  static NotificationSection of(DateTime createdAt, DateTime now) {
    final age = now.difference(createdAt);
    if (age < const Duration(hours: 24)) return nouveau;
    if (age < const Duration(days: 7)) return cetteSemaine;
    return plusTot;
  }

  /// Libellé affiché : « Cette semaine » réutilise la clé commune partagée
  /// avec les autres filtres par date de l'app.
  String label(AppLocalizations l) => switch (this) {
    NotificationSection.nouveau => l.notificationSectionNew,
    NotificationSection.cetteSemaine => l.commonDateThisWeek,
    NotificationSection.plusTot => l.notificationSectionEarlier,
  };
}

/// Horodatage compact d'une ligne : « 2 min », « 3 h », « 2 j », « 28 août ».
/// Il ne se comprime jamais, c'est le titre qui cède.
String formatNotificationAge(
  AppLocalizations l,
  DateTime createdAt,
  DateTime now,
) {
  final local = createdAt.isUtc ? createdAt.toLocal() : createdAt;
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return l.notificationAgeNow;
  if (diff.inMinutes < 60) return l.notificationAgeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.notificationAgeHours(diff.inHours);
  if (diff.inDays < 7) return l.notificationAgeDays(diff.inDays);
  final formatted = local.year == now.year
      ? DateFormat.MMMd(l.localeName).format(local)
      : DateFormat.yMMMd(l.localeName).format(local);
  return formatted;
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
      child: NotificationBottomSheet(
        onReturn: () {
          if (context.mounted) showNotificationBottomSheet(context);
        },
      ),
    ),
  );
}

/// Pousse [route] depuis le sheet, puis le rouvre au retour : le sheet se
/// ferme avant la navigation, et le bouton retour ramenait à l'écran de
/// dessous au lieu des notifications (Sentry FLUTTER-8K). Le sheet ne revient
/// que si l'utilisateur est bien revenu là où il l'avait ouvert, jamais après
/// un changement d'onglet en cours de route.
Future<void> _pushThenReturnToSheet(
  BuildContext sheetContext,
  GoRouter router,
  String route,
) async {
  final reopen = sheetContext
      .findAncestorWidgetOfExactType<NotificationBottomSheet>()
      ?.onReturn;
  final origin = router.routerDelegate.currentConfiguration.uri.toString();
  Navigator.of(sheetContext, rootNavigator: true).pop();
  await router.push(route);
  if (reopen == null) return;
  if (router.routerDelegate.currentConfiguration.uri.toString() != origin) {
    return;
  }
  reopen();
}

class NotificationBottomSheet extends StatefulWidget {
  const NotificationBottomSheet({super.key, this.onReturn});

  /// Rouvre le sheet au retour d'une notification ouverte depuis lui.
  final VoidCallback? onReturn;

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
    final l = context.l10n;
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
                    l.notificationSheetTitle,
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
                          context.l10n.notificationMarkAllRead,
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
    final l = context.l10n;
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
            title: l.notificationLoadErrorTitle,
            description: l.notificationLoadErrorDescription,
            actionLabel: l.commonRetry,
            onAction: () => context.read<NotificationBloc>().add(
              const NotificationsLoadRequested(),
            ),
          );
        }

        if (state is NotificationLoaded) {
          // La carte des annonces vit au-dessus du feed, hors de ses sections,
          // et reste là même quand le feed est vide.
          final card = state.announcements.hasAny
              ? _AnnouncementsCard(summary: state.announcements)
              : null;

          if (state.notifications.isEmpty) {
            return Column(
              children: [
                ?card,
                Expanded(
                  child: DonyEmptyState(
                    mascotte: DonyMascotteType.assis,
                    title: l.notificationEmptyTitle,
                    description: l.notificationEmptyDescription,
                  ),
                ),
              ],
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
              itemCount: rows.length + (card == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (card != null) {
                  if (index == 0) return card;
                  index -= 1;
                }
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
              context.l10n.commonDelete,
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
    // La lecture part d'abord et ne dépend pas de la navigation.
    context.read<NotificationBloc>().add(
      NotificationMarkReadRequested(notif.id),
    );
    unawaited(consumeSubscriptionBadge(notif.type, notif.data));
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final route = openableRouteForNotification(
      notif,
      (r) => notificationRouteExists(router, r),
    );
    if (route == null) {
      // Deeplink périmé ou inconnu de cette version de l'app : on le dit,
      // plutôt que d'ouvrir une page vide, et le sheet reste ouvert.
      DonySnackbar.show(
        context,
        message: context.l10n.notificationRouteMissing,
        type: DonySnackbarType.error,
      );
      return;
    }
    if (isShellTabRoute(route)) {
      Navigator.of(context, rootNavigator: true).pop();
      router.go(route);
    } else {
      unawaited(_pushThenReturnToSheet(context, router, route));
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

/// La carte « Annonces Yadony » : une seule boîte pour tout ce qui vient de
/// la plateforme, visuellement à part du feed, avec son compteur de non-lus
/// et le titre de la dernière annonce.
class _AnnouncementsCard extends StatelessWidget {
  final AnnouncementsSummary summary;
  const _AnnouncementsCard({required this.summary});

  /// Le sheet se ferme avant d'ouvrir la boîte, et revient au retour : il
  /// se recharge alors à l'ouverture, la carte reflète ce qui a été lu.
  Future<void> _open(BuildContext context) => _pushThenReturnToSheet(
    context,
    GoRouter.of(context),
    AnnouncementsInboxScreen.route,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unread = summary.unreadCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.sm,
        DonySpacing.lg,
        DonySpacing.md,
      ),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: DonySpacing.icon,
                  height: DonySpacing.icon,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: DonyIcon(
                    'megaphone',
                    size: DonySpacing.iconSm,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.notificationAnnouncementsCardTitle,
                        style: tt.titleLarge?.copyWith(color: cs.onSurface),
                      ),
                      if (summary.latestTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary.latestTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: DonySpacing.sm),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: tt.labelMedium?.copyWith(
                        // Le primaire sombre est un bleu clair : un chiffre
                        // blanc n'y fait que 3,28:1, le noir monte à 6,39:1.
                        color: Theme.of(context).brightness == Brightness.dark
                            ? DonyColors.onBrandHcDark
                            : cs.onPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
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
        section.label(context.l10n).toUpperCase(),
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
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                          l,
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
            ...[
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
      'RECIPIENT_PARCEL_DELIVERED' => (cs.success, 'circle-check'),
      'RECIPIENT_CONFIRMED' => (cs.success, 'badge-check'),
      'RECIPIENT_INVITATION_ACCEPTED' => (cs.success, 'badge-check'),

      // Perdu
      'BID_REJECTED' => (cs.error, 'circle-x'),
      'PARCEL_REFUSED' => (cs.error, 'circle-x'),
      'negotiation_commission_declined' => (cs.error, 'circle-x'),
      'TRIP_CANCELLED' => (cs.error, 'ban'),
      'RECIPIENT_PARCEL_CANCELLED' => (cs.error, 'ban'),
      'RECIPIENT_PARCEL_REASSIGNED' => (cs.error, 'user-x'),
      'RECIPIENT_INVITATION_REMOVED' => (cs.error, 'user-x'),
      'TRIP_RESCHEDULED' => (cs.warning, 'calendar-sync'),
      'TRIP_RESCHEDULE_KEPT' => (cs.success, 'check'),
      'TRIP_RESCHEDULE_WITHDRAWN' => (cs.error, 'calendar-x'),
      'ACCOUNT_SUSPENDED' => (cs.error, 'shield'),

      // Réclame une action
      'negotiation_awaiting_payment' => (cs.warning, 'credit-card'),
      'negotiation_commission_pending' => (cs.warning, 'wallet'),
      'MM_PAYMENT_PENDING' => (cs.warning, 'credit-card'),
      'CARD_EXPIRING' => (cs.warning, 'credit-card'),
      'DISPUTE_OPENED' => (cs.warning, 'triangle-alert'),
      'DELIVERY_NOSHOW_REPORTED' => (cs.warning, 'user-x'),
      'CONFIRMATION_CODE_READY' => (cs.warning, 'qr-code'),
      'CONFIRMATION_CODE_BLOCKED' => (cs.warning, 'key-round'),
      'PARCEL_RETURN_REQUIRED' => (cs.warning, 'package'),
      'PARCEL_RETURN_TO_SENDER' => (cs.warning, 'package'),
      'RECIPIENT_PARCEL_INCOMING' => (cs.warning, 'inbox'),
      'RECIPIENT_INVITATION' => (cs.warning, 'user-plus'),
      'RECIPIENT_PARCEL_RESCHEDULED' => (cs.warning, 'calendar'),
      'RECIPIENT_DECLINED' => (cs.warning, 'user-x'),
      'RECIPIENT_WITHDRAWN' => (cs.warning, 'user-x'),
      'RECIPIENT_REPLACEMENT_REQUESTED' => (cs.warning, 'user-plus'),
      'RECIPIENT_CHANGED' => (cs.warning, 'refresh-cw'),

      // Informe / met en relation
      'BID_CREATED' => (cs.primary, 'package'),
      'PACKAGE_MATCH' => (cs.primary, 'package'),
      'NEW_MESSAGE' => (cs.primary, 'message-circle'),
      // Même icône que la ligne épinglée « Support Yadony » des conversations.
      'SUPPORT_MESSAGE' => (cs.primary, 'circle-help'),
      'TRIP_IN_PROGRESS' => (cs.primary, 'plane-takeoff'),
      'RECIPIENT_PARCEL_DEPARTED' => (cs.primary, 'plane-takeoff'),
      'RECIPIENT_PARCEL_ARRIVED' => (cs.primary, 'plane-landing'),
      'RECIPIENT_PICKUP_UPDATED' => (cs.primary, 'map-pin'),
      'RECIPIENT_PARCEL_ANNOUNCED' => (cs.primary, 'inbox'),
      'negotiation_started' => (cs.info, 'arrow-left-right'),
      'negotiation_counter' => (cs.info, 'arrow-left-right'),
      'negotiation' => (cs.info, 'arrow-left-right'),
      'TRAVELER_INVITE' => (cs.info, 'handshake'),
      'SENDER_INVITE' => (cs.info, 'package'),
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
