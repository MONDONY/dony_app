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
/// `'ONBOARDING_COMPLETE'`, que [connectAvailable] est vrai et que
/// [identityVerified] l'est aussi. Placement : haut de `_AccountTab` (avant
/// IDENTITÉ & CONTACT), comme l'ancienne carte.
///
/// La carte porte son propre écart bas : masquée, elle occupe exactement zéro
/// place, et l'appelant n'a pas à rejouer sa règle de visibilité pour décider
/// s'il doit intercaler un espacement.
class ActivateCardPaymentsCtaCard extends StatelessWidget {
  const ActivateCardPaymentsCtaCard({
    super.key,
    required this.stripeStatus,
    required this.connectAvailable,
    required this.identityVerified,
  });

  final String? stripeStatus;

  /// Stripe couvre-t-il le pays de l'utilisateur ? Faux pour les zones XOF et
  /// XAF, les États-Unis et le Canada : proposer l'activation y mènerait à un
  /// refus, autant ne rien proposer.
  ///
  /// Se lit sur `StripeAccountState.connectAvailableInCountry`, qui porte le
  /// repli « disponible tant que le statut n'est pas chargé ».
  final bool connectAvailable;

  /// L'identité est-elle vérifiée ? Stripe Connect n'ouvre pas de compte sans
  /// elle (le serveur refuse par un 422 `kyc-required`). Tant qu'elle manque,
  /// cette carte laisse la place au CTA de vérification d'identité, qui est la
  /// vraie prochaine action : deux bannières concurrentes en tête de profil
  /// n'apprendraient à personne laquelle vient d'abord.
  final bool identityVerified;

  @override
  Widget build(BuildContext context) {
    if (stripeStatus == 'ONBOARDING_COMPLETE' ||
        !connectAvailable ||
        !identityVerified) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Material(
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
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}
