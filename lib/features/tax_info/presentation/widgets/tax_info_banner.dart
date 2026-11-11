import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bannière discrète du Profil : une demande d'informations fiscales (DAC7),
/// jamais bloquante. « Compléter » ouvre l'écran, « Plus tard » masque la
/// bannière pour la session, sans rien enregistrer.
///
/// Les deux actions sont des liens texte courts, sur une ligne, côte à côte.
class TaxInfoBanner extends StatelessWidget {
  const TaxInfoBanner({super.key, required this.onOpen, required this.onLater});

  final VoidCallback onOpen;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);
    return DonyStatusBanner(
      key: const Key('tax-info-banner'),
      type: DonyStatusBannerType.info,
      iconAsset: 'landmark',
      title: l.taxInfoBannerTitle,
      message: l.taxInfoBannerBody,
      // `Wrap` : si le texte agrandi ne tient pas côte à côte, « Plus tard »
      // passe dessous, chaque libellé restant sur une ligne.
      action: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            key: const Key('tax-info-banner-open'),
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              minimumSize: const Size(0, kDonyMinTapTarget),
              padding: const EdgeInsets.only(right: DonySpacing.md),
            ),
            child: Text(
              l.taxInfoBannerAction,
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          ),
          TextButton(
            key: const Key('tax-info-banner-later'),
            onPressed: onLater,
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              minimumSize: const Size(0, kDonyMinTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
            ),
            child: Text(
              l.taxInfoLater,
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
