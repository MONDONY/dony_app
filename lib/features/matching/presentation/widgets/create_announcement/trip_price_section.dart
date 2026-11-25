// Section prix de l'étape « Prix & conditions » : prix au kilo réglé par
// « − / + » autour du prix conseillé de la route, gain du voyageur, et prix
// par article (grille du profil) en option.
import 'dart:ui' show PathMetric;

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/kg_price_stepper.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

export 'package:dony/features/matching/bloc/trip_price_suggestion_cubit.dart'
    show gridSuggestionsFrom;

/// Prix au kilo actuellement retenu par les notifiers du formulaire, `null`
/// tant qu'aucun prix n'est posé.
///
/// Les notifiers gardent leur forme historique (index de repère, ou « autre
/// prix » + montant libre) : brouillons, modèles et modification les
/// remplissent ainsi. Le sélecteur « − / + » écrit toujours un montant libre.
double? currentKgPrice({
  required SupportedCurrency currency,
  required int priceOption,
  required double customPrice,
  required String customPriceText,
}) {
  if (priceOption < 0) return null;
  final presets = KgPriceReference.forCurrency(currency).presets;
  if (priceOption < presets.length) return presets[priceOption];
  return parsePriceInput(customPriceText) ?? customPrice;
}

/// Écrit [price] comme montant libre dans les notifiers du formulaire.
///
/// Le texte et le montant passent avant l'index : les écouteurs de l'index
/// (synchronisation du bloc, validité) lisent alors des valeurs cohérentes.
void writeKgPrice({
  required double price,
  required SupportedCurrency currency,
  required ValueNotifier<int> priceOptionNotifier,
  required ValueNotifier<double> customPriceNotifier,
  required TextEditingController customPriceCtrl,
}) {
  customPriceCtrl.text = formatKgPrice(price);
  customPriceNotifier.value = price;
  priceOptionNotifier.value = KgPriceReference.forCurrency(
    currency,
  ).presets.length;
}

/// Cubit des prix conseillés s'il est fourni par l'écran (création et
/// modification d'un trajet), `null` ailleurs (modèle de trajet, tests).
TripPriceSuggestionCubit? _suggestionCubitOf(BuildContext context) =>
    context.watch<TripPriceSuggestionCubit?>();

/// Lit l'état des prix conseillés, ou un état de repli (médiane embarquée)
/// quand l'écran ne fournit pas de cubit.
class _SuggestionBuilder extends StatelessWidget {
  const _SuggestionBuilder({required this.currency, required this.builder});

  final SupportedCurrency currency;
  final Widget Function(
    BuildContext context,
    TripPriceSuggestionState state,
    TripPriceSuggestionCubit? cubit,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final cubit = _suggestionCubitOf(context);
    if (cubit == null) {
      return builder(
        context,
        TripPriceSuggestionState(currency: currency),
        null,
      );
    }
    return BlocBuilder<TripPriceSuggestionCubit, TripPriceSuggestionState>(
      bloc: cubit,
      builder: (context, state) => builder(
        context,
        // Réponse pour une autre devise que celle affichée : la médiane
        // embarquée de la devise courante fait foi.
        state.currency == currency
            ? state
            : TripPriceSuggestionState(currency: currency),
        cubit,
      ),
    );
  }
}

/// Montant sans symbole, séparateurs de la langue (« 8 », « 8,50 »,
/// « 2 000 »).
String _plainAmount(BuildContext context, double value) {
  final format = NumberFormat.decimalPattern(context.l10n.localeName)
    ..minimumFractionDigits = value % 1 == 0 ? 0 : 2
    ..maximumFractionDigits = value % 1 == 0 ? 0 : 2;
  return format.format(value);
}

/// Carte du prix au kilo : gros montant, « − / + », pastille du prix le plus
/// courant ou lien de retour au prix conseillé, bornes.
class KgPriceStepperCard extends StatelessWidget {
  const KgPriceStepperCard({
    super.key,
    required this.currency,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.customPriceCtrl,
  });

  final SupportedCurrency currency;
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final TextEditingController customPriceCtrl;

  @override
  Widget build(BuildContext context) {
    return _SuggestionBuilder(
      currency: currency,
      builder: (context, suggestion, cubit) => ListenableBuilder(
        listenable: Listenable.merge([
          priceOptionNotifier,
          customPriceNotifier,
          customPriceCtrl,
        ]),
        builder: (context, _) => _buildCard(context, suggestion, cubit),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    TripPriceSuggestionState suggestion,
    TripPriceSuggestionCubit? cubit,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final bounds = kgPriceStepperBoundsFor(currency);
    final suggested = suggestion.suggestedPricePerKg;
    final price =
        currentKgPrice(
          currency: currency,
          priceOption: priceOptionNotifier.value,
          customPrice: customPriceNotifier.value,
          customPriceText: customPriceCtrl.text,
        ) ??
        suggested;
    final isSuggested = (price - suggested).abs() < 1e-9;
    final canDecrease = price > bounds.min + 1e-9;
    final canIncrease = price < bounds.max - 1e-9;

    void write(double value) => writeKgPrice(
      price: value,
      currency: currency,
      priceOptionNotifier: priceOptionNotifier,
      customPriceNotifier: customPriceNotifier,
      customPriceCtrl: customPriceCtrl,
    );

    void adjust({required bool up}) {
      write(stepKgPrice(price, bounds, up: up));
      cubit?.priceAdjusted(up: up, fromSuggested: isSuggested);
    }

    String money(double v) =>
        CurrencyFormatter.formatOrPlain(v, currency, compact: true);

    return Container(
      key: const Key('kg-price-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.lg,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StepButton(
                key: const Key('kg-price-decrease'),
                icon: 'minus',
                semanticLabel: l.tripPublishKgPriceDecrease(money(bounds.step)),
                onTap: canDecrease ? () => adjust(up: false) : null,
              ),
              Expanded(
                child: Semantics(
                  label: l.tripPublishKgPriceSemantics(money(price)),
                  excludeSemantics: true,
                  child: FittedBox(
                    // Le montant ne passe jamais à la ligne : en franc CFA,
                    // « 16 500 » est plus large que « 8 ».
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _plainAmount(context, price),
                          key: const Key('kg-price-amount'),
                          style: tt.displayLarge?.copyWith(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs + 2),
                        Text(
                          '${currency.symbol}/kg', // i18n-ignore : unité
                          style: tt.titleMedium?.copyWith(
                            fontSize: 17,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _StepButton(
                key: const Key('kg-price-increase'),
                icon: 'plus',
                semanticLabel: l.tripPublishKgPriceIncrease(money(bounds.step)),
                onTap: canIncrease ? () => adjust(up: true) : null,
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          if (isSuggested && suggestion.isMostCommonOnRoute)
            Container(
              key: const Key('kg-price-most-common'),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.md,
                vertical: DonySpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DonyIcon('check', size: 14, color: cs.onPrimaryContainer),
                  const SizedBox(width: DonySpacing.xs + 2),
                  Flexible(
                    child: Text(
                      l.tripPublishKgPriceMostCommon,
                      style: tt.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms)
          else if (!isSuggested)
            TextButton(
              key: const Key('kg-price-reset'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () {
                write(suggested);
                cubit?.priceResetToSuggested();
              },
              child: Text(
                l.tripPublishKgPriceReset(money(suggested)),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripPublishKgPriceBounds(money(bounds.min), money(bounds.max)),
            key: const Key('kg-price-bounds'),
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton rond « − » ou « + » (56 pt, au-dessus des 44 pt minimum).
class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: cs.surface,
        shape: CircleBorder(side: BorderSide(color: cs.outline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 56,
            child: Center(
              child: DonyIcon(
                icon,
                color: enabled
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ce que le voyageur touche s'il remplit ses kilos, frais payés en plus par
/// l'expéditeur.
class KgPriceEarningsBlock extends StatelessWidget {
  const KgPriceEarningsBlock({
    super.key,
    required this.currency,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.customPriceCtrl,
    required this.availableKgNotifier,
  });

  final SupportedCurrency currency;
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final TextEditingController customPriceCtrl;
  final ValueNotifier<double> availableKgNotifier;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return _SuggestionBuilder(
      currency: currency,
      builder: (context, suggestion, _) =>
          BlocSelector<
            AnnouncementFormBloc,
            AnnouncementFormState,
            CapacityUnit
          >(
            selector: (s) => s.capacityUnit,
            builder: (context, unit) => ListenableBuilder(
              listenable: Listenable.merge([
                priceOptionNotifier,
                customPriceNotifier,
                customPriceCtrl,
                availableKgNotifier,
              ]),
              builder: (context, _) {
                final price =
                    currentKgPrice(
                      currency: currency,
                      priceOption: priceOptionNotifier.value,
                      customPrice: customPriceNotifier.value,
                      customPriceText: customPriceCtrl.text,
                    ) ??
                    suggestion.suggestedPricePerKg;
                // Capacité illimitée : pas de total, le gain se lit au kilo.
                final kg = availableKgNotifier.value;
                final unlimited = unit == CapacityUnit.kgFree || kg <= 0;
                final net = unlimited ? price : price * kg;
                return Container(
                  key: const Key('kg-price-earnings'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(DonySpacing.base),
                  decoration: BoxDecoration(
                    color: cs.surfaceWarm,
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unlimited
                            ? l.tripPublishEarningsPerKg
                            : l.tripPublishEarningsIfFull(formatKgPrice(kg)),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs + 2),
                      Text(
                        l.tripPublishEarningsAmount(
                          CurrencyFormatter.formatOrPlain(
                            net,
                            currency,
                            compact: true,
                          ),
                        ),
                        key: const Key('kg-price-earnings-amount'),
                        style: tt.headlineLarge?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xs + 2),
                      Text(
                        l.tripPublishEarningsFeesNote,
                        style: tt.bodySmall?.copyWith(
                          fontSize: 13,
                          height: 1.45,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}

/// Prix par article : carte d'invitation (pointillés) tant que la grille du
/// voyageur est vide, liste des prix une fois remplie.
class ItemPricesCard extends StatelessWidget {
  const ItemPricesCard({
    super.key,
    required this.currency,
    required this.gridCurrency,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.customPriceCtrl,
    this.kgPriceShown,
  });

  /// Le trajet a un prix au kilo (`null` : toujours). Sans lui, la ligne « Le
  /// reste est compté au kilo » disparaît : le reste n'est pas vendu.
  final ValueListenable<bool>? kgPriceShown;

  /// Devise du trajet.
  final SupportedCurrency currency;

  /// Devise de la grille (devise active du voyageur), `null` si inconnue.
  final SupportedCurrency? gridCurrency;
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final TextEditingController customPriceCtrl;

  @override
  Widget build(BuildContext context) {
    return _SuggestionBuilder(
      currency: currency,
      builder: (context, suggestion, cubit) =>
          BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
            buildWhen: (p, c) => p.gridPreviewItems != c.gridPreviewItems,
            builder: (context, formState) {
              final items = formState.gridPreviewItems;
              if (items.isEmpty) {
                return _EmptyItemPricesCard(
                  currency: currency,
                  suggestion: suggestion,
                  onAdd: () => _open(
                    context,
                    cubit,
                    suggestion,
                    TripItemPricesSource.step,
                  ),
                );
              }
              return _FilledItemPricesCard(
                currency: currency,
                gridCurrency: gridCurrency,
                items: formState.gridPreviewItems,
                suggestion: suggestion,
                priceOptionNotifier: priceOptionNotifier,
                customPriceNotifier: customPriceNotifier,
                customPriceCtrl: customPriceCtrl,
                kgPriceShown: kgPriceShown,
                onEdit: () => _open(
                  context,
                  cubit,
                  suggestion,
                  TripItemPricesSource.cardEdit,
                ),
              );
            },
          ),
    );
  }

  Future<void> _open(
    BuildContext context,
    TripPriceSuggestionCubit? cubit,
    TripPriceSuggestionState suggestion,
    TripItemPricesSource source,
  ) async {
    cubit?.itemPricesOpened(source);
    await openPriceGridAndRefresh(
      context,
      suggestions: gridSuggestionsFrom(suggestion),
    );
  }
}

class _EmptyItemPricesCard extends StatelessWidget {
  const _EmptyItemPricesCard({
    required this.currency,
    required this.suggestion,
    required this.onAdd,
  });

  final SupportedCurrency currency;
  final TripPriceSuggestionState suggestion;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final examples = suggestion.items.take(3).toList();
    return CustomPaint(
      key: const Key('item-prices-empty'),
      painter: _DashedBorderPainter(
        color: cs.primary.withValues(alpha: 0.6),
        radius: DonyRadius.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.tripPublishItemPricesTitle,
                    style: tt.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm + 2,
                    vertical: DonySpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    l.tripPublishItemPricesOptional,
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.tripPublishItemPricesPitch,
              style: tt.bodyMedium?.copyWith(height: 1.45),
            ),
            if (examples.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.md),
              Wrap(
                key: const Key('item-prices-examples'),
                spacing: DonySpacing.xs + 2,
                runSpacing: DonySpacing.xs + 2,
                children: [
                  for (final item in examples)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm + 2,
                        vertical: DonySpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(DonyRadius.full),
                      ),
                      child: Text(
                        l.tripPublishItemPriceExample(
                          item.label,
                          CurrencyFormatter.formatOrPlain(
                            item.unitPrice,
                            currency,
                            compact: true,
                          ),
                        ),
                        style: tt.bodySmall?.copyWith(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: DonySpacing.md),
            OutlinedButton.icon(
              key: const Key('item-prices-add'),
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: cs.primary),
                foregroundColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
              ),
              icon: DonyIcon('plus', size: 18, color: cs.primary),
              label: Text(
                l.tripPublishItemPricesAddCta,
                maxLines: 1,
                softWrap: false,
                style: tt.labelLarge?.copyWith(fontSize: 15, color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilledItemPricesCard extends StatelessWidget {
  const _FilledItemPricesCard({
    required this.currency,
    required this.gridCurrency,
    required this.items,
    required this.suggestion,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.customPriceCtrl,
    required this.onEdit,
    this.kgPriceShown,
  });

  final ValueListenable<bool>? kgPriceShown;

  final SupportedCurrency currency;
  final SupportedCurrency? gridCurrency;
  final List<GridPreviewItem> items;
  final TripPriceSuggestionState suggestion;
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final TextEditingController customPriceCtrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final display = GridPriceDisplay.resolve(
      gridCurrency: gridCurrency,
      tripCurrency: currency,
    );
    return Container(
      key: const Key('item-prices-filled'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.tripPublishGridPreviewLabel,
                  style: tt.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('item-prices-edit'),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: onEdit,
                icon: DonyIcon('square-pen', size: 16, color: cs.primary),
                label: Text(l.commonEdit, maxLines: 1, softWrap: false),
              ),
            ],
          ),
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm + 2),
              decoration: BoxDecoration(
                border: i == items.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: cs.outline.withValues(alpha: 0.6),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items[i].label,
                      style: tt.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Text(
                    display.formatItem(items[i]),
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          GridConvertedNote(display: display),
          const SizedBox(height: DonySpacing.xs),
          ListenableBuilder(
            listenable: Listenable.merge([
              priceOptionNotifier,
              customPriceNotifier,
              customPriceCtrl,
              ?kgPriceShown,
            ]),
            builder: (context, _) {
              if (kgPriceShown?.value == false) {
                return const SizedBox.shrink();
              }
              final price =
                  currentKgPrice(
                    currency: currency,
                    priceOption: priceOptionNotifier.value,
                    customPrice: customPriceNotifier.value,
                    customPriceText: customPriceCtrl.text,
                  ) ??
                  suggestion.suggestedPricePerKg;
              return Text(
                l.tripPublishItemPricesRestPerKg(
                  CurrencyFormatter.formatOrPlain(
                    price,
                    currency,
                    compact: true,
                  ),
                ),
                key: const Key('item-prices-rest-per-kg'),
                style: tt.bodySmall?.copyWith(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Contour pointillé arrondi de la carte d'invitation « Prix par article ».
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(radius)),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
