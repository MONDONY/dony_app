import 'dart:ui';

import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ProStatsBottomSheet extends StatelessWidget {
  const ProStatsBottomSheet({super.key, required this.stats});

  final ProStatsModel stats;

  static Future<void> show(
    BuildContext context, {
    required ProStatsModel stats,
  }) {
    return DonyBottomSheet.show(
      context,
      title: 'Mes statistiques PRO',
      child: ProStatsBottomSheet(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Devise servie par le backend (totaux convertis dedans), repli cache local.
    final currency =
        SupportedCurrency.fromCode(stats.currency) ??
        ActiveCurrency.current ??
        SupportedCurrency.eur;
    final bool multiCurrency = stats.isMultiCurrency;
    final currencyFmt = NumberFormat.currency(
      locale: currency.locale,
      symbol: currency.symbol,
      decimalDigits: currency.minorUnit,
    );
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero mensuel glass ──────────────────────────────────────────────
        _GlassHeroCard(
              monthLabel: monthLabel,
              revenue:
                  (multiCurrency ? '\u2248 ' : '') +
                  currencyFmt.format(stats.monthlyRevenue),
              trips: stats.monthlyTrips,
              parcels: stats.monthlyParcelsDelivered,
            )
            .animate()
            .fadeIn(delay: 60.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),

        const SizedBox(height: DonySpacing.base),

        // ── Revenus total ───────────────────────────────────────────────────
        _SectionCard(
              child: _MetricRow(
                label: multiCurrency
                    ? 'Revenus total (environ, toutes devises)'
                    : 'Revenus total (depuis le début)',
                value:
                    (multiCurrency ? '\u2248 ' : '') +
                    currencyFmt.format(stats.totalRevenue),
                iconAsset: 'wallet',
              ),
            )
            .animate()
            .fadeIn(delay: 100.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),

        const SizedBox(height: DonySpacing.base),

        // ── Performance ─────────────────────────────────────────────────────
        _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('PERFORMANCE'),
                  const SizedBox(height: DonySpacing.base),
                  _ProgressMetric(
                    label: "Taux d'acceptation",
                    value: stats.acceptanceRate,
                    displayText: '${(stats.acceptanceRate * 100).round()}%',
                    color: cs.primary,
                  ),
                  const SizedBox(height: DonySpacing.md),
                  _ProgressMetric(
                    label: 'Note moyenne',
                    value: stats.averageRating / 5.0,
                    displayText: stats.averageRating > 0
                        ? '${stats.averageRating.toStringAsFixed(1)} / 5.0 ★'
                        : '- / 5.0',
                    // cs.secondary = terra500 en light, adapté en dark
                    color: cs.secondary,
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: 140.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),

        // ── Top destinations ────────────────────────────────────────────────
        if (stats.topDestinations.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('TOP DESTINATIONS'),
                    const SizedBox(height: DonySpacing.base),
                    ...stats.topDestinations.asMap().entries.map((entry) {
                      final i = entry.key;
                      final dest = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < stats.topDestinations.length - 1
                              ? DonySpacing.sm
                              : 0,
                        ),
                        child: _DestinationRow(
                          rank: i + 1,
                          from: dest.from,
                          to: dest.to,
                          count: dest.count,
                        ),
                      );
                    }),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 180.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ],

        const SizedBox(height: DonySpacing.xxl),
      ],
    );
  }
}

// ── Hero mensuel avec glassmorphism ───────────────────────────────────────────

class _GlassHeroCard extends StatelessWidget {
  const _GlassHeroCard({
    required this.monthLabel,
    required this.revenue,
    required this.trips,
    required this.parcels,
  });

  final String monthLabel;
  final String revenue;
  final int trips;
  final int parcels;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientStart = isDark ? DonyColors.proBg1 : DonyColors.ink800;
    final gradientEnd = isDark ? DonyColors.proBg2 : DonyColors.proBg3;
    final bgAlpha = isDark ? 0.80 : 0.90;
    final borderAlpha = isDark ? 0.10 : 0.18;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(DonySpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gradientStart.withValues(alpha: bgAlpha),
                gradientEnd.withValues(alpha: bgAlpha - 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
            boxShadow: [
              BoxShadow(
                color: gradientStart.withValues(alpha: isDark ? 0.4 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monthLabel.toUpperCase(),
                style: tt.labelSmall!.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                revenue,
                style: tt.headlineLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                'Revenus net ce mois',
                style: tt.bodySmall!.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
              Row(
                children: [
                  Expanded(
                    child: _GlassTile(
                      label: 'Trajets',
                      value: trips.toString(),
                      iconAsset: 'plane-takeoff',
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: _GlassTile(
                      label: 'Colis livrés',
                      value: parcels.toString(),
                      iconAsset: 'package',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tuile métrique à l'intérieur du hero glass
class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.label,
    required this.value,
    required this.iconAsset,
  });

  final String label;
  final String value;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DonyIcon(
                iconAsset,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(height: DonySpacing.xs),
              Text(
                value,
                style: tt.titleLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: tt.labelSmall!.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Composants sections standards ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: child,
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.iconAsset,
  });

  final String label;
  final String value;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DonySpacing.sm),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: DonyIcon(iconAsset, color: cs.primary, size: 20),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(
            label,
            style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: tt.titleMedium!.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.displayText,
    required this.color,
  });

  final String label;
  final double value;
  final String displayText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final clampedValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: tt.bodySmall!.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              displayText,
              style: tt.labelMedium!.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.full),
          child: LinearProgressIndicator(
            value: clampedValue,
            minHeight: 8,
            backgroundColor: cs.outline.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.rank,
    required this.from,
    required this.to,
    required this.count,
  });

  final int rank;
  final String from;
  final String to;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$rank.',
            style: tt.labelSmall!.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        DonyIcon('plane', size: 14, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Expanded(
          child: Text(
            '$from → $to',
            style: tt.bodySmall!.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DonyBadge(label: '$count trajet${count > 1 ? 's' : ''}'),
      ],
    );
  }
}
