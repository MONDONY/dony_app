import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/presentation/widgets/secondary_activity_entry.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class _EtapeInfo {
  final String code;
  final String label;
  final IconData icon;
  final bool photoRequired;

  const _EtapeInfo(
    this.code,
    this.label,
    this.icon, {
    required this.photoRequired,
  });
}

const _etapes = [
  _EtapeInfo(
    'DEPART',
    'Départ',
    Icons.flight_takeoff_rounded,
    photoRequired: true,
  ),
  _EtapeInfo(
    'TRANSIT',
    'Transit',
    Icons.sync_alt_rounded,
    photoRequired: false,
  ),
  _EtapeInfo(
    'ARRIVEE',
    'Arrivée',
    Icons.flight_land_rounded,
    photoRequired: true,
  ),
];

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key, this.onTrackParcel});

  /// Entrée additive « Suivre un colis » (voyageur pro). Null = non affichée.
  final VoidCallback? onTrackParcel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ScanHubCubit>()..load(),
      child: ScanHubView(onTrackParcel: onTrackParcel),
    );
  }
}

class ScanHubView extends StatelessWidget {
  const ScanHubView({super.key, this.onTrackParcel});

  final VoidCallback? onTrackParcel;

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
        title: Text('Scan & Suivi', style: tt.headlineLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: BlocBuilder<ScanHubCubit, ScanHubState>(
        builder: (context, state) {
          switch (state) {
            case ScanHubLoading():
              return Center(
                child: CircularProgressIndicator(color: cs.primary),
              );
            case ScanHubError(:final message):
              return _ErrorState(
                message: message,
                onRetry: () => context.read<ScanHubCubit>().load(),
              );
            case ScanHubEmpty():
              return const _NoTripState();
            case ScanHubLoaded(:final trip, :final progress):
              // Animation d'entrée jouée une fois : ScanHubLoaded est un état
              // terminal (le cubit charge une seule fois, pas de refresh). Si un
              // rafraîchissement de progression est ajouté un jour, sortir le
              // `.animate()` du sous-arbre piloté par l'état pour éviter le replay.
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.lg,
                  DonySpacing.xl,
                  DonySpacing.lg,
                  DonySpacing.huge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      [
                            if (onTrackParcel != null) ...[
                              SecondaryActivityEntry(
                                icon: Icons.inventory_2_rounded,
                                label: 'Suivre un colis',
                                onTap: onTrackParcel!,
                              ),
                              const SizedBox(height: DonySpacing.lg),
                            ],
                            _TripHeroCard(
                              corridor:
                                  '${trip.departureCity} → ${trip.arrivalCity}',
                              dateLabel: _formatDate(trip.departureDate),
                              confirmedColis: progress.confirmedColis,
                              scannedDepart: progress.scannedDepart,
                            ),
                            const SizedBox(height: DonySpacing.xl),
                            const _EtapesSection(),
                            const SizedBox(height: DonySpacing.xl),
                            const _QuickActionsSection(),
                          ]
                          .animate(interval: 60.ms)
                          .fadeIn(duration: 280.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOutCubic),
                ),
              );
          }
        },
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'fr').format(date);
}

class _TripHeroCard extends StatelessWidget {
  const _TripHeroCard({
    required this.corridor,
    required this.dateLabel,
    required this.confirmedColis,
    required this.scannedDepart,
  });

  final String corridor;
  final String dateLabel;
  final int confirmedColis;
  final int scannedDepart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = confirmedColis == 0 ? 0.0 : scannedDepart / confirmedColis;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAJET ACTIF',
            style: tt.labelSmall?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.7),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            corridor,
            style: tt.headlineMedium?.copyWith(
              color: DonyColors.neutral0,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$dateLabel · $confirmedColis colis confirmés',
            style: tt.bodySmall?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.75),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DonySpacing.md),
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: DonyColors.neutral0.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scans départ',
                      style: tt.labelSmall?.copyWith(
                        color: DonyColors.neutral0.withValues(alpha: 0.85),
                      ),
                    ),
                    Text(
                      '$scannedDepart / $confirmedColis',
                      style: tt.labelSmall?.copyWith(
                        color: DonyColors.neutral0,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: DonyColors.neutral0.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(cs.success),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTripState extends StatelessWidget {
  const _NoTripState();

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      title: 'Aucun trajet à scanner',
      description:
          'Tu pourras scanner les colis dès qu\'une demande sera acceptée sur l\'un de tes trajets.',
      mascotte: DonyMascotteType.assis,
      actionLabel: 'Voir mes trajets',
      onAction: () => context.push('/announcements/trips'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DonyEmptyState(
      title: 'Impossible de charger les trajets',
      description: message,
      type: DonyEmptyStateType.error,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

class _EtapesSection extends StatelessWidget {
  const _EtapesSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOISIR UNE ÉTAPE',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: _etapes
              .map(
                (e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: e.code == 'ARRIVEE' ? 0 : DonySpacing.sm,
                    ),
                    child: _EtapeChip(etape: e),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Photo obligatoire au départ et à l\'arrivée. Au transit, la photo est facultative.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EtapeChip extends StatelessWidget {
  const _EtapeChip({required this.etape});
  final _EtapeInfo etape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyPressable(
      onTap: () => context.push(
        '/tracking/scan/identify',
        extra: <String, dynamic>{'etape': etape.code, 'focusNumber': false},
      ),
      child: DonyCard(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md,
          horizontal: DonySpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(etape.icon, size: 24, color: cs.onSurface),
            const SizedBox(height: DonySpacing.sm),
            Text(
              etape.label,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DonySpacing.xs),
            // Slot de hauteur fixe, pleine largeur : badge photo (départ/arrivée)
            // ou vide (transit), pour garder les 3 chips alignés. FittedBox =
            // garantie zéro overflow même sur écran étroit.
            SizedBox(
              height: 20,
              width: double.infinity,
              child: etape.photoRequired
                  ? const FittedBox(fit: BoxFit.scaleDown, child: _PhotoBadge())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge compact « 📷 Photo » — exigence photo de l'étape.
class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.errorLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_camera_rounded, size: 11, color: cs.error),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            'Photo',
            style: tt.labelSmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OU IDENTIFIER DIRECTEMENT',
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickBtn(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scanner QR',
                subtitle: 'Caméra directe',
                onTap: () => context.push('/tracking/scan'),
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _QuickBtn(
                icon: Icons.dialpad_rounded,
                label: 'Numéro',
                subtitle: 'DON-XXXXXX',
                onTap: () => context.push(
                  '/tracking/scan/identify',
                  extra: <String, dynamic>{'etape': null, 'focusNumber': true},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DonyPressable(
      onTap: onTap,
      child: DonyCard(
        padding: const EdgeInsets.all(DonySpacing.md),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Icon(icon, color: cs.primary, size: 20),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              label,
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
