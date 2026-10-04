// Étape 2 du formulaire "Publier un trajet" : Prix & Conditions.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur, zéro changement
// de comportement.
import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/grid_preview_card.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/payment_setup_notice.dart';
import 'package:dony/features/matching/presentation/widgets/price_hint_widget.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Corps de l'étape 2 (Prix & Conditions) du formulaire de création d'annonce.
///
/// Tous les [ValueNotifier] et [TextEditingController] restent la propriété de
/// [_CreateAnnouncementContentState] — ils sont simplement passés en paramètre.
/// Le cycle de vie (create / dispose) reste entièrement dans le state parent.
class PrixConditionsStep extends StatelessWidget {
  final SupportedCurrency? currency;
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final ValueNotifier<double> availableKgNotifier;
  final ValueNotifier<bool> cashEnabledNotifier;
  final ValueNotifier<bool> kgPriceEnabledNotifier; // ← NOUVEAU

  /// Le voyageur accepte le paiement par mobile money (Orange Money, Wave,
  /// MTN via pawaPay). Bascule visible même hors zone CFA, mais désactivée
  /// (cf. [currencyNotifier] et [mobileMoneyAccountActive]).
  final ValueNotifier<bool> mobileMoneyEnabledNotifier;

  /// Devise courante, écoutée en direct pour activer/désactiver la bascule
  /// mobile money : seuls XOF et XAF (zone CFA) y sont éligibles. Distinct de
  /// [currency] (valeur déjà résolue, utilisée pour l'affichage des prix) —
  /// le parent transmet les deux.
  final ValueNotifier<SupportedCurrency> currencyNotifier;

  /// Le voyageur a activé son compte de versement mobile money
  /// (`MobileMoneyAccountBloc` côté écran). Tant que ce n'est pas le cas, la
  /// bascule reste désactivée même en zone CFA.
  final bool mobileMoneyAccountActive;

  /// Devise reçue par le compte mobile money actif (ex. XOF), `null` si
  /// inconnue ou aucun compte actif. Sert à proposer de publier le trajet
  /// dans cette devise quand celle du trajet ne permet pas le mobile money.
  final SupportedCurrency? mobileMoneyCurrency;

  /// Appelé au retour de l'écran d'activation du mobile money, ouvert depuis
  /// l'encart « Activer le mobile money ». Le parent y recharge son
  /// `MobileMoneyAccountBloc`, sans quoi la bascule resterait désactivée
  /// après une activation réussie.
  final VoidCallback? onMobileMoneySetupReturned;

  /// Le voyageur accepte les propositions de prix des expéditeurs.
  /// Propriété du parent, comme les autres notifiers de cette étape.
  final ValueNotifier<bool> negotiableNotifier;
  final ValueNotifier<Set<String>> selectedContentNotifier;
  final ValueNotifier<Set<String>> customAcceptedNotifier;
  final ValueNotifier<Set<String>> refusedTypesNotifier;

  /// Catalogue de labels de types de contenu — piloté par le repository
  /// (`ContentCategoryRepository`), avec repli embarqué. Remplace l'ancienne
  /// liste figée de types de contenu. Propriété du parent (host
  /// `create_announcement_bottom_sheet.dart` / `create_trip_screen.dart`)
  /// comme les autres notifiers.
  final ValueNotifier<List<String>> catalogLabelsNotifier;
  final TextEditingController descriptionCtrl;
  final TextEditingController customAcceptedCtrl;
  final TextEditingController refusedCtrl;
  final TextEditingController customPriceCtrl;

  /// Verrouille la section prix (lecture seule) : utilisé quand le prix est déjà
  /// fixé par une négociation (modification d'un trajet à lier, ou trajet dédié).
  /// La section prix éditable est masquée et remplacée par une note ; le prix
  /// déjà saisi reste inchangé à l'enregistrement. La capacité (étape 1) et les
  /// autres champs restent éditables.
  final bool lockPrice;

  /// Trajet dédié : prix total convenu avec l'expéditeur. Si non-null et
  /// [lockPrice] actif, la note générique est remplacée par une carte affichant
  /// ce montant. Sinon, la note générique « Prix fixé par la négociation ».
  final double? lockedTotalPriceEur;

  /// Affiche la section « Modes de paiement acceptés ». Masquée dans le flux
  /// trajet dédié (le mode de paiement est déjà fixé par la négociation).
  final bool showPaymentMethods;

  const PrixConditionsStep({
    super.key,
    this.currency,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.availableKgNotifier,
    required this.cashEnabledNotifier,
    required this.kgPriceEnabledNotifier, // ← NOUVEAU
    required this.mobileMoneyEnabledNotifier,
    required this.currencyNotifier,
    this.mobileMoneyAccountActive = false,
    this.mobileMoneyCurrency,
    this.onMobileMoneySetupReturned,
    required this.negotiableNotifier,
    required this.selectedContentNotifier,
    required this.customAcceptedNotifier,
    required this.refusedTypesNotifier,
    required this.catalogLabelsNotifier,
    required this.descriptionCtrl,
    required this.customAcceptedCtrl,
    required this.refusedCtrl,
    required this.customPriceCtrl,
    this.lockPrice = false,
    this.lockedTotalPriceEur,
    this.showPaymentMethods = true,
  });

  /// Repères de la devise de l'annonce : chips, médiane, fourchette.
  KgPriceReference get _reference =>
      KgPriceReference.forCurrency(currency ?? SupportedCurrency.eur);

  List<double> get _presets => _reference.presets;

  bool get _isCustomPrice => priceOptionNotifier.value == _presets.length;

  double get _pricePerKg => _isCustomPrice
      ? customPriceNotifier.value
      : _presets[priceOptionNotifier.value.clamp(0, _presets.length - 1)];

  @override
  Widget build(BuildContext context) {
    // TODO(refactor): décomposer en _PriceSection / _PaymentSection / _ContentSection / _NoteSection
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prix fixé par la négociation → section prix masquée (note + prix
        // existant conservé). La capacité (étape 1) reste éditable.
        // Trajet dédié : on affiche le prix total convenu ; modification-pour-
        // négo : note générique (pas de total à afficher).
        if (lockPrice)
          lockedTotalPriceEur != null
              ? _LockedAgreedPriceCard(
                  amount: lockedTotalPriceEur!,
                  currency: currency,
                )
              : const _LockedPriceNote(),
        if (!lockPrice) ...[
          // ── MODE DE TARIFICATION ──────────────────────────────────────────────
          BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
            buildWhen: (p, c) => p.pricingMode != c.pricingMode,
            builder: (context, formState) {
              return Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeToggleOption(
                        label: l.tripPublishPricingModeKg,
                        active: formState.pricingMode == PricingMode.kg,
                        onTap: () => context.read<AnnouncementFormBloc>().add(
                          const AnnouncementPricingModeSetRequested(
                            PricingMode.kg,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ModeToggleOption(
                        label: l.tripPublishPricingModeMixed,
                        active: formState.pricingMode == PricingMode.mixed,
                        onTap: () => context.read<AnnouncementFormBloc>().add(
                          const AnnouncementPricingModeSetRequested(
                            PricingMode.mixed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ).animate().fadeIn(delay: 50.ms),
          const SizedBox(height: DonySpacing.md),

          // ── PRIX PAR KG ───────────────────────────────────────────────────────
          BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
            buildWhen: (p, c) => p.pricingMode != c.pricingMode,
            builder: (context, formState) {
              final isMixed = formState.pricingMode == PricingMode.mixed;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CaSectionLabel(
                    label: l.tripPublishPricePerKgSectionLabel,
                    iconAsset: 'tag',
                  ),
                  const SizedBox(height: DonySpacing.md),
                  // ── Toggle "Tarif au kilo" (MIXED uniquement) ─────────────
                  if (isMixed)
                    ValueListenableBuilder<bool>(
                      valueListenable: kgPriceEnabledNotifier,
                      builder: (context, kgEnabled, _) {
                        return SwitchListTile(
                          key: const Key('kg-price-toggle'),
                          value: kgEnabled,
                          onChanged: (v) => kgPriceEnabledNotifier.value = v,
                          activeThumbColor: cs.primary,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.tripPublishKgPriceToggleTitle,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            l.tripPublishKgPriceToggleSubtitle,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  // ── Chips (cachées si toggle OFF) ─────────────────────────
                  ValueListenableBuilder<bool>(
                    valueListenable: kgPriceEnabledNotifier,
                    builder: (context, kgEnabled, _) {
                      if (!kgEnabled) return const SizedBox.shrink();
                      return ListenableBuilder(
                        listenable: Listenable.merge([
                          priceOptionNotifier,
                          customPriceNotifier,
                          availableKgNotifier,
                        ]),
                        builder: (context, _) {
                          final selectedIdx = priceOptionNotifier.value;
                          final isCustom = _isCustomPrice;
                          final pricePerKg = _pricePerKg;
                          final kg = availableKgNotifier.value;
                          final travelerNet = kg * pricePerKg;
                          final senderTotal = netToSenderPrice(travelerNet);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Chips preset ──────────────────────────
                              Row(
                                children: List.generate(_presets.length, (i) {
                                  final selected = selectedIdx == i;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: i == 0 ? 0 : DonySpacing.xs,
                                        right: DonySpacing.xs,
                                      ),
                                      child: GestureDetector(
                                        onTap: () =>
                                            priceOptionNotifier.value = i,
                                        child: AnimatedContainer(
                                          duration: 180.ms,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: DonySpacing.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? cs.successLight
                                                : cs.surface,
                                            borderRadius: BorderRadius.circular(
                                              DonyRadius.lg,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? cs.success
                                                  : cs.outline,
                                              width: selected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              CurrencyFormatter.formatOrPlain(
                                                _presets[i],
                                                currency,
                                              ),
                                              style: tt.titleMedium?.copyWith(
                                                color: selected
                                                    ? cs.success
                                                    : cs.onSurface,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: DonySpacing.xs),
                              // ── Chip "Autre" ──────────────────────────
                              GestureDetector(
                                onTap: () {
                                  priceOptionNotifier.value = _presets.length;
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    FocusScope.of(context).unfocus();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: 180.ms,
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: DonySpacing.sm,
                                    horizontal: DonySpacing.base,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCustom
                                        ? cs.successLight
                                        : cs.surface,
                                    borderRadius: BorderRadius.circular(
                                      DonyRadius.lg,
                                    ),
                                    border: Border.all(
                                      color: isCustom ? cs.success : cs.outline,
                                      width: isCustom ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      DonyIcon(
                                        'square-pen',
                                        size: 16,
                                        color: isCustom
                                            ? cs.success
                                            : cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: DonySpacing.xs),
                                      Flexible(
                                        child: Text(
                                          l.tripPublishCustomPriceChipLabel,
                                          style: tt.bodyMedium?.copyWith(
                                            color: isCustom
                                                ? cs.success
                                                : cs.onSurfaceVariant,
                                            fontWeight: isCustom
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // ── Champ prix custom ─────────────────────
                              if (isCustom) ...[
                                const SizedBox(height: DonySpacing.sm),
                                DonyTextField(
                                  label: l.tripPublishPricePerKgSectionLabel,
                                  hint: l.tripPublishCustomPriceFieldHint,
                                  controller: customPriceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(
                                      right: DonySpacing.md,
                                    ),
                                    child: Text(
                                      '${currency?.symbol ?? ''}/kg',
                                      style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(
                                      v.replaceAll(',', '.'),
                                    );
                                    if (parsed != null && parsed > 0) {
                                      customPriceNotifier.value = parsed;
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: DonySpacing.sm),
                              Text(
                                selectedIdx == -1
                                    ? l.tripPublishPriceSelectPrompt
                                    : kg == 0
                                    ? l.tripPublishUnlimitedCapacityEstimateNote
                                    : l.tripPublishPriceEstimateLine(
                                        CurrencyFormatter.formatOrPlain(
                                          travelerNet,
                                          currency,
                                        ),
                                        CurrencyFormatter.formatOrPlain(
                                          senderTotal,
                                          currency,
                                        ),
                                      ),
                                style: tt.bodySmall?.copyWith(
                                  color: selectedIdx == -1
                                      ? cs.error.withValues(alpha: 0.7)
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ).animate().fadeIn(delay: 100.ms),
          // ── Price hint (masqué si toggle OFF) ────────────────────────────────
          ValueListenableBuilder<bool>(
            valueListenable: kgPriceEnabledNotifier,
            builder: (context, kgEnabled, _) {
              if (!kgEnabled) return const SizedBox.shrink();
              return BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
                buildWhen: (p, c) =>
                    p.priceWarning != c.priceWarning ||
                    p.pricePerKg != c.pricePerKg ||
                    p.departureCity != c.departureCity ||
                    p.arrivalCity != c.arrivalCity,
                builder: (context, formState) {
                  final dep = formState.departureCity;
                  final arr = formState.arrivalCity;
                  final corridor = (dep != null && arr != null)
                      ? '$dep – $arr'
                      : null;
                  return PriceHintWidget(
                    marketMedianPrice: _reference.marketMedian,
                    warning: formState.priceWarning,
                    corridor: corridor,
                    currency: currency,
                  );
                },
              );
            },
          ),

          // ── APERÇU GRILLE (mode MIXED) ────────────────────────────────────────
          BlocBuilder<AnnouncementFormBloc, AnnouncementFormState>(
            buildWhen: (p, c) =>
                p.pricingMode != c.pricingMode ||
                p.gridPreviewItems != c.gridPreviewItems,
            builder: (context, formState) {
              if (formState.pricingMode != PricingMode.mixed) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: DonySpacing.md),
                  GridPreviewCard(
                    items: formState.gridPreviewItems,
                    currency: currency,
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(DonySpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: Text(
                      l.tripPublishGridCommissionNotice(
                        commissionPercentLabel(l),
                      ),
                      style: tt.bodySmall?.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              );
            },
          ),
          // ── OUVERTURE AUX PROPOSITIONS DE PRIX ────────────────────────────
          const SizedBox(height: DonySpacing.md),
          ValueListenableBuilder<bool>(
            valueListenable: negotiableNotifier,
            builder: (context, negotiable, _) {
              return SwitchListTile(
                key: const Key('negotiable-toggle'),
                value: negotiable,
                onChanged: (v) {
                  negotiableNotifier.value = v;
                  context.read<AnnouncementFormBloc>().add(
                    NegotiableChanged(v),
                  );
                },
                activeThumbColor: cs.primary,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l.tripPublishNegotiableToggleTitle,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l.tripPublishNegotiableToggleSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            },
          ),
        ], // fin du bloc prix (masqué quand lockPrice)
        const SizedBox(height: DonySpacing.xxl),

        // ── MODES DE PAIEMENT ACCEPTÉS ────────────────────────────────────────
        // Masqué dans le flux trajet dédié : le mode de paiement est déjà fixé
        // par la négociation (lockContext.paymentMethod).
        if (showPaymentMethods) ...[
          CaSectionLabel(
            label: l.tripPublishPaymentMethodsSectionLabel,
            iconAsset: 'banknote',
          ),
          const SizedBox(height: DonySpacing.sm),
          BlocBuilder<StripeAccountBloc, StripeAccountState>(
            builder: (ctx, stripeState) =>
                ValueListenableBuilder<SupportedCurrency>(
                  valueListenable: currencyNotifier,
                  builder: (ctx, currencyValue, _) => _buildPaymentMethodsCard(
                    tt,
                    cs,
                    ctx,
                    l,
                    cardStatus: _cardStatusFor(stripeState, currencyValue),
                    currency: currencyValue,
                  ),
                ),
          ).animate().fadeIn(delay: 180.ms),
          const SizedBox(height: DonySpacing.xxl),
        ], // fin de la section paiement (masquée quand !showPaymentMethods)
        // ── CE QUE J'ACCEPTE ──────────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishAcceptedContentSectionLabel,
          iconAsset: 'circle-check',
        ),
        const SizedBox(height: DonySpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([
            selectedContentNotifier,
            customAcceptedNotifier,
            catalogLabelsNotifier,
          ]),
          builder: (context, _) {
            final catalogLabels = catalogLabelsNotifier.value;
            final catalog = catalogLabels
                .map(
                  (label) => ContentCategory(
                    code: label,
                    label: label,
                    emoji: emojiForLabel(label),
                  ),
                )
                .toList();
            final catalogSet = catalogLabels.toSet();
            final combinedSelected = <String>{
              ...selectedContentNotifier.value,
              ...customAcceptedNotifier.value,
            }.toList();

            final otherSelected = combinedSelected.contains(kOtherContentLabel);
            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ContentCategoryComboBox(
                      keyPrefix: 'accepted-content',
                      catalog: catalog,
                      selected: combinedSelected,
                      onChanged: (labels) {
                        final labelSet = labels.toSet();
                        selectedContentNotifier.value = labelSet
                            .where(catalogSet.contains)
                            .toSet();
                        customAcceptedNotifier.value = labelSet
                            .where((l) => !catalogSet.contains(l))
                            .toSet();
                      },
                    ),
                    // « Autre » seul ne dit rien à l'expéditeur : une
                    // précision est obligatoire (FLUTTER-4G).
                    if (otherSelected) ...[
                      const SizedBox(height: DonySpacing.md),
                      DonyTextField(
                        key: const Key('accepted-other-precision'),
                        label: l.tripPublishOtherContentPrecisionLabel,
                        hint: l.tripPublishOtherContentPrecisionHint,
                        controller: customAcceptedCtrl,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── CE QUE JE REFUSE ──────────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishRefusedContentSectionLabel,
          iconAsset: 'ban',
        ),
        const SizedBox(height: DonySpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([
            refusedTypesNotifier,
            catalogLabelsNotifier,
          ]),
          builder: (context, _) {
            final catalogLabels = catalogLabelsNotifier.value;
            final catalog = catalogLabels
                .map(
                  (label) => ContentCategory(
                    code: label,
                    label: label,
                    emoji: emojiForLabel(label),
                  ),
                )
                .toList();

            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: ContentCategoryComboBox(
                  keyPrefix: 'refused-content',
                  catalog: catalog,
                  selected: refusedTypesNotifier.value.toList(),
                  hint: l.tripPublishRefusedContentHint,
                  onChanged: (labels) =>
                      refusedTypesNotifier.value = labels.toSet(),
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 140.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── NOTE AUX EXPÉDITEURS ──────────────────────────────────────────────
        CaSectionLabel(
          label: l.tripPublishNoteToSendersSectionLabel,
          iconAsset: 'notebook-pen',
        ),
        const SizedBox(height: DonySpacing.sm),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: descriptionCtrl,
          builder: (context, value, _) {
            return CaSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.xs,
                    ),
                    child: TextField(
                      controller: descriptionCtrl,
                      maxLines: 4,
                      maxLength: 500,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText: l.tripPublishNoteToSendersHint,
                        hintStyle: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: DonySpacing.md,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      right: DonySpacing.base,
                      bottom: DonySpacing.sm,
                    ),
                    child: Text(
                      '${value.text.length}/500',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            );
          },
        ).animate().fadeIn(delay: 160.ms),
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }

  /// Ce que la ligne « Carte bancaire » peut offrir sur CE trajet.
  ///
  /// L'ordre compte. La devise passe en premier : un trajet en XOF ne prendra
  /// jamais la carte, onboarding Stripe fait ou non, et y inviter serait
  /// trompeur. Le pays ensuite, puis l'onboarding lui-même. Même règle que la
  /// soumission (`create_trip_screen.dart`, `_isStripeConfigured() &&
  /// _currency.isStripeEligible`) : l'écran n'affiche jamais une carte
  /// « activée » qui ne partirait pas au serveur.
  static _CardStatus _cardStatusFor(
    StripeAccountState stripeState,
    SupportedCurrency currency,
  ) {
    if (!currency.isStripeEligible) return _CardStatus.currencyUnavailable;
    if (stripeState is StripeAccountReady &&
        stripeState.accountStatus.isComplete) {
      return _CardStatus.active;
    }
    if (!stripeState.connectAvailableInCountry) {
      return _CardStatus.countryUnavailable;
    }
    return _CardStatus.notConfigured;
  }

  /// Section « Modes de paiement acceptés ». Chaque mode indisponible dit
  /// pourquoi, et mène à sa configuration quand l'utilisateur peut la faire.
  Widget _buildPaymentMethodsCard(
    TextTheme tt,
    ColorScheme cs,
    BuildContext ctx,
    AppLocalizations l, {
    required _CardStatus cardStatus,
    required SupportedCurrency currency,
  }) {
    final cardActive = cardStatus == _CardStatus.active;
    // Sans carte, les espèces sont le seul mode garanti : la soumission les
    // ajoute d'office, l'écran les montre donc activées et verrouillées. Au
    // moins un mode de paiement est requis pour publier. Post-frame pour ne
    // pas muter d'état pendant le build.
    final cashLocked = !cardActive;
    if (cashLocked && !cashEnabledNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cashEnabledNotifier.value = true;
      });
    }

    return CaSectionCard(
      child: Column(
        children: [
          // ── Carte bancaire (toujours verrouillée, ON seulement si utilisable)
          SwitchListTile(
            key: const Key('payment-method-stripe'),
            value: cardActive,
            onChanged: null,
            activeThumbColor: cs.primary,
            title: Row(
              children: [
                DonyIcon(
                  'credit-card',
                  size: 18,
                  color: cardActive ? null : cs.onSurfaceVariant,
                ),
                const SizedBox(width: DonySpacing.sm),
                Flexible(
                  child: Text(
                    l.tripPublishCardPaymentTitle,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cardActive ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
              ],
            ),
            subtitle: Text(switch (cardStatus) {
              _CardStatus.active => l.tripPublishCardPaymentSubtitle,
              _CardStatus.notConfigured =>
                l.tripPublishCardNotConfiguredSubtitle,
              _CardStatus.countryUnavailable ||
              _CardStatus.currencyUnavailable =>
                l.tripPublishCardUnavailableSubtitle,
            }, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs,
            ),
          ),
          if (!cardActive)
            _noticePadding(switch (cardStatus) {
              _CardStatus.notConfigured => PaymentSetupNotice(
                key: const Key('card-setup-notice'),
                message: l.tripPublishCardConnectInactiveNotice,
                ctaLabel: l.tripPublishActivateCardPaymentsCta,
                ctaKey: const Key('activate-card-payments-cta'),
                // Le retour d'onboarding rafraîchit lui-même le
                // StripeAccountBloc global (connect_onboarding_intro_screen).
                onCtaTap: () => ctx.push('/connect/onboarding/intro'),
              ),
              _CardStatus.countryUnavailable => PaymentSetupNotice(
                key: const Key('card-setup-notice'),
                message: l.tripPublishCashOnlyBannerNoConnect,
              ),
              _CardStatus.currencyUnavailable ||
              _CardStatus.active => PaymentSetupNotice(
                key: const Key('card-setup-notice'),
                message: l.tripPublishCardCurrencyUnavailableNotice(
                  currency.code,
                ),
              ),
            }),
          const CaRowDivider(),
          // ── Espèces ───────────────────────────────────────────────────────
          // La carte de commission n'est plus requise à la création d'annonce.
          // La vérification (wallet ou carte) est reportée à l'acceptation du bid.
          ValueListenableBuilder<bool>(
            valueListenable: cashEnabledNotifier,
            builder: (context, cashEnabled, _) {
              final cashOn = cashLocked || cashEnabled;
              return Column(
                children: [
                  SwitchListTile(
                    key: const Key('payment-method-cash'),
                    value: cashOn,
                    // Verrouillées, les espèces restent un interrupteur
                    // actif à l'œil : désactivé, il s'affichait grisé et se
                    // lisait « espèces indisponibles » alors qu'elles sont
                    // acceptées d'office (Sentry FLUTTER-8M). Un toucher
                    // explique pourquoi elles ne se désactivent pas.
                    onChanged: cashLocked
                        ? (_) => DonySnackbar.show(
                            ctx,
                            message: l.tripPublishCashLockedExplanation,
                          )
                        : (val) => cashEnabledNotifier.value = val,
                    activeThumbColor: cs.primary,
                    title: Row(
                      children: [
                        const DonyIcon('banknote', size: 18),
                        const SizedBox(width: DonySpacing.sm),
                        Flexible(
                          child: Text(
                            l.tripPublishCashLabel,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      cashLocked
                          ? l.tripPublishCashLockedSubtitle
                          : l.tripPublishCashSubtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.base,
                      vertical: DonySpacing.xs,
                    ),
                  ),
                  AnimatedSize(
                    duration: 200.ms,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: cashOn
                        ? _noticePadding(
                            const CashCommissionNotice().animate().fadeIn(
                              duration: 200.ms,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              );
            },
          ),
          const CaRowDivider(),
          _buildMobileMoneySection(tt, cs, l, currency: currency),
        ],
      ),
    );
  }

  /// Marge commune des encarts placés sous une ligne de mode de paiement.
  Widget _noticePadding(Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DonySpacing.base,
      0,
      DonySpacing.base,
      DonySpacing.md,
    ),
    child: child,
  );

  /// Bascule « Mobile money » : réservée aux trajets en franc CFA (XOF, XAF),
  /// et au voyageur qui a activé son compte de versement. Visible dans tous
  /// les cas, désactivée tant que l'une des deux conditions manque.
  Widget _buildMobileMoneySection(
    TextTheme tt,
    ColorScheme cs,
    AppLocalizations l, {
    required SupportedCurrency currency,
  }) {
    final eligible = currency.isMobileMoneyEligible;
    final usable = eligible && mobileMoneyAccountActive;
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: mobileMoneyEnabledNotifier,
          builder: (context, mobileMoneyEnabled, _) {
            return SwitchListTile(
              key: const Key('payment-method-mobile-money'),
              // Jamais affichée activée quand elle n'est pas utilisable,
              // quelle que soit la valeur héritée d'un modèle ou d'une devise
              // précédente.
              value: usable && mobileMoneyEnabled,
              onChanged: usable
                  ? (v) => mobileMoneyEnabledNotifier.value = v
                  : null,
              activeThumbColor: cs.primary,
              title: Row(
                children: [
                  DonyIcon(
                    'smartphone',
                    size: 18,
                    color: usable ? null : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Flexible(
                    child: Text(
                      'Mobile money', // i18n-ignore : mot identique en anglais (glossaire commun)
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: usable ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                !eligible
                    ? l.tripPublishMobileMoneyIneligibleSubtitle
                    : !mobileMoneyAccountActive
                    ? l.tripPublishMobileMoneyInactiveSubtitle
                    : 'Orange Money, MTN, Moov', // i18n-ignore : noms de marques
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.xs,
              ),
            );
          },
        ),
        // Compte activé mais trajet dans une autre devise : l'option grisée
        // ne disait pas pourquoi (FLUTTER-55). On l'explique et on propose de
        // publier dans la devise du compte, comme le sélecteur de devise.
        if (!eligible && mobileMoneyAccountActive)
          _noticePadding(_mobileMoneyCurrencyNotice(l, tripCurrency: currency)),
        // Hors zone CFA sans compte, rien à activer : le sous-titre suffit.
        if (eligible && !mobileMoneyAccountActive)
          Builder(
            builder: (context) => _noticePadding(
              PaymentSetupNotice(
                key: const Key('mobile-money-setup-notice'),
                message: l.tripPublishMobileMoneyInactiveNotice,
                ctaLabel: l.tripPublishActivateMobileMoneyCta,
                ctaKey: const Key('activate-mobile-money-cta'),
                onCtaTap: () async {
                  // L'écran d'activation a sa propre instance du bloc
                  // (registerFactory) : sans rechargement au retour, l'étape
                  // afficherait encore « non activé » après l'activation.
                  await context.push<void>('/payments/mobile-money/account');
                  if (context.mounted) onMobileMoneySetupReturned?.call();
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _mobileMoneyCurrencyNotice(
    AppLocalizations l, {
    required SupportedCurrency tripCurrency,
  }) {
    final target = mobileMoneyCurrency;
    if (target == null || !target.isMobileMoneyEligible) {
      return PaymentSetupNotice(
        key: const Key('mobile-money-currency-notice'),
        message: l.tripPublishMobileMoneyCurrencyNoticeGeneric(
          tripCurrency.code,
        ),
      );
    }
    return PaymentSetupNotice(
      key: const Key('mobile-money-currency-notice'),
      message: l.tripPublishMobileMoneyCurrencyNotice(
        target.code,
        tripCurrency.code,
      ),
      ctaLabel: l.tripPublishSwitchCurrencyCta(target.code),
      ctaKey: const Key('switch-to-mobile-money-currency-cta'),
      onCtaTap: () => currencyNotifier.value = target,
    );
  }
}

/// Ce que la ligne « Carte bancaire » peut offrir sur un trajet donné.
enum _CardStatus {
  /// Onboarding Stripe terminé et devise compatible : la carte est acceptée.
  active,

  /// Stripe couvre le pays mais l'onboarding n'est pas fait.
  notConfigured,

  /// Stripe n'ouvre pas de compte connecté dans le pays de l'utilisateur.
  countryUnavailable,

  /// La devise du trajet ne se paie pas par carte (zone CFA notamment).
  currencyUnavailable,
}

/// Bouton de sélection du mode de tarification dans le toggle.
class _ModeToggleOption extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeToggleOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        decoration: BoxDecoration(
          color: active ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(DonyRadius.sm),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: active ? cs.primary : cs.onSurfaceVariant,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Note affichée à la place de la section prix quand le prix est verrouillé
/// (fixé par une négociation). Le prix existant du trajet reste inchangé.
class _LockedPriceNote extends StatelessWidget {
  const _LockedPriceNote();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      key: const Key('locked-price-note'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('lock', size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.tripPublishLockedPriceNoteTitle,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.tripPublishLockedPriceNoteSubtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte affichant le prix total convenu (flux trajet dédié). Le montant est
/// fixé par la négociation et non modifiable dans le formulaire.
class _LockedAgreedPriceCard extends StatelessWidget {
  const _LockedAgreedPriceCard({required this.amount, required this.currency});
  final double amount;
  final SupportedCurrency? currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      key: const Key('locked-agreed-price-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.lg),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          DonyIcon('circle-check', color: cs.success, size: 28),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.tripPublishAgreedPriceLabel,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  CurrencyFormatter.formatOrPlain(
                    amount,
                    currency,
                    compact: true,
                  ),
                  style: tt.headlineSmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          DonyIcon('lock', size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Libellé de la catégorie « Autre » du catalogue (valeur de donnée).
const kOtherContentLabel = 'Autre'; // i18n-ignore : valeur ContentCategory

/// Contenus acceptés envoyés au back : « Autre » est remplacé par la
/// précision du voyageur (FLUTTER-4G). `null` quand « Autre » est coché sans
/// précision : l'appelant doit bloquer la publication.
List<String>? acceptedContentWithPrecision({
  required Set<String> selected,
  required Set<String> custom,
  required String otherPrecision,
}) {
  final all = {...selected, ...custom};
  if (!all.contains(kOtherContentLabel)) return all.toList();
  // Le back découpe les contenus sur « , » : pas de virgule dans un libellé.
  final precision = otherPrecision
      .replaceAll(',', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (precision.isEmpty) return null;
  return {...all.where((c) => c != kOtherContentLabel), precision}.toList();
}
