import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Confirmation avant de basculer la devise du voyage depuis la notice mobile
/// money de l'étape Prix (FLUTTER-GK).
///
/// Les montants saisis ne sont pas convertis : 8 €/kg devient 8 F CFA/kg. Le
/// voyageur doit donc le savoir avant, ainsi que la perte de la carte quand la
/// devise cible ne la propose pas (zone CFA).
///
/// Voyage à plusieurs étapes (FLUTTER-HP) : seul le premier trajet change de
/// devise, chaque étape ajoutée garde la sienne ([legCurrencies]) ; le message
/// le dit au lieu d'annoncer « tous les prix du voyage ».
abstract final class CurrencySwitchConfirmSheet {
  /// Rend `true` si le voyageur confirme, `false` sinon (annulation,
  /// fermeture par geste).
  static Future<bool> show(
    BuildContext context, {
    required SupportedCurrency target,
    List<SupportedCurrency> legCurrencies = const [],
  }) async {
    final l = context.l10n;
    final legs = {
      for (final c in legCurrencies) c.code: c.symbol,
    }.values.join(', ');
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.tripSwitchCurrencyConfirmTitle(target.symbol),
      stickyBottom: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('currency-switch-confirm'),
              label: l.commonConfirm,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('currency-switch-cancel'),
              label: l.commonCancel,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
      child: Builder(
        builder: (ctx) {
          final tt = Theme.of(ctx).textTheme;
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: const EdgeInsets.only(bottom: DonySpacing.base),
            child: Text(
              switch ((legs.isEmpty, target.isStripeEligible)) {
                (true, true) => l.tripSwitchCurrencyConfirmMessage(
                  target.symbol,
                ),
                (true, false) => l.tripSwitchCurrencyConfirmMessageNoCard(
                  target.symbol,
                ),
                (false, true) => l.tripSwitchCurrencyConfirmMessageLegs(
                  target.symbol,
                  legs,
                ),
                (false, false) => l.tripSwitchCurrencyConfirmMessageLegsNoCard(
                  target.symbol,
                  legs,
                ),
              },
              key: const Key('currency-switch-message'),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        },
      ),
    );
    return confirmed ?? false;
  }
}
