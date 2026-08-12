import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// CTA profil : active la capacité « paiements par carte » (Stripe Connect).
///
/// Remplace l'ancien `BecomeTravelerCtaCard` — le rôle voyageur est
/// désormais universel, seule la capacité carte reste à activer.
///
/// Visible uniquement tant que [stripeStatus] n'est pas
/// `'ONBOARDING_COMPLETE'`. Placement : haut de `_AccountTab` (avant
/// IDENTITÉ & CONTACT), comme l'ancienne carte.
class ActivateCardPaymentsCtaCard extends StatelessWidget {
  const ActivateCardPaymentsCtaCard({super.key, required this.stripeStatus});

  final String? stripeStatus;

  @override
  Widget build(BuildContext context) {
    if (stripeStatus == 'ONBOARDING_COMPLETE') {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;

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
          onTap: () => context.push('/payments/onboarding'),
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
                  child: const DonyIcon(
                    'credit-card',
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
                        'Activer les paiements par carte',
                        style: tt.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        'Recevez des paiements sécurisés avec séquestre, '
                        'en plus des espèces',
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chevron trailing ────────────────────────────────────────
                const SizedBox(width: DonySpacing.sm),
                DonyIcon(
                  'chevron-right',
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
