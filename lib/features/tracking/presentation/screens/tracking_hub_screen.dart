import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
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
    final tt = Theme.of(context).textTheme;
    final offlineItems = _getOfflineItems();

    return Scaffold(
      backgroundColor: DonyColors.bgApp,
      appBar: AppBar(
        backgroundColor: DonyColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Suivi des colis',
          style: tt.headlineLarge,
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: DonyColors.borderDefault),
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
                onTap: () => OfflineQueueBottomSheet.show(
                  context,
                  items: offlineItems,
                ),
              ),
              const SizedBox(height: DonySpacing.xl),
            ],

            // ── Section voyageur ────────────────────────────────────────
            const _HubSectionTitle(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Je suis voyageur',
            ),
            const SizedBox(height: DonySpacing.md),
            _HubCard(
              icon: Icons.qr_code_scanner_rounded,
              iconBg: DonyColors.blue50,
              iconColor: DonyColors.blue500,
              title: 'Scanner le QR code d\'un colis',
              subtitle: 'À la remise, en transit ou à la livraison',
              onTap: () => context.push('/tracking/scan'),
            ),
            const SizedBox(height: DonySpacing.xxl),

            // ── Section expéditeur / destinataire ───────────────────────
            const _HubSectionTitle(
              icon: Icons.search_rounded,
              label: 'Je suis expéditeur ou destinataire',
            ),
            const SizedBox(height: DonySpacing.md),
            _HubCard(
              icon: Icons.search_rounded,
              iconBg: DonyColors.neutral100,
              iconColor: DonyColors.textMuted,
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
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: DonyColors.terra50,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.terra500),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: DonyColors.terra500,
              size: DonySpacing.iconSm,
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count scan${count > 1 ? 's' : ''} en attente',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DonyColors.terra600,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    'Appuyez pour voir et synchroniser',
                    style: tt.bodySmall?.copyWith(color: DonyColors.terra500),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DonyColors.terra500,
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
  const _HubSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 14, color: DonyColors.textMuted),
        const SizedBox(width: DonySpacing.xs),
        Text(
          label.toUpperCase(),
          style: tt.labelMedium?.copyWith(
            color: DonyColors.textMuted,
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
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base + 2),
        decoration: BoxDecoration(
          color: DonyColors.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: DonyColors.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DonySpacing.md),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: DonySpacing.base - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DonyColors.textSubtle,
              size: DonySpacing.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}
