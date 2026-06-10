import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// TripCard — carte trajet voyageur (Mes trajets)
//
// Design direction: « Éditorial calme »
// • Hiérarchie typographique forte : route en titre Hanken Grotesk bold,
//   métadonnées en corps léger.
// • Timeline de vol visuelle (drapeaux → dashed line → avion → drapeaux).
// • Barre de progression animée : kgs vendus / total, couleur du système.
// • Passé (COMPLETED / CANCELLED) : opacité réduite, footer condensé,
//   pas de timeline ni de progression → cognition allégée.
// • Motion : fadeIn + slideY staggeré par index, easeOutCubic 300 ms.
// ─────────────────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.announcement,
    required this.onTap,
    required this.index,
  });

  final AnnouncementModel announcement;
  final VoidCallback onTap;
  final int index;

  bool get _isPast =>
      announcement.status == 'COMPLETED' ||
      announcement.status == 'CANCELLED';

  /// Returns (bgColor, fgColor, label, shouldPulse) for the status badge.
  ({Color bg, Color fg, String label, bool pulse}) _badge(ColorScheme cs) =>
      switch (announcement.status) {
        'ACTIVE' => (
            bg: cs.successLight,
            fg: cs.success,
            label: 'Actif',
            pulse: true
          ),
        'IN_PROGRESS' => (
            bg: cs.infoLight,
            fg: cs.info,
            label: 'En cours',
            pulse: true
          ),
        'FULL' => (
            bg: cs.warningLight,
            fg: cs.warning,
            label: 'Complet',
            pulse: false
          ),
        'COMPLETED' => (
            bg: DonyColors.neutral100,
            fg: cs.onSurfaceVariant,
            label: 'Terminé',
            pulse: false
          ),
        'CANCELLED' => (
            bg: cs.errorLight,
            fg: cs.error,
            label: 'Annulé',
            pulse: false
          ),
        _ => (
            bg: DonyColors.neutral100,
            fg: cs.onSurfaceVariant,
            label: announcement.status,
            pulse: false
          ),
      };

  /// Human-readable date label relative to today.
  String _dateLabel() {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(announcement.departureDate);
    final diff = d.difference(today).inDays;
    final dateStr =
        DateFormat('d MMM', 'fr').format(announcement.departureDate);
    if (diff == 0) {
      return "Aujourd'hui · $dateStr";
    }
    if (diff == 1) {
      return 'Demain · $dateStr';
    }
    if (diff > 1 && diff <= 6) {
      return 'Départ dans $diff jours · $dateStr';
    }
    return DateFormat('EEE d MMM yyyy', 'fr').format(announcement.departureDate);
  }

  /// Formats a kg value: drops .0 suffix for whole numbers.
  String _kg(double v) =>
      '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)} kg';

  /// Formats price: drops .00 suffix for whole numbers.
  String _price(double v) =>
      v.truncateToDouble() == v
          ? '${v.toStringAsFixed(0)} €'
          : '${v.toStringAsFixed(2)} €';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final badge = _badge(cs);
    final totalKg = announcement.totalKg;
    final availableKg = announcement.availableKg;
    final soldKg = (totalKg - availableKg).clamp(0, totalKg).toDouble();
    final progress = totalKg > 0 ? (soldKg / totalKg).clamp(0.0, 1.0) : 0.0;

    // Préfère le drapeau résolu par le backend (n'importe quel pays), retombe
    // sur la map hardcodée locale, puis null (point bleu via _FlagEndpoint).
    final depFlag =
        announcement.departureFlag ?? cityFlag(announcement.departureCity);
    final arrFlag =
        announcement.arrivalFlag ?? cityFlag(announcement.arrivalCity);

    Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
          boxShadow: const [
            BoxShadow(
              color: DonyColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        // No outer padding; each section manages its own rhythm.
        child: _isPast
            ? _PastCardContent(
                announcement: announcement,
                badge: badge,
                soldKg: soldKg,
                kg: _kg,
                price: _price,
                dateLabel: _dateLabel(),
              )
            : _ActiveCardContent(
                announcement: announcement,
                badge: badge,
                soldKg: soldKg,
                totalKg: totalKg,
                availableKg: availableKg,
                progress: progress,
                depFlag: depFlag,
                arrFlag: arrFlag,
                dateLabel: _dateLabel(),
                kg: _kg,
                price: _price,
              ),
      ),
    );

    if (_isPast) {
      card = Opacity(opacity: 0.65, child: card);
    }

    return card
        .animate(delay: Duration(milliseconds: DonyCurve.staggerMs * index))
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────
// Active card content
// ─────────────────────────────────────────────────────────────

class _ActiveCardContent extends StatelessWidget {
  const _ActiveCardContent({
    required this.announcement,
    required this.badge,
    required this.soldKg,
    required this.totalKg,
    required this.availableKg,
    required this.progress,
    required this.depFlag,
    required this.arrFlag,
    required this.dateLabel,
    required this.kg,
    required this.price,
  });

  final AnnouncementModel announcement;
  final ({Color bg, Color fg, String label, bool pulse}) badge;
  final double soldKg;
  final double totalKg;
  final double availableKg;
  final double progress;
  final String? depFlag;
  final String? arrFlag;
  final String dateLabel;
  final String Function(double) kg;
  final String Function(double) price;

  /// Builds the optional « demandes » stats row (acceptées / en attente).
  /// Returns an empty list when both counts are 0 so the card stays clean and
  /// no extra spacing is emitted; otherwise prepends its own top spacing and
  /// the chip row (the trailing rhythm is handled by the caller's SizedBox).
  List<Widget> _buildBidStatsRow(ColorScheme cs) {
    final accepted = announcement.confirmedParcelCount;
    final pending = announcement.pendingBidCount;
    if (accepted <= 0 && pending <= 0) {
      return const [];
    }

    String plural(int n, String one, String many) => n == 1 ? one : many;

    return [
      const SizedBox(height: DonySpacing.sm),
      Wrap(
        spacing: DonySpacing.xs,
        runSpacing: DonySpacing.xs,
        children: [
          if (accepted > 0)
            _BidStatChip(
              icon: Icons.check_circle_rounded,
              fg: cs.success,
              bg: cs.successLight,
              label: '$accepted ${plural(accepted, 'acceptée', 'acceptées')}',
            ),
          if (pending > 0)
            _BidStatChip(
              icon: Icons.schedule_rounded,
              fg: cs.warning,
              bg: cs.warningLight,
              label: '$pending en attente',
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row: route title + badge ──
          Row(
            children: [
              Expanded(
                child: _RouteTitle(
                  departure: announcement.departureCity,
                  arrival: announcement.arrivalCity,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatusBadge(badge: badge),
            ],
          ),

          const SizedBox(height: DonySpacing.xs),

          // ── Date sub-label ──
          Text(
            dateLabel,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),

          // ── Demandes stats row (acceptées / en attente) ──
          // Rendered only when at least one count > 0 — keeps demand-free
          // cards visually clean. Emits its own trailing spacing.
          ..._buildBidStatsRow(cs),

          const SizedBox(height: DonySpacing.md),

          // ── Flight timeline ──
          _FlightTimeline(depFlag: depFlag, arrFlag: arrFlag),

          const SizedBox(height: DonySpacing.md),

          // ── Progress bar (hidden for KG_FREE) ──
          if (!announcement.isKgFree) ...[
            _KgProgressBar(progress: progress),

            const SizedBox(height: DonySpacing.xs),

            Text(
              '${kg(soldKg)} vendus sur ${kg(totalKg)}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: DonySpacing.md),
          ] else
            const SizedBox(height: DonySpacing.md),

          // ── Divider ──
          Divider(height: 1, thickness: 1, color: cs.outline),

          const SizedBox(height: DonySpacing.md),

          // ── Footer: available kg + price ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    announcement.isKgFree
                        ? 'Kg libre'
                        : '${kg(availableKg)} disponibles',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${price(announcement.pricePerKg)} / kg',
                style: tt.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Past card content (COMPLETED / CANCELLED)
// ─────────────────────────────────────────────────────────────

class _PastCardContent extends StatelessWidget {
  const _PastCardContent({
    required this.announcement,
    required this.badge,
    required this.soldKg,
    required this.kg,
    required this.price,
    required this.dateLabel,
  });

  final AnnouncementModel announcement;
  final ({Color bg, Color fg, String label, bool pulse}) badge;
  final double soldKg;
  final String Function(double) kg;
  final String Function(double) price;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isCompleted = announcement.status == 'COMPLETED';
    final earned = soldKg * announcement.pricePerKg;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RouteTitle(
                  departure: announcement.departureCity,
                  arrival: announcement.arrivalCity,
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  dateLabel,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.xs),
                // Condensed footer
                Row(
                  children: [
                    Text(
                      announcement.isKgFree ? 'Kg libre' : '${kg(soldKg)} vendus',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!announcement.isKgFree && isCompleted && soldKg > 0) ...[
                      Text(
                        ' · ',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${earned.toStringAsFixed(0)} € gagnés',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          _StatusBadge(badge: badge),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _RouteTitle — departure → arrival in bold Hanken Grotesk
// ─────────────────────────────────────────────────────────────

class _RouteTitle extends StatelessWidget {
  const _RouteTitle({
    required this.departure,
    required this.arrival,
  });

  final String departure;
  final String arrival;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            departure,
            style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: cs.primary,
          ),
        ),
        Flexible(
          child: Text(
            arrival,
            style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _StatusBadge — pill with optional pulsing dot
// ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.badge});

  final ({Color bg, Color fg, String label, bool pulse}) badge;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: badge.fg,
        shape: BoxShape.circle,
      ),
    );

    if (badge.pulse) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 1, end: 0.3, duration: 600.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: tt.labelMedium?.copyWith(
              color: badge.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _BidStatChip — compact informational chip (acceptées / en attente)
// Non-interactive: no onTap, no 44px touch target required.
// ─────────────────────────────────────────────────────────────

class _BidStatChip extends StatelessWidget {
  const _BidStatChip({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.label,
  });

  final IconData icon;
  final Color fg;
  final Color bg;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _FlightTimeline — flag → dashed line with plane → flag
// ─────────────────────────────────────────────────────────────

class _FlightTimeline extends StatelessWidget {
  const _FlightTimeline({
    required this.depFlag,
    required this.arrFlag,
  });

  final String? depFlag;
  final String? arrFlag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        _FlagEndpoint(flag: depFlag),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              const CustomPaint(
                size: Size(double.infinity, 2),
                painter: _DashedLinePainter(color: DonyColors.blue200),
              ),
              // Plane icon rotated to point right (Icons.flight points up by default)
              RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.flight_rounded,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        _FlagEndpoint(flag: arrFlag),
      ],
    );
  }
}

class _FlagEndpoint extends StatelessWidget {
  const _FlagEndpoint({required this.flag});

  final String? flag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (flag != null) {
      return Text(flag!, style: const TextStyle(fontSize: 16));
    }
    // Fallback blue dot for unknown cities
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _DashedLinePainter — horizontal dashed rule
// ─────────────────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashGap = 5.0;
    double x = 0;
    final y = size.height / 2;

    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashWidth).clamp(0, size.width), y),
        paint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────
// _KgProgressBar — animated fill 0→progress
// ─────────────────────────────────────────────────────────────

class _KgProgressBar extends StatelessWidget {
  const _KgProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.full),
      child: Container(
        height: 6,
        color: cs.outline,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * value,
                    height: 6,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
