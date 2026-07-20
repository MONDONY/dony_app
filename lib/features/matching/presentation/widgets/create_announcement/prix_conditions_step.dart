// Étape 2 du formulaire "Publier un trajet" : Prix & Conditions.
// Extrait de create_announcement_bottom_sheet.dart — refactor pur, zéro changement
// de comportement.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/bloc/announcement_form_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_form_event.dart';
import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/presentation/widgets/cash_commission_notice.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_create_announcement_constants.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/_shared_widgets.dart';
import 'package:dony/features/matching/presentation/widgets/price_hint_widget.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
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
  final ValueNotifier<int> priceOptionNotifier;
  final ValueNotifier<double> customPriceNotifier;
  final ValueNotifier<double> availableKgNotifier;
  final ValueNotifier<bool> cashEnabledNotifier;
  final ValueNotifier<bool> kgPriceEnabledNotifier; // ← NOUVEAU
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

  /// Trajet dédié : prix total convenu avec l'expéditeur (€). Si non-null et
  /// [lockPrice] actif, la note générique est remplacée par une carte affichant
  /// ce montant. Sinon, la note générique « Prix fixé par la négociation ».
  final double? lockedTotalPriceEur;

  /// Affiche la section « Modes de paiement acceptés ». Masquée dans le flux
  /// trajet dédié (le mode de paiement est déjà fixé par la négociation).
  final bool showPaymentMethods;

  const PrixConditionsStep({
    super.key,
    required this.priceOptionNotifier,
    required this.customPriceNotifier,
    required this.availableKgNotifier,
    required this.cashEnabledNotifier,
    required this.kgPriceEnabledNotifier, // ← NOUVEAU
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

  bool get _isCustomPrice => priceOptionNotifier.value == kPriceOptions.length;

  double get _pricePerKg => _isCustomPrice
      ? customPriceNotifier.value
      : kPriceOptions[
          priceOptionNotifier.value.clamp(0, kPriceOptions.length - 1)];

  @override
  Widget build(BuildContext context) {
    // TODO(refactor): décomposer en _PriceSection / _PaymentSection / _ContentSection / _NoteSection
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prix fixé par la négociation → section prix masquée (note + prix
        // existant conservé). La capacité (étape 1) reste éditable.
        // Trajet dédié : on affiche le prix total convenu ; modification-pour-
        // négo : note générique (pas de total à afficher).
        if (lockPrice)
          lockedTotalPriceEur != null
              ? _LockedAgreedPriceCard(amount: lockedTotalPriceEur!)
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
                      label: 'Au kilo',
                      active: formState.pricingMode == PricingMode.kg,
                      onTap: () => context.read<AnnouncementFormBloc>().add(
                            const AnnouncementPricingModeSetRequested(
                                PricingMode.kg),
                          ),
                    ),
                  ),
                  Expanded(
                    child: _ModeToggleOption(
                      label: 'Grille + kilo',
                      active: formState.pricingMode == PricingMode.mixed,
                      onTap: () => context.read<AnnouncementFormBloc>().add(
                            const AnnouncementPricingModeSetRequested(
                                PricingMode.mixed),
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
                const CaSectionLabel(
                    label: 'Prix par kg', iconAsset: 'tag'),
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
                        activeColor: cs.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Tarif au kilo',
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Optionnel en mode grille',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
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
                              children: List.generate(kPriceOptions.length, (i) {
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
                                              DonyRadius.lg),
                                          border: Border.all(
                                            color: selected
                                                ? cs.success
                                                : cs.outline,
                                            width: selected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${kPriceOptions[i].toStringAsFixed(0)}€',
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
                                priceOptionNotifier.value =
                                    kPriceOptions.length;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
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
                                  color:
                                      isCustom ? cs.successLight : cs.surface,
                                  borderRadius:
                                      BorderRadius.circular(DonyRadius.lg),
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
                                    Text(
                                      'Autre prix',
                                      style: tt.bodyMedium?.copyWith(
                                        color: isCustom
                                            ? cs.success
                                            : cs.onSurfaceVariant,
                                        fontWeight: isCustom
                                            ? FontWeight.w600
                                            : FontWeight.normal,
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
                                label: 'Prix par kg',
                                hint: 'ex: 12',
                                controller: customPriceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                      right: DonySpacing.md),
                                  child: Text('€/kg',
                                      style: tt.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant)),
                                ),
                                onChanged: (v) {
                                  final parsed =
                                      double.tryParse(v.replaceAll(',', '.'));
                                  if (parsed != null && parsed > 0) {
                                    customPriceNotifier.value = parsed;
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: DonySpacing.sm),
                            Text(
                              selectedIdx == -1
                                  ? 'Sélectionnez un prix pour voir l\'estimation'
                                  : kg == 0
                                      ? 'Capacité illimitée : estimation selon la demande'
                                      : 'Vous touchez ${travelerNet.toStringAsFixed(0)}€ · l\'expéditeur paie ${senderTotal.toStringAsFixed(0)}€',
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
                final corridor =
                    (dep != null && arr != null) ? '$dep – $arr' : null;
                return PriceHintWidget(
                  marketMedianPrice: 8.0,
                  warning: formState.priceWarning,
                  corridor: corridor,
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
                Container(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ma grille · ${formState.gridPreviewItems.length} article${formState.gridPreviewItems.length == 1 ? '' : 's'}',
                            style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant),
                          ),
                          GestureDetector(
                            onTap: () =>
                                context.push('/profile/price-grid'),
                            child: Text(
                              'Modifier →',
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.primary),
                            ),
                          ),
                        ],
                      ),
                      if (formState.gridPreviewItems.isNotEmpty) ...[
                        const SizedBox(height: DonySpacing.sm),
                        ...formState.gridPreviewItems.map(
                          (item) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item.label,
                                    style: tt.bodySmall),
                                Text(
                                  '${item.unitPriceDisplay.toStringAsFixed(2)} €',
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: DonySpacing.sm),
                        Text(
                          'Aucun article configuré',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Text(
                    'Dony ajoute $donyCommissionPercentLabel % sur chaque article et sur le prix au kilo',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.primary),
                  ),
                ),
              ],
            );
          },
        ),
        ], // fin du bloc prix (masqué quand lockPrice)
        const SizedBox(height: DonySpacing.xxl),

        // ── MODES DE PAIEMENT ACCEPTÉS ────────────────────────────────────────
        // Masqué dans le flux trajet dédié : le mode de paiement est déjà fixé
        // par la négociation (lockContext.paymentMethod).
        if (showPaymentMethods) ...[
        const CaSectionLabel(
          label: 'Modes de paiement acceptés',
          iconAsset: 'banknote',
        ),
        const SizedBox(height: DonySpacing.sm),
        BlocBuilder<StripeAccountBloc, StripeAccountState>(
          builder: (ctx, stripeState) {
            final isStripeConfigured = stripeState is StripeAccountReady &&
                stripeState.accountStatus.isComplete;

            if (!isStripeConfigured) {
              // Sans Stripe configuré, les espèces sont la seule méthode
              // disponible : on force le notifier à ON (au moins une méthode
              // de paiement est requise pour publier). Post-frame pour éviter
              // toute mutation d'état pendant la phase de build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                cashEnabledNotifier.value = true;
              });
              return _buildStripeNotConfiguredPaymentSection(tt, cs, ctx);
            }

            return CaSectionCard(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('payment-method-stripe'),
                        value: true,
                        onChanged: null,
                        activeThumbColor: cs.primary,
                        title: Row(
                          children: [
                            const DonyIcon('credit-card', size: 18),
                            const SizedBox(width: DonySpacing.sm),
                            Text(
                              'Carte bancaire (Stripe)',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(width: DonySpacing.xs),
                            DonyIcon('lock',
                                size: 14, color: cs.onSurfaceVariant),
                          ],
                        ),
                        subtitle: Text(
                          'Paiement sécurisé par défaut',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.base,
                          vertical: DonySpacing.xs,
                        ),
                      ),
                      const CaRowDivider(),
                      // La carte de commission n'est plus requise à la création d'annonce.
                      // La vérification (wallet ou carte) est reportée à l'acceptation du bid.
                      ValueListenableBuilder<bool>(
                        valueListenable: cashEnabledNotifier,
                        builder: (context, cashEnabled, _) {
                          return Column(
                            children: [
                              SwitchListTile(
                                key: const Key('payment-method-cash'),
                                value: cashEnabled,
                                onChanged: (val) =>
                                    cashEnabledNotifier.value = val,
                                activeThumbColor: cs.primary,
                                title: Row(
                                  children: [
                                    const DonyIcon('banknote',
                                        size: 18),
                                    const SizedBox(width: DonySpacing.sm),
                                    Text(
                                      'Espèces',
                                      style: tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'Commission prélevée au voyageur à la remise',
                                  style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
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
                                child: cashEnabled
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          DonySpacing.base,
                                          0,
                                          DonySpacing.base,
                                          DonySpacing.md,
                                        ),
                                        child: const CashCommissionNotice()
                                            .animate()
                                            .fadeIn(duration: 200.ms),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
          },
        ).animate().fadeIn(delay: 180.ms),
        const SizedBox(height: DonySpacing.xxl),
        ], // fin de la section paiement (masquée quand !showPaymentMethods)

        // ── CE QUE J'ACCEPTE ──────────────────────────────────────────────────
        const CaSectionLabel(
            label: 'Ce que j\'accepte',
            iconAsset: 'circle-check'),
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
                .map((label) => ContentCategory(
                      code: label,
                      label: label,
                      emoji: emojiForLabel(label),
                    ))
                .toList();
            final catalogSet = catalogLabels.toSet();
            final combinedSelected = <String>{
              ...selectedContentNotifier.value,
              ...customAcceptedNotifier.value,
            }.toList();

            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: ContentCategoryComboBox(
                  keyPrefix: 'accepted-content',
                  catalog: catalog,
                  selected: combinedSelected,
                  onChanged: (labels) {
                    final labelSet = labels.toSet();
                    selectedContentNotifier.value =
                        labelSet.where(catalogSet.contains).toSet();
                    customAcceptedNotifier.value = labelSet
                        .where((l) => !catalogSet.contains(l))
                        .toSet();
                  },
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 120.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── CE QUE JE REFUSE ──────────────────────────────────────────────────
        const CaSectionLabel(
            label: 'Ce que je refuse', iconAsset: 'ban'),
        const SizedBox(height: DonySpacing.sm),
        ListenableBuilder(
          listenable: Listenable.merge([
            refusedTypesNotifier,
            catalogLabelsNotifier,
          ]),
          builder: (context, _) {
            final catalogLabels = catalogLabelsNotifier.value;
            final catalog = catalogLabels
                .map((label) => ContentCategory(
                      code: label,
                      label: label,
                      emoji: emojiForLabel(label),
                    ))
                .toList();

            return CaSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(DonySpacing.base),
                child: ContentCategoryComboBox(
                  keyPrefix: 'refused-content',
                  catalog: catalog,
                  selected: refusedTypesNotifier.value.toList(),
                  hint: 'Ex: Liquides, Denrées périssables…',
                  onChanged: (labels) =>
                      refusedTypesNotifier.value = labels.toSet(),
                ),
              ),
            );
          },
        ).animate().fadeIn(delay: 140.ms),
        const SizedBox(height: DonySpacing.xxl),

        // ── NOTE AUX EXPÉDITEURS ──────────────────────────────────────────────
        const CaSectionLabel(
            label: 'Note aux expéditeurs', iconAsset: 'notebook-pen'),
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
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      decoration: InputDecoration(
                        hintText:
                            'Ex: Je préfère les colis bien emballés. Contactez-moi avant le départ.',
                        hintStyle: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
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
                      style:
                          tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

  // Cash libre et forcé ON ; carte verrouillée OFF avec CTA d'activation
  // Stripe. Publier sans Stripe est autorisé (D3/D4) — seul le paiement par
  // carte requiert l'onboarding Stripe complet.
  Widget _buildStripeNotConfiguredPaymentSection(
    TextTheme tt,
    ColorScheme cs,
    BuildContext ctx,
  ) {
    return CaSectionCard(
      child: Column(
        children: [
          // ── Bannière info ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.successLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DonyRadius.card),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DonyIcon('circle-check', color: cs.success, size: 18),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    'Publiez en espèces dès maintenant. Connectez Stripe '
                    'pour accepter aussi la carte.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                GestureDetector(
                  key: const Key('activate-card-payments-cta'),
                  onTap: () => ctx.push('/connect/onboarding/intro'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                      vertical: DonySpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(DonyRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Activer les paiements par carte',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Icon(
                          DonyIcons.arrowRight,
                          size: 14,
                          color: cs.onPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Ligne Carte bancaire (verrouillée OFF) ────────────────────────
          SwitchListTile(
            key: const Key('payment-method-stripe'),
            value: false,
            onChanged: null,
            title: Row(
              children: [
                DonyIcon('credit-card',
                    size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  'Carte bancaire (Stripe)',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
              ],
            ),
            subtitle: Text(
              'Non configuré, activez pour proposer le paiement sécurisé',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs,
            ),
          ),
          const CaRowDivider(),
          // ── Ligne Espèces (forcée ON, non désactivable) ───────────────────
          SwitchListTile(
            key: const Key('payment-method-cash'),
            value: true,
            onChanged: null,
            activeThumbColor: cs.primary,
            title: Row(
              children: [
                const DonyIcon('banknote', size: 18),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  'Espèces',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Commission prélevée au voyageur à la remise',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.xs,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              0,
              DonySpacing.base,
              DonySpacing.md,
            ),
            child: const CashCommissionNotice().animate().fadeIn(
                  duration: 200.ms,
                ),
          ),
        ],
      ),
    );
  }
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
                  )
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
                  'Prix fixé par la négociation',
                  style: tt.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  "Le montant de ce colis a été convenu avec l'expéditeur, "
                  'non modifiable ici.',
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
  const _LockedAgreedPriceCard({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
                  'Prix total convenu',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  '${amount.toStringAsFixed(0)} €',
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
