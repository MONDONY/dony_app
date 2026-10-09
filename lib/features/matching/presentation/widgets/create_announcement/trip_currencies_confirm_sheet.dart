import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Étape d'un voyage telle que la confirmation l'affiche.
class TripCurrencyLine {
  const TripCurrencyLine({required this.route, required this.currency});

  /// « Paris → Abidjan ».
  final String route;
  final SupportedCurrency currency;
}

/// Confirmation avant de publier un voyage dont les étapes n'ont pas toutes
/// la même devise (FLUTTER-HP).
///
/// La devise d'une étape se déduit de son pays de départ : un voyageur peut
/// ne pas voir qu'une étape part en F CFA alors que la première est en euros.
/// Les prix ne sont jamais convertis, il le confirme donc étape par étape.
abstract final class TripCurrenciesConfirmSheet {
  /// Vrai si les étapes de [lines] ont au moins deux devises différentes.
  static bool needed(List<TripCurrencyLine> lines) =>
      lines.map((e) => e.currency.code).toSet().length > 1;

  /// Rend `true` si le voyageur confirme, `false` sinon (« Revoir les
  /// étapes », fermeture par geste).
  static Future<bool> show(
    BuildContext context, {
    required List<TripCurrencyLine> lines,
  }) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.tripCurrenciesConfirmTitle,
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('trip-currencies-confirm'),
              label: l.tripCurrenciesConfirmCta,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('trip-currencies-edit'),
              label: l.tripCurrenciesConfirmEdit,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: _Lines(lines: lines),
    );
    return confirmed ?? false;
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines});

  final List<TripCurrencyLine> lines;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.tripCurrenciesConfirmMessage,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.md),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: DonySpacing.sm),
            Container(
              key: Key('trip-currencies-line-$i'),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.tripCurrenciesConfirmLeg(i + 1, lines[i].route),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Semantics(
                    label: lines[i].currency.name(l),
                    excludeSemantics: true,
                    child: Text(
                      lines[i].currency.symbol,
                      maxLines: 1,
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
