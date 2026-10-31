import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_gain.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Détail du gain estimé du trajet du voyageur, bloc « Gain estimé » en tête
/// du sheet « Colis » (`openTripActivitySheet`), d'après [TripGain]
/// (`tripGainOf`) : les colis récupérés, espèces comprises.
///
/// Trois lignes au plus, chacune seulement si son montant est positif :
/// - « En ligne » : net des colis payés dans l'app, versé après la livraison
///   de chacun ;
/// - « En espèces » : net des colis payés en espèces, avec ce que
///   l'expéditeur remet en main propre. La commission n'est pas déduite de
///   l'argent remis : le voyageur l'a avancée à part sur son solde, comme le
///   dit la carte de gain de la fiche colis (FLUTTER-R8) ;
/// - « Total estimé » : les deux.
///
/// Rien sans gain (le bloc n'est alors pas monté). Lecture seule.
class TripGainContent extends StatelessWidget {
  const TripGainContent({super.key, required this.gain});

  final TripGain gain;

  @override
  Widget build(BuildContext context) {
    if (!gain.hasGain) return const SizedBox.shrink();
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final currency = SupportedCurrency.fromCodeOrDefault(gain.currency);
    String money(double amount) => CurrencyFormatter.format(amount, currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gain.hasOnline) ...[
          _GainLine(
            id: 'online',
            label: l.tripGainOnlineLabel,
            amount: money(gain.online),
            note: l.tripSummaryEarningsNote,
          ),
          const SizedBox(height: DonySpacing.base),
        ],
        if (gain.hasCash) ...[
          _GainLine(
            id: 'cash',
            label: l.tripGainCashLabel,
            amount: money(gain.cash),
            // Brut distinct du net : l'expéditeur remet aussi la commission
            // que le voyageur a avancée. Sinon (ancien back), la note seule.
            note: gain.hasCashCommission
                ? l.tripGainCashGrossNote(
                    money(gain.cashGross),
                    money(gain.cashCommission),
                  )
                : l.tripGainCashNote,
          ),
          const SizedBox(height: DonySpacing.base),
        ],
        Divider(height: 1, color: cs.outline),
        const SizedBox(height: DonySpacing.base),
        _GainLine(
          id: 'total',
          label: l.tripGainTotalLabel,
          amount: money(gain.total),
          emphasized: true,
        ),
      ],
    );
  }
}

/// Une ligne du détail : libellé à gauche, montant à droite (chiffres
/// tabulaires, sur une ligne, rétréci plutôt que passé à la ligne comme la
/// carte de gain de la fiche colis), puis sa note.
class _GainLine extends StatelessWidget {
  const _GainLine({
    required this.id,
    required this.label,
    required this.amount,
    this.note,
    this.emphasized = false,
  });

  final String id;
  final String label;
  final String amount;
  final String? note;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      key: Key('trip-gain-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: (emphasized ? tt.titleSmall : tt.bodyMedium)?.copyWith(
                  color: cs.onSurface,
                  fontWeight: emphasized ? FontWeight.w700 : null,
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  amount,
                  key: Key('trip-gain-$id-amount'),
                  maxLines: 1,
                  style: (emphasized ? tt.titleLarge : tt.titleSmall)?.copyWith(
                    color: cs.onSurface,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (note case final note?) ...[
          const SizedBox(height: DonySpacing.xxs),
          Text(
            note,
            key: Key('trip-gain-$id-note'),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
