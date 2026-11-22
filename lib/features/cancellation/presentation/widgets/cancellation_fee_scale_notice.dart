import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/data/cancellation_fee_scale.dart';
import 'package:dony/features/cancellation/presentation/widgets/cancellation_fee_config_builder.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Ligne d'information au-dessus du bouton de paiement d'un colis : « des
/// frais peuvent s'appliquer après acceptation par le voyageur », suivie de
/// « Voir le barème » qui ouvre la feuille du barème.
///
/// Invisible (aucune place prise) tant que la configuration n'est pas lue,
/// frais éteints, route absente (back antérieur), date d'effet pas encore
/// passée ou paliers illisibles : l'écran reste celui d'avant la fonction. À
/// poser seulement pour un paiement en ligne (carte, mobile money), jamais en
/// espèces. [clock] : horloge de la date d'effet (tests).
class CancellationFeeScaleNotice extends StatelessWidget {
  const CancellationFeeScaleNotice({
    super.key,
    this.clock,
    this.source = 'bid_checkout',
  });

  final DateTime Function()? clock;

  /// Origine de l'ouverture, pour l'analytics.
  final String source;

  @override
  Widget build(BuildContext context) {
    return CancellationFeeConfigBuilder(
      builder: (ctx, config) {
        final scale = CancellationFeeScale.fromConfig(
          config,
          now: (clock ?? DateTime.now)(),
        );
        if (scale == null) return const SizedBox.shrink();
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        final l = ctx.l10n;
        return Semantics(
          button: true,
          child: InkWell(
            key: const Key('cancel-fee-scale-notice'),
            borderRadius: BorderRadius.circular(DonyRadius.md),
            onTap: () => _openScale(ctx, scale),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DonyIcon(
                      'info',
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${l.cancelScaleNoticeText} ',
                        children: [
                          TextSpan(
                            text: l.cancelScaleNoticeLink,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openScale(BuildContext context, CancellationFeeScale scale) {
    if (getIt.isRegistered<AnalyticsService>()) {
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.cancellationFeeScaleOpened,
          properties: {'source': source},
        ),
      );
    }
    showCancellationFeeScaleSheet(context, scale);
  }
}

/// Feuille du barème : une phrase par palier (de la configuration), le
/// plafond, puis deux précisions. Le contenu défile, « OK » reste au pied.
Future<void> showCancellationFeeScaleSheet(
  BuildContext context,
  CancellationFeeScale scale,
) {
  final l = context.l10n;
  return DonyBottomSheet.show<void>(
    context,
    title: l.cancelScaleSheetTitle,
    analyticsName: 'cancellation/fee-scale',
    stickyBottom: Builder(
      builder: (ctx) => DonyButton(
        key: const Key('cancel-fee-scale-close'),
        label: ctx.l10n.commonOk,
        onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
      ),
    ),
    child: _CancellationFeeScaleContent(scale: scale),
  );
}

class _CancellationFeeScaleContent extends StatelessWidget {
  const _CancellationFeeScaleContent({required this.scale});

  final CancellationFeeScale scale;

  static String _sentence(AppLocalizations l, CancellationFeeScaleRow r) {
    switch (r.kind) {
      case CancellationFeeScaleKind.moreThan:
        return l.cancelScaleMoreThan(r.days, r.percent);
      case CancellationFeeScaleKind.between:
        return l.cancelScaleBetween(r.fromDays ?? r.days, r.days, r.percent);
      case CancellationFeeScaleKind.lessThan:
        return l.cancelScaleLessThan(r.days, r.percent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final cap = scale.capEur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in scale.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: Text(_sentence(l, row), style: tt.bodyMedium),
          ),
        if (cap != null)
          Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.sm),
            child: Text(
              l.cancelScaleCap(formatPriceIn(cap, 'EUR')),
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.cancelScaleExactAmount,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.cancelScaleCashNote,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
