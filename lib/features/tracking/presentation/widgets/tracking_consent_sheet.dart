import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille d'explication avant la demande de position du système : ce que
/// voit l'expéditeur, que c'est facultatif et limité à l'usage de l'app.
///
/// Rend `true` (Autoriser), `false` (Pas maintenant) ou `null` (fermée par un
/// geste, comptée comme un refus par [TrackingConsentCubit]).
abstract final class TrackingConsentSheet {
  static Future<bool?> show(BuildContext context) {
    final l = context.l10n;
    return DonyBottomSheet.show<bool>(
      context,
      title: l.trackingConsentTitle,
      analyticsName: 'tracking/consent',
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('tracking-consent-accept'),
              label: l.trackingConsentAccept,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('tracking-consent-decline'),
              label: l.trackingConsentDecline,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: const _TrackingConsentBody(),
    );
  }
}

class _TrackingConsentBody extends StatelessWidget {
  const _TrackingConsentBody();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final body = tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant);
    final points = [
      l.trackingConsentPointApproximate,
      l.trackingConsentPointOptional,
      l.trackingConsentPointWhileUsing,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.trackingConsentIntro, style: tt.bodyMedium),
          const SizedBox(height: DonySpacing.md),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: body),
                  Expanded(child: Text(point, style: body)),
                ],
              ),
            ),
          const SizedBox(height: DonySpacing.sm),
          Text(l.trackingConsentChangeLater, style: body),
        ],
      ),
    );
  }
}
