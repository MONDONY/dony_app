import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Codes de raison envoyés au back (liste fermée côté serveur, voir
/// `KycService.ABANDON_REASONS`). `TECHNICAL` et `LATER` s'ajoutent ici aux
/// trois premiers ; « Autre » n'est pas proposé : mieux vaut « Passer ».
const kycAbandonReasonCodes = <String>[
  'NO_DOCUMENT',
  'PRIVACY',
  'TOO_LONG',
  'TECHNICAL',
  'LATER',
];

/// Feuille posée quand l'utilisateur quitte la vérification d'identité après
/// avoir vu la page du fournisseur. Rend le code de la raison choisie, ou
/// `null` s'il passe ou glisse la feuille. Aucun bouton dans le `child` : le
/// seul bouton (« Passer ») vit dans `stickyBottom`.
Future<String?> showKycAbandonReasonSheet(BuildContext context) {
  final l = context.l10n;
  return DonyBottomSheet.show<String>(
    context,
    title: l.kycAbandonSheetTitle,
    subtitle: l.kycAbandonSheetSubtitle,
    analyticsName: 'kyc_abandon_reason',
    child: const _ReasonList(),
    stickyBottom: Builder(
      builder: (ctx) => DonyButton(
        key: const Key('kyc-abandon-skip'),
        label: l.kycAbandonSkip,
        variant: DonyButtonVariant.ghost,
        onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
      ),
    ),
  );
}

/// Icône (SVG Lucide de `assets/icons/`) de chaque raison : on reconnaît la
/// raison d'un coup d'œil avant de lire la phrase.
const _reasonIcons = <String, String>{
  'NO_DOCUMENT': 'id-card',
  'PRIVACY': 'eye-off',
  'TOO_LONG': 'hourglass',
  'TECHNICAL': 'circle-alert',
  'LATER': 'clock',
};

class _ReasonList extends StatelessWidget {
  const _ReasonList();

  String _label(BuildContext context, String code) {
    final l = context.l10n;
    return switch (code) {
      'NO_DOCUMENT' => l.kycAbandonReasonNoDocument,
      'PRIVACY' => l.kycAbandonReasonPrivacy,
      'TOO_LONG' => l.kycAbandonReasonTooLong,
      'TECHNICAL' => l.kycAbandonReasonTechnical,
      _ => l.kycAbandonReasonLater,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, code) in kycAbandonReasonCodes.indexed)
            DonyListTile(
              key: Key('kyc-abandon-reason-$code'),
              iconAsset: _reasonIcons[code] ?? 'circle-help',
              iconColor: cs.primary,
              iconBgColor: cs.primary.withValues(alpha: 0.10),
              label: _label(context, code),
              showDivider: i < kycAbandonReasonCodes.length - 1,
              onTap: () => Navigator.of(context, rootNavigator: true).pop(code),
            ),
        ],
      ),
    );
  }
}
