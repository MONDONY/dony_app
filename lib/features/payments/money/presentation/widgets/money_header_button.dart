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

/// Facteur de texte au-delà duquel la pastille affiche l'icône seule.
const double _kMaxPillTextScale = 1.3;

/// Route de l'écran « Mon argent ».
const kMoneyOverviewRoute = '/payments/money';

/// Pastille portefeuille de l'en-tête d'Activités (FLUTTER-HV, déplacée de
/// l'accueil par FLUTTER-J3). Affiche le montant à venir du voyageur quand de
/// l'argent est en séquestre, sinon une simple icône ronde. Un tap ouvre
/// « Mon argent », puis rafraîchit le montant au retour.
///
/// Lit le [MoneyOverviewBloc] fourni au-dessus (sans repli portefeuille : un
/// ancien back rend simplement l'icône).
class MoneyHeaderButton extends StatelessWidget {
  const MoneyHeaderButton({
    super.key,
    this.size = 48,
    this.showAmount = true,
    this.maxWidth,
  });

  final double size;

  /// `false` : icône seule, quel que soit le montant.
  final bool showAmount;

  /// Largeur disponible pour la pastille dans l'en-tête. Un montant qui n'y
  /// tient pas laisse place à l'icône seule (montant gardé dans le libellé
  /// d'accessibilité) : jamais de débordement ni de montant tronqué.
  final double? maxWidth;

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
        // Au-delà de 130 % de texte, le montant ne tient plus à côté de la
        // barre de recherche : icône seule, montant gardé dans le libellé.
        final textScaler = MediaQuery.textScalerOf(context);
        final largeText = textScaler.scale(14) > 14 * _kMaxPillTextScale;
        final amountStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: cs.onPrimaryContainer,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final amountText = hasUpcoming
            ? formatMoney(upcoming.first.amount, upcoming.first.currency)
            : '';
        final pill =
            hasUpcoming &&
            showAmount &&
            !largeText &&
            _amountFits(context, maxWidth, amountText, amountStyle, textScaler);

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
                      amountText,
                      key: const Key('money-header-amount'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: amountStyle,
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

/// Marges horizontales, icône et écart de la pastille avec montant.
const double _kPillChrome = DonySpacing.md + 14 + 22 + DonySpacing.sm;

/// La pastille avec [text] tient dans [maxWidth] (toujours vrai sans
/// contrainte).
bool _amountFits(
  BuildContext context,
  double? maxWidth,
  String text,
  TextStyle? style,
  TextScaler textScaler,
) {
  if (maxWidth == null) return true;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width + _kPillChrome <= maxWidth;
}

/// Pastille d'en-tête avec son propre [MoneyOverviewBloc] (variante
/// en-tête : sans repli sur le portefeuille ni événement de consultation).
class MoneyHeaderEntry extends StatelessWidget {
  const MoneyHeaderEntry({super.key, this.size = 48, this.maxWidth});

  final double size;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<MoneyOverviewBloc>(param1: true)
            ..add(const MoneyOverviewLoadRequested()),
      child: MoneyHeaderButton(size: size, maxWidth: maxWidth),
    );
  }
}
