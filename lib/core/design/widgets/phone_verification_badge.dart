import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/phone/phone_verification_level.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Pastille de fiabilité d'un numéro de téléphone : « Vérifié » (code SMS),
/// « Vérifié par Yadony » (numéro déclaré, vérifié à la main par l'équipe) ou
/// « Non vérifié » (numéro seulement déclaré). Couleurs unies : vert, bleu,
/// gris, jamais deux niveaux de la même teinte. Le libellé tient sur une ligne.
class PhoneVerificationBadge extends StatelessWidget {
  const PhoneVerificationBadge(this.level, {super.key});

  final PhoneVerificationLevel level;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final (label, icon, bg, fg) = switch (level) {
      PhoneVerificationLevel.sms => (
        l.phoneVerificationSms,
        'badge-check',
        cs.successLight,
        cs.success,
      ),
      PhoneVerificationLevel.yadony => (
        l.phoneVerificationYadony,
        'shield-check',
        cs.infoLight,
        cs.info,
      ),
      PhoneVerificationLevel.none => (
        l.phoneVerificationNone,
        'circle-x',
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
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
            DonyIcon(icon, size: 13, color: fg),
            const SizedBox(width: DonySpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
