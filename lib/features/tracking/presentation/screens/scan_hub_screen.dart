import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _TripStub {
  static const corridor = 'Paris → Dakar';
  static const date = '22 mai 2025';
  static const totalColis = 3;
  static const scannedDepart = 1;
}

class _EtapeInfo {
  final String code;
  final String label;
  final IconData icon;
  final bool photoRequired;

  const _EtapeInfo(this.code, this.label, this.icon, {required this.photoRequired});
}

const _etapes = [
  _EtapeInfo('DEPART', 'Départ', Icons.flight_takeoff_rounded, photoRequired: true),
  _EtapeInfo('TRANSIT', 'Transit', Icons.sync_alt_rounded, photoRequired: false),
  _EtapeInfo('ARRIVEE', 'Arrivée', Icons.flight_land_rounded, photoRequired: true),
];

class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key});

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg, DonySpacing.xl, DonySpacing.lg, DonySpacing.huge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripHeroCard(),
            const SizedBox(height: DonySpacing.xl),
            _EtapesSection(),
            const SizedBox(height: DonySpacing.xl),
            _QuickActionsSection(),
          ],
        ),
      ),
    );
  }
}

class _TripHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = _TripStub.scannedDepart / _TripStub.totalColis;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.8),
          ],
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
            _TripStub.corridor,
            style: tt.headlineMedium?.copyWith(
              color: DonyColors.neutral0,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${_TripStub.date} · ${_TripStub.totalColis} colis confirmés',
            style: tt.bodySmall?.copyWith(
              color: DonyColors.neutral0.withValues(alpha: 0.75),
            ),
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
                      '${_TripStub.scannedDepart} / ${_TripStub.totalColis}',
                      style: tt.labelSmall?.copyWith(
                        color: DonyColors.neutral0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DonySpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
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

class _EtapesSection extends StatelessWidget {
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
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: e.code == 'ARRIVEE' ? 0 : DonySpacing.sm,
                      ),
                      child: _EtapeChip(etape: e),
                    ),
                  ))
              .toList(),
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

    return GestureDetector(
      onTap: () => context.push(
        '/tracking/scan/identify',
        extra: <String, dynamic>{'etape': etape.code, 'focusNumber': false},
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md,
          horizontal: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(etape.icon, size: 22, color: cs.onSurface),
                if (etape.photoRequired)
                  Positioned(
                    top: -2,
                    right: -8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              etape.label,
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              etape.photoRequired ? 'obligatoire' : 'optionnelle',
              style: tt.labelSmall?.copyWith(
                fontSize: 9,
                color: etape.photoRequired ? cs.error : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
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
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: tt.labelSmall?.copyWith(
                fontSize: 9,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
