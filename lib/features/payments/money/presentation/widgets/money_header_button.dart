import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Route de l'écran « Mon argent ».
const kMoneyOverviewRoute = '/payments/money';

/// Pastille portefeuille de l'en-tête de l'accueil (FLUTTER-HV, maquette
/// « Main »). Affiche le montant à venir du voyageur quand de l'argent est
/// en séquestre, sinon une simple icône ronde. Un tap ouvre « Mon argent »,
/// puis rafraîchit le montant au retour.
///
/// Lit le [MoneyOverviewBloc] fourni au-dessus (sans repli portefeuille : un
/// ancien back rend simplement l'icône).
class MoneyHeaderButton extends StatelessWidget {
  const MoneyHeaderButton({super.key, this.size = 48, this.showAmount = true});

  final double size;

  /// `false` sur un écran étroit : l'icône seule laisse la place à la barre
  /// de recherche.
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MoneyOverviewBloc, MoneyOverviewState>(
      builder: (context, state) {
        final l = context.l10n;
        final cs = Theme.of(context).colorScheme;
        final upcoming = state is MoneyOverviewLoaded
            ? state.overview.travelerUpcoming
            : const <MoneyAmount>[];
        final hasUpcoming = upcoming.isNotEmpty;
        final label = hasUpcoming
            ? l.moneyHeaderSemanticsUpcoming(
                upcoming
                    .map((a) => formatMoney(a.amount, a.currency))
                    .join(', '),
              )
            : l.moneyHeaderSemantics;
        final pill = hasUpcoming && showAmount;

        Future<void> open() async {
          await context.push(kMoneyOverviewRoute);
          if (context.mounted) {
            context.read<MoneyOverviewBloc>().add(
              const MoneyOverviewRefreshRequested(),
            );
          }
        }

        return Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: DonyPressable(
            onTap: open,
            child: AnimatedContainer(
              key: const Key('money-header-button'),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: size,
              constraints: BoxConstraints(minWidth: size),
              padding: pill
                  ? const EdgeInsets.only(left: DonySpacing.md, right: 14)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: hasUpcoming ? cs.primaryContainer : cs.surface,
                borderRadius: BorderRadius.circular(size / 2),
                border: hasUpcoming
                    ? Border.all(color: cs.primary, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DonyIcon(
                    'wallet',
                    size: 22,
                    color: hasUpcoming ? cs.primary : cs.onSurfaceVariant,
                  ),
                  if (pill) ...[
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      formatMoney(
                        upcoming.first.amount,
                        upcoming.first.currency,
                      ),
                      key: const Key('money-header-amount'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pastille de l'accueil avec son propre [MoneyOverviewBloc] (variante
/// en-tête : sans repli sur le portefeuille ni événement de consultation).
class MoneyHeaderEntry extends StatelessWidget {
  const MoneyHeaderEntry({super.key, this.size = 48, this.showAmount = true});

  final double size;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<MoneyOverviewBloc>(param1: true)
            ..add(const MoneyOverviewLoadRequested()),
      child: MoneyHeaderButton(size: size, showAmount: showAmount),
    );
  }
}
