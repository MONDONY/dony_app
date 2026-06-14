import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Prominent gradient CTA card inviting non-travelers to become travelers.
///
/// Placement: top of _AccountTab (before CONTACT & SÉCURITÉ), shown only
/// when `isTraveler == false`.
class BecomeTravelerCtaCard extends StatelessWidget {
  const BecomeTravelerCtaCard({
    super.key,
    required this.onTap,
    this.kycStatus,
    this.stripeStatus,
  });

  final VoidCallback onTap;
  final String? kycStatus;
  final String? stripeStatus;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final kycOk = kycStatus == 'VERIFIED';
    final stripeOk = stripeStatus == 'ONBOARDING_COMPLETE';
    final allDone = kycOk && stripeOk;
    final done = (kycOk ? 1 : 0) + (stripeOk ? 1 : 0);

    final String statusText;
    if (allDone) {
      statusText = 'Dossier complet — prêt à voyager';
    } else if (done == 0) {
      statusText = '2 étapes pour commencer';
    } else {
      statusText = '$done/2 étapes complétées';
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DonyColors.blue500, DonyColors.blue700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DonyRadius.card),
          boxShadow: [
            BoxShadow(
              color: DonyColors.blue500.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            child: Row(
              children: [
                // ── Icône dans un pill translucide ──────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(DonyRadius.xl),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: DonySpacing.md),

                // ── Textes ──────────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Devenir voyageur',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        'Transporte des colis, gagne de l\'argent',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs),
                      // Status sub-line
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 12,
                            color: allDone
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            statusText,
                            style: tt.labelSmall?.copyWith(
                              color: allDone
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Chevron trailing ────────────────────────────────────────
                const SizedBox(width: DonySpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.80),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}
