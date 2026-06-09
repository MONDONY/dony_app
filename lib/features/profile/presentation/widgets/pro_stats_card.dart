import 'dart:ui';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/bloc/pro_stats_bloc.dart';
import 'package:dony/features/profile/data/pro_stats_repository.dart';
import 'package:dony/features/profile/presentation/widgets/pro_stats_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ProStatsCard extends StatelessWidget {
  const ProStatsCard({super.key});

  static Widget withBloc() {
    return BlocProvider(
      create: (_) =>
          ProStatsBloc(getIt<ProStatsRepository>())
            ..add(ProStatsLoadRequested()),
      child: const ProStatsCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProStatsBloc, ProStatsState>(
      builder: (context, state) {
        if (state is ProStatsLoading || state is ProStatsInitial) {
          return _CardShell(child: _LoadingContent());
        }
        if (state is ProStatsError) {
          return _CardShell(
            child: _ErrorContent(
              onRetry: () =>
                  context.read<ProStatsBloc>().add(ProStatsLoadRequested()),
            ),
          );
        }
        if (state is ProStatsLoaded) {
          return _CardShell(
            onTap: () => ProStatsBottomSheet.show(context, stats: state.stats),
            child: _LoadedContent(stats: state.stats),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Shell glassmorphique ──────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Couleurs du dégradé adaptées au mode
    final gradientStart = isDark
        ? DonyColors
              .proBg1 // bleu nuit profond
        : DonyColors.ink800; // ink800
    final gradientEnd = isDark
        ? DonyColors
              .proBg2 // presque noir bleu
        : DonyColors.proBg3; // bleu saphir

    // Opacité du fond glass selon brightness
    final bgAlpha = isDark ? 0.75 : 0.88;
    // Bordure glass
    final borderAlpha = isDark ? 0.10 : 0.18;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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
                  gradientEnd.withValues(alpha: bgAlpha - 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderAlpha),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientStart.withValues(alpha: isDark ? 0.4 : 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Contenu chargé ────────────────────────────────────────────────────────────

class _LoadedContent extends StatelessWidget {
  const _LoadedContent({required this.stats});

  final dynamic stats;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final currencyFmt = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    );
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM', 'fr_FR').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthLabel.toUpperCase(),
              style: tt.labelSmall!.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.8,
              ),
            ),
            _ProBadge(),
          ],
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          currencyFmt.format(stats.monthlyRevenue),
          style: tt.displaySmall!.copyWith(color: Colors.white),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: DonySpacing.xxs),
        Text(
          '${stats.monthlyTrips} trajet${stats.monthlyTrips > 1 ? 's' : ''} · '
          '${stats.monthlyParcelsDelivered} colis livré${stats.monthlyParcelsDelivered > 1 ? 's' : ''}',
          style: tt.bodySmall!.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        Row(
          children: [
            _StatPill(
              label: 'Acceptés',
              value: '${(stats.acceptanceRate * 100).round()}%',
            ),
            const SizedBox(width: DonySpacing.sm),
            _StatPill(
              label: 'Note',
              value: stats.averageRating > 0
                  ? '${stats.averageRating.toStringAsFixed(1)} ★'
                  : '—',
            ),
            const Spacer(),
            Text(
              'Voir plus →',
              style: tt.labelSmall!.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Contenu loading ───────────────────────────────────────────────────────────

class _LoadingContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHARGEMENT…',
          style: tt.labelSmall!.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

// ── Contenu erreur ────────────────────────────────────────────────────────────

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(
          Icons.wifi_off_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 18,
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            'Statistiques indisponibles',
            style: tt.bodySmall!.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: Text(
            'Réessayer',
            style: tt.labelSmall!.copyWith(color: DonyColors.blue200),
          ),
        ),
      ],
    );
  }
}

// ── Pill stat ─────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    // Pill glass : fond blanc très transparent + bordure fine
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: tt.titleSmall!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: tt.labelSmall!.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge PRO ─────────────────────────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: DonyColors.terra500.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: DonyColors.terra500.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'PRO',
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
