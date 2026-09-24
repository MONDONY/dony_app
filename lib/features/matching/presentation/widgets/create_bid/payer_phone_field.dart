import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

// ── Numéro payeur mobile money ──────────────────────────────────────────────
//
// Affiché uniquement quand le mode mobile money est sélectionné. Le numéro
// reste modifiable/effaçable par l'expéditeur (jamais requis pour
// soumettre) : un champ vide envoie `phoneNumber: null`, et le backend
// replie alors sur le téléphone Firebase de l'expéditeur. Un champ de saisie
// et un texte d'aide, jamais de DonyButton ici — reste dans le `child`
// scrollable du picker, jamais dans le _StickyBottom.
//
// Extrait de `create_bid_bottom_sheet.dart` (widget public réutilisé par le
// récapitulatif d'un fil de négociation).
class PayerPhoneField extends StatelessWidget {
  const PayerPhoneField({
    super.key,
    required this.controller,
    required this.hasProfilePhone,
  });

  final TextEditingController controller;

  /// Faux quand `_initialPayerPhone()` était vide (compte Yadony sans
  /// numéro de téléphone) : le texte d'aide ne peut alors plus affirmer un
  /// pré-remplissage qui n'a pas eu lieu.
  final bool hasProfilePhone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DonyTextField(
          key: const Key('payer-phone-field'),
          controller: controller,
          label: context.l10n.bidCreatePayerPhoneLabel,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: DonySpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DonyIcon('smartphone', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Text(
                hasProfilePhone
                    ? context.l10n.bidCreatePayerPhoneHintWithProfile
                    : context.l10n.bidCreatePayerPhoneHintNoProfile,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
