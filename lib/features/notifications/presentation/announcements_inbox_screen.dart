import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_bloc.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_event.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// La boîte « Annonces Yadony » : la liste des annonces plateforme.
///
/// Pas d'avatar ni d'icône de type : tout vient de la même source, une icône
/// répétée serait du bruit. Le tap marque l'annonce lue ; l'écran de détail
/// avec le texte complet arrive avec le routage (lot 6).
class AnnouncementsInboxScreen extends StatelessWidget {
  const AnnouncementsInboxScreen({super.key});

  static const route = '/notifications/annonces';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<AnnouncementsInboxBloc>()
            ..add(const AnnouncementsInboxLoadRequested()),
      child: const _AnnouncementsInboxView(),
    );
  }
}

class _AnnouncementsInboxView extends StatelessWidget {
  const _AnnouncementsInboxView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: const DonyAppBarBackButton(),
        title: Text('Annonces Yadony', style: tt.headlineLarge),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cs.outline, height: 1),
        ),
      ),
      body: BlocBuilder<AnnouncementsInboxBloc, AnnouncementsInboxState>(
        builder: (context, state) => switch (state) {
          AnnouncementsInboxInitial() || AnnouncementsInboxLoading() => Center(
            child: CircularProgressIndicator(color: cs.primary),
          ),
          AnnouncementsInboxError() => DonyEmptyState(
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            iconAsset: 'wifi-off',
            title: 'Erreur de chargement',
            description: 'Impossible de charger les annonces.',
            actionLabel: 'Réessayer',
            onAction: () => context.read<AnnouncementsInboxBloc>().add(
              const AnnouncementsInboxLoadRequested(),
            ),
          ),
          AnnouncementsInboxLoaded(:final announcements) =>
            announcements.isEmpty
                ? const DonyEmptyState(
                    mascotte: DonyMascotteType.assis,
                    title: 'Aucune annonce',
                    description:
                        'Les nouveautés et informations de Yadony '
                        'apparaîtront ici.',
                  )
                : _AnnouncementsList(announcements: announcements),
        },
      ),
    );
  }
}

class _AnnouncementsList extends StatelessWidget {
  final List<NotificationModel> announcements;
  const _AnnouncementsList({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: cs.primary,
      onRefresh: () async => context.read<AnnouncementsInboxBloc>().add(
        const AnnouncementsInboxLoadRequested(),
      ),
      child: ListView.separated(
        padding: EdgeInsets.only(
          top: DonySpacing.sm,
          bottom: DonySpacing.sm + MediaQuery.of(context).viewPadding.bottom,
        ),
        itemCount: announcements.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: cs.outline,
          indent: _AnnouncementTile.textIndent,
          endIndent: DonySpacing.lg,
        ),
        itemBuilder: (context, index) {
          final a = announcements[index];
          return _AnnouncementTile(
            announcement: a,
            onTap: () => context.read<AnnouncementsInboxBloc>().add(
              AnnouncementsInboxMarkReadRequested(a.id),
            ),
          ).animate().fadeIn(
            delay: Duration(milliseconds: 40 * index),
            duration: 280.ms,
          );
        },
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final NotificationModel announcement;
  final VoidCallback onTap;

  const _AnnouncementTile({required this.announcement, required this.onTap});

  /// Même gouttière que le feed : la pastille garde sa place, les titres
  /// restent alignés lus ou non.
  static const double gutter = 16;
  static const double textIndent = DonySpacing.xs + gutter;

  @override
  Widget build(BuildContext context) {
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
              height: 20,
              child: announcement.read
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
                          announcement.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: announcement.read
                                ? FontWeight.w600
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        formatNotificationAge(
                          announcement.createdAt,
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
                    announcement.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
