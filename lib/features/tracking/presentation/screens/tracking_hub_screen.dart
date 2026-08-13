import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/presentation/widgets/offline_queue_bottom_sheet.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_search_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TrackingHubScreen extends StatelessWidget {
  const TrackingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TrackingBloc>(),
      child: const _TrackingHubView(),
    );
  }
}

class _TrackingHubView extends StatelessWidget {
  const _TrackingHubView();

  // Stubbed offline items — in a real implementation these come from
  // the OfflineSyncService / HiveService via the BLoC or a dedicated provider.
  List<OfflineScanItem> _getOfflineItems() => const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final offlineItems = _getOfflineItems();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Suivi des colis', style: tt.headlineLarge),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xxl,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bannière offline (si des scans sont en attente) ─────────
            if (offlineItems.isNotEmpty) ...[
              _OfflineBanner(
                count: offlineItems.length,
                onTap: () =>
                    OfflineQueueBottomSheet.show(context, items: offlineItems),
              ),
              const SizedBox(height: DonySpacing.xl),
            ],

            // ── Section voyageur ────────────────────────────────────────
            const _HubSectionTitle(
              iconAsset: 'scan-line',
              label: 'Je suis voyageur',
            ),
            const SizedBox(height: DonySpacing.md),
            _HubCard(
              iconAsset: 'scan-line',
              iconBg: cs.primaryContainer,
              iconColor: cs.primary,
              title: 'Lire le QR code d\'un colis',
              subtitle: 'À la remise, en transit ou à la livraison',
              onTap: () => context.push('/tracking/scan'),
            ),
            const SizedBox(height: DonySpacing.xxl),

            // ── Section expéditeur / destinataire ───────────────────────
            const _HubSectionTitle(
              iconAsset: 'search',
              label: 'Je suis expéditeur ou destinataire',
            ),
            const SizedBox(height: DonySpacing.md),
            _HubCard(
              iconAsset: 'search',
              iconBg: cs.surfaceContainerHighest,
              iconColor: cs.onSurfaceVariant,
              title: 'Suivre un colis par numéro',
              subtitle: 'Entrez votre numéro DON-XXXXXX',
              onTap: () => TrackingSearchBottomSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.secondary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyIcon('wifi-off', color: cs.secondary, size: DonySpacing.iconSm),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count lecture${count > 1 ? 's' : ''} en attente',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    'Appuyez pour voir et synchroniser',
                    style: tt.bodySmall?.copyWith(color: cs.secondary),
                  ),
                ],
              ),
            ),
            DonyIcon(
              'chevron-right',
              color: cs.secondary,
              size: DonySpacing.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────

class _HubSectionTitle extends StatelessWidget {
  const _HubSectionTitle({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        DonyIcon(iconAsset, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label.toUpperCase(),
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Hub card ──────────────────────────────────────────────────────────────────

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.iconAsset,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base + 2),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: DonyIcon(iconAsset, color: iconColor),
            ),
            const SizedBox(width: DonySpacing.base - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            DonyIcon(
              'chevron-right',
              color: cs.onSurfaceVariant,
              size: DonySpacing.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}
