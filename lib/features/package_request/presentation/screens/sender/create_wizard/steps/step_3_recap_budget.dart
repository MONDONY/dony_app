import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/pricing/pricing_labels.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_field_mark.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/payment_setup_notice.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/wizard_currency.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Étape 3 / 3 — Budget & photo (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Budget" · récap · choix du mode de prix · budget requis ·
/// aperçu net voyageur · modes de paiement · mention CGU au-dessus du CTA.
class Step3RecapBudget extends StatefulWidget {
  const Step3RecapBudget({
    super.key,
    this.canContinueNotifier,
    this.currency,
    this.mobileMoneyAccountActive,
    this.onMobileMoneySetupReturned,
  });

  /// Piloté par l'étape, lu par le bouton « Publier » de la coque.
  final ValueNotifier<bool>? canContinueNotifier;
  final SupportedCurrency? currency;

  /// Le compte mobile money de l'expéditeur est-il configuré et actif ?
  /// Une demande qui accepte le mobile money ne part pas sans lui
  /// (FLUTTER-B2). `null` : état inconnu, l'étape ne bloque rien.
  final bool? mobileMoneyAccountActive;

  /// Appelé au retour de l'écran d'activation, pour recharger le compte.
  final VoidCallback? onMobileMoneySetupReturned;

  @override
  State<Step3RecapBudget> createState() => Step3RecapBudgetState();
}

class Step3RecapBudgetState extends State<Step3RecapBudget> {
  final _formKey = GlobalKey<FormState>();
  final _budgetFieldKey = GlobalKey();
  final _budgetCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();

  // NegotiationQuote une fois chargé, String si le dernier essai de promo a
  // échoué (message affiché inline), null tant qu'aucun devis serveur n'est
  // arrivé (l'aperçu retombe alors sur l'estimation locale instantanée).
  final _quoteNotifier = ValueNotifier<Object?>(null);
  final _quoteLoadingNotifier = ValueNotifier<bool>(false);

  /// Grille de commission figée de la demande éditée, `null` en création ou
  /// tant qu'elle n'est pas lue : la grille en vigueur s'applique alors.
  late final ValueNotifier<CommissionGrid?> _frozenGridNotifier;

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (édition / retour à l'étape) du budget brut depuis l'état.
    final s = context.read<PackageRequestFormBloc>().state;
    _frozenGridNotifier = ValueNotifier(
      CommissionGridStore.byId(s.commissionGridId),
    );
    // La grille figée peut arriver après l'ouverture : le bouton se recale.
    _frozenGridNotifier.addListener(_sync);
    _loadFrozenGrid(s.commissionGridId);
    final b = s.totalBudgetEur;
    if (b != null) {
      _budgetCtrl.text = b == b.roundToDouble()
          ? b.toInt().toString()
          : b.toStringAsFixed(2);
    }
    if (s.promoCode != null) {
      _promoCtrl.text = s.promoCode!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync();
      // Seed la devise dans le bloc si elle n'y est pas déjà : sans ce sync,
      // une demande jamais retouchée par l'utilisateur partirait sans
      // devise, alors que la borne d'affichage (widget.currency) en montre
      // déjà une. Absent en édition : la devise d'une demande déjà créée ne
      // se change pas ici (cf. PackageRequestFormBloc._onStep3, currency
      // n'est envoyée qu'à la création).
      final formBloc = context.read<PackageRequestFormBloc>();
      if (formBloc.state.currency == null && !s.isEditing) {
        formBloc.add(
          PackageRequestCurrencyChanged(_resolveCurrency(formBloc.state)),
        );
      }
    });
  }

  /// Devise EFFECTIVE de cette demande — même résolution qu'en [build] :
  /// celle du bloc une fois choisie, repli sur celle transmise par l'écran
  /// parent tant que le sync post-frame de [initState] n'est pas encore
  /// passé, puis sur la devise active, puis l'euro.
  ///
  /// Centralisée ici : [_sync] et [submit] tournent hors du `BlocBuilder` de
  /// [build] et doivent donc résoudre la devise eux-mêmes plutôt que de
  /// comparer un montant saisi dans N'IMPORTE QUELLE devise aux bornes
  /// euros de [PackageRequestLimits] — précisément le bug corrigé ici.
  SupportedCurrency _resolveCurrency(PackageRequestFormState s) =>
      resolveWizardCurrency(s, fallback: widget.currency);

  /// Grille de commission de cette demande : celle figée à sa création en
  /// édition (le back recalcule le net d'un nouveau budget sur elle), sinon
  /// la grille en vigueur. `null` sans grille : taux unique historique.
  CommissionGrid? get _requestGrid =>
      _legacyPricing(context.read<PackageRequestFormBloc>().state)
      ? null
      : _frozenGridNotifier.value ?? activeCommissionGrid;

  /// Demande existante créée avant les paliers (aucune grille figée) : le
  /// back recalcule son net au taux unique, l'aperçu fait de même. La grille
  /// en vigueur ne vaut que pour une nouvelle demande.
  static bool _legacyPricing(PackageRequestFormState s) =>
      s.isEditing && s.commissionGridId == null;

  /// Lit la grille figée [id] quand l'app ne la connaît pas encore. Un échec
  /// laisse la grille en vigueur s'appliquer.
  void _loadFrozenGrid(String? id) {
    if (id == null || _frozenGridNotifier.value != null) return;
    if (!getIt.isRegistered<IConfigRepository>()) return;
    final config = getIt<IConfigRepository>();
    unawaited(
      CommissionGridStore.ensure(id, config.getCommissionGridById).then((grid) {
        if (mounted && grid != null) _frozenGridNotifier.value = grid;
      }),
    );
  }

  /// Le bouton ne doit être actif que si la publication peut réellement
  /// aboutir : il l'était dès qu'un montant était saisi, y compris hors
  /// bornes, et la publication échouait ensuite sans un mot.
  void _sync() {
    if (!mounted) return;
    final s = context.read<PackageRequestFormBloc>().state;
    widget.canContinueNotifier?.value =
        PackageRequestLimits.isBudgetValid(
          s.totalBudgetEur,
          _resolveCurrency(s),
          grid: _requestGrid,
          legacy: _legacyPricing(s),
        ) &&
        !_mobileMoneyAccountMissing(s);
  }

  /// Le mobile money est coché, possible dans la devise, et l'expéditeur n'a
  /// pas de compte mobile money actif : la demande ne peut pas partir.
  bool _mobileMoneyAccountMissing(PackageRequestFormState s) =>
      widget.mobileMoneyAccountActive == false &&
      _resolveCurrency(s).isMobileMoneyEligible &&
      s.acceptedPaymentMethods.contains(PaymentMethod.mobileMoney);

  Future<void> _applyPromoCode() async {
    final state = context.read<PackageRequestFormBloc>().state;
    final budget = state.totalBudgetEur;
    if (budget == null) return;
    final code = _promoCtrl.text.trim();
    _quoteLoadingNotifier.value = true;
    try {
      // La devise de la demande : sous grille, elle choisit le minimum de
      // frais de service du devis (ignorée par un back sans grille).
      final quote = await getIt<PackageRequestRepository>().quote(
        budget,
        promoCode: code.isEmpty ? null : code,
        currency: _resolveCurrency(state).code,
      );
      _quoteNotifier.value = quote;
      // Persisté dans l'état du formulaire dès validation réussie — envoyé à
      // la publication, appliqué automatiquement au paiement (jamais resaisi,
      // cf. AcceptOfferBottomSheet).
      if (mounted) {
        context.read<PackageRequestFormBloc>().add(
          PackageRequestPromoCodeChanged(code.isEmpty ? null : code),
        );
      }
    } catch (e) {
      _quoteNotifier.value = code.isEmpty
          ? null
          : ErrorPresenter.resolve(
              e,
              l10n: mounted ? context.l10n : null,
            ).message;
    } finally {
      _quoteLoadingNotifier.value = false;
    }
  }

  /// Ramène le champ budget à l'écran quand la publication est refusée : le
  /// champ peut être hors de vue, sous l'aperçu qui vient de se refermer.
  void _scrollToBudgetField() {
    final ctx = _budgetFieldKey.currentContext;
    if (ctx == null) return;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      ),
    );
  }

  /// Le budget a changé → l'aperçu (chargé pour l'ANCIEN montant) est périmé.
  /// Retombe sur l'estimation locale instantanée jusqu'au prochain "Appliquer".
  void _invalidateQuote() {
    if (_quoteNotifier.value != null) _quoteNotifier.value = null;
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _promoCtrl.dispose();
    _quoteNotifier.dispose();
    _quoteLoadingNotifier.dispose();
    _frozenGridNotifier
      ..removeListener(_sync)
      ..dispose();
    super.dispose();
  }

  void submit({bool saveAsDraft = false}) {
    final state = context.read<PackageRequestFormBloc>().state;
    // Backstop : le bouton est déjà grisé, l'encart sous les modes de
    // paiement explique pourquoi et mène à l'activation.
    if (_mobileMoneyAccountMissing(state)) return;
    if (!_formKey.currentState!.validate() ||
        !PackageRequestLimits.isBudgetValid(
          state.totalBudgetEur,
          _resolveCurrency(state),
          grid: _requestGrid,
          legacy: _legacyPricing(state),
        )) {
      // Backstop : le bouton « Aperçu » est déjà grisé dans ce cas. `validate()`
      // vient d'afficher le message sous le champ ; on y ramène l'utilisateur,
      // car l'aperçu qui se referme le laissait sinon devant un « Publier »
      // qui ne produisait rien.
      _scrollToBudgetField();
      return;
    }
    final photosCubit = context.read<PackageRequestPhotosCubit>();
    context.read<PackageRequestFormBloc>().add(
      FormStep3Submitted(
        // touched=false (aucune photo manipulée) → null = conserver en édition.
        photoKeys: photosCubit.touched ? photosCubit.readyKeys : null,
        saveAsDraft: saveAsDraft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
      builder: (context, state) {
        // Rejoue la synchro du bouton sticky à chaque changement d'état
        // (prix, mode, etc.) — le seul appel dans initState/toggle ratait
        // le cas "prix tapé après avoir choisi le mode ferme".
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        final currency = _resolveCurrency(state);
        final l10n = context.l10n;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.md,
            DonySpacing.lg,
            DonySpacing.huge,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.requestPublicBudget,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l10n.requestCreateBudgetSubtitle,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.lg),

                // ── Récap (beige bg) ───────────────────────────────────────
                WizardSummaryCard(state: state),
                const SizedBox(height: DonySpacing.base),

                // ── Choix du mode de prix ──────────────────────────────────
                // Deux cartes plutôt qu'un interrupteur : chacune annonce sa
                // conséquence, et c'est le choix qui porte la règle du budget
                // obligatoire. Auparavant le champ était annoncé « optionnel »
                // puis refusé à la publication.
                _FieldLabel(l10n.requestCreatePriceModeLabel),
                const SizedBox(height: DonySpacing.sm),
                _PriceModeChoice(
                  negotiable: state.negotiable,
                  onChanged: (v) {
                    context.read<PackageRequestFormBloc>().add(
                      PackageRequestNegotiableToggled(v),
                    );
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _sync(),
                    );
                  },
                ),
                const SizedBox(height: DonySpacing.base),

                // ── Devise ─────────────────────────────────────────────────
                // Figée une fois la demande créée : elle ne se change plus en
                // édition, exactement comme côté trajet.
                if (!state.isEditing) ...[
                  _FieldLabel(l10n.requestCreateCurrencyLabel),
                  const SizedBox(height: DonySpacing.sm),
                  _CurrencySelectionRow(currency: currency),
                  const SizedBox(height: DonySpacing.base),
                ],

                // ── Budget ─────────────────────────────────────────────────
                AiFieldMark(
                  fields: const ['totalBudget'],
                  child: _FieldLabel(
                    state.negotiable
                        ? l10n.requestCreateBudgetLabelNegotiable
                        : l10n.requestCreateBudgetLabelFixed,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                ValueListenableBuilder<CommissionGrid?>(
                  valueListenable: _frozenGridNotifier,
                  builder: (context, frozenGrid, _) => _BudgetTotalInput(
                    key: _budgetFieldKey,
                    controller: _budgetCtrl,
                    onBudgetChanged: _invalidateQuote,
                    currency: currency,
                    grid: _legacyPricing(state)
                        ? null
                        : frozenGrid ?? activeCommissionGrid,
                    legacy: _legacyPricing(state),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Text(
                    state.negotiable
                        ? l10n.requestCreateBudgetHintNegotiable
                        : l10n.requestCreateBudgetHintFixed,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),

                // ── Net voyageur : décomposition transparente ───────────────
                if (state.totalBudgetEur != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _quoteNotifier,
                      _frozenGridNotifier,
                    ]),
                    builder: (context, _) {
                      final quoteVal = _quoteNotifier.value;
                      final quote = quoteVal is NegotiationQuote
                          ? quoteVal
                          : null;
                      return _BudgetBreakdown(
                        budgetEur: state.totalBudgetEur!,
                        quote: quote,
                        currency: currency,
                        grid: _requestGrid,
                        editing: state.isEditing,
                      );
                    },
                  ),
                  const SizedBox(height: DonySpacing.base),

                  // ── Code promo ────────────────────────────────────────────
                  _FieldLabel(l10n.requestCreatePromoLabel),
                  const SizedBox(height: DonySpacing.sm),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _quoteNotifier,
                      _quoteLoadingNotifier,
                    ]),
                    builder: (context, _) {
                      final loading = _quoteLoadingNotifier.value;
                      final quoteVal = _quoteNotifier.value;
                      final quote = quoteVal is NegotiationQuote
                          ? quoteVal
                          : null;
                      final promoError = quoteVal is String ? quoteVal : null;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const Key('promo-code-input'),
                                  controller: _promoCtrl,
                                  scrollPadding: kDonyKeyboardScrollPadding,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: l10n.requestCreatePromoHint,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: DonySpacing.base,
                                      vertical: DonySpacing.md,
                                    ),
                                    suffixIcon: loading
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  onFieldSubmitted: (_) => _applyPromoCode(),
                                ),
                              ),
                              const SizedBox(width: DonySpacing.sm),
                              SizedBox(
                                height: 52,
                                width: 110,
                                child: FilledButton(
                                  key: const Key('apply-promo-code-btn'),
                                  onPressed: loading ? null : _applyPromoCode,
                                  child: Text(l10n.commonApply),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            l10n.promoCodeNotReferralHint,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (quote != null && quote.promoApplied) ...[
                            const SizedBox(height: DonySpacing.xs),
                            Row(
                              children: [
                                DonyIcon(
                                  'circle-check',
                                  size: 16,
                                  color: cs.success,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    quote.promoLabel ??
                                        l10n.requestCreatePromoAppliedFallback,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Code valide, mais le minimum de frais de service
                          // annule tout le gain : indice, sans style d'erreur.
                          if (quote != null &&
                              quote.promoIneffectiveBecauseMinimum) ...[
                            const SizedBox(height: DonySpacing.xs),
                            Row(
                              key: const Key('request-promo-ineffective'),
                              children: [
                                DonyIcon(
                                  'info',
                                  size: 16,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.promoIneffectiveCommissionMinimum,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (promoError != null) ...[
                            const SizedBox(height: DonySpacing.xs),
                            Row(
                              children: [
                                DonyIcon(
                                  'circle-alert',
                                  size: 16,
                                  color: cs.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    promoError,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: DonySpacing.base),

                // ── Modes de paiement ──────────────────────────────────────
                AiFieldMark(
                  fields: const ['acceptedPaymentMethods'],
                  child: _FieldLabel(l10n.requestCreatePaymentAcceptedLabel),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l10n.requestCreatePaymentHint,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),
                _PaymentMethodChips(
                  selected: state.acceptedPaymentMethods,
                  currency: currency,
                ),
                if (_mobileMoneyAccountMissing(state)) ...[
                  const SizedBox(height: DonySpacing.sm),
                  PaymentSetupNotice(
                    key: const Key('request-mobile-money-setup-notice'),
                    message: l10n.requestCreateMobileMoneyAccountRequired,
                    ctaLabel: l10n.requestCreateMobileMoneyAccountCta,
                    ctaKey: const Key('request-activate-mobile-money-cta'),
                    onCtaTap: () async {
                      await context.push<void>(
                        '/payments/mobile-money/account',
                      );
                      if (mounted) widget.onMobileMoneySetupReturned?.call();
                    },
                  ),
                ],
                const SizedBox(height: DonySpacing.base),

                // L'écran s'arrêtait sur la mention CGU, qui répond à une
                // obligation légale, pas à « et maintenant ? ».
                Container(
                  padding: const EdgeInsets.all(DonySpacing.md),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DonyIcon('send', size: 16, color: cs.primary),
                      const SizedBox(width: DonySpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.requestCreatePublishInfoBanner,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Le CTA « Publier ma demande » + la mention CGU sont portés par
                // la barre sticky du wizard (_StickyCta) — pas de bouton inline ici.
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Devise ─────────────────────────────────────────────────────────────────

/// Ligne tappable ouvrant le sélecteur de devise partagé. Aucun voyageur
/// n'est encore choisi à ce stade (la demande est publiée avant tout
/// matching) : les rails carte et mobile money prévisualisés dépendent donc
/// seulement de la devise (`SupportedCurrency.isStripeEligible`,
/// `SupportedCurrency.isMobileMoneyEligible`), pas d'un compte Connect ou
/// d'un compte mobile money précis. Le serveur retranchera ce qu'il faut au
/// moment du paiement réel.
class _CurrencySelectionRow extends StatelessWidget {
  const _CurrencySelectionRow({required this.currency});

  final SupportedCurrency currency;

  List<CurrencyPaymentOption> get _options => [
    for (final c in SupportedCurrency.values)
      CurrencyPaymentOption(
        currency: c,
        availablePaymentMethods: {
          BidPaymentMethod.cash,
          if (c.isStripeEligible) BidPaymentMethod.stripe,
          if (c.isMobileMoneyEligible) BidPaymentMethod.mobileMoney,
        },
      ),
  ];

  Future<void> _openSelector(BuildContext context) async {
    final formBloc = context.read<PackageRequestFormBloc>();
    final selected = await CurrencySelector.show(
      context,
      options: _options,
      initialCurrency: currency,
    );
    if (selected != null) {
      formBloc.add(PackageRequestCurrencyChanged(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.requestCreateCurrencySemanticLabel(
        currency.name(l10n),
        currency.code,
      ),
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('package-request-currency-selector-row'),
          borderRadius: BorderRadius.circular(DonyRadius.md),
          onTap: () => unawaited(_openSelector(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                DonyIcon('banknote', size: 18, color: cs.primary),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: Text(
                    '${currency.name(l10n)} (${currency.code})',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.requestCreateChangeCurrency,
                  style: tt.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
      ),
    );
  }
}

// ─── Budget total input ──────────────────────────────────────────────────────

class _BudgetTotalInput extends StatelessWidget {
  const _BudgetTotalInput({
    super.key,
    required this.controller,
    this.onBudgetChanged,
    required this.currency,
    this.grid,
    this.legacy = false,
  });
  final TextEditingController controller;
  final SupportedCurrency? currency;

  /// Grille de commission de la demande, `null` sans grille.
  final CommissionGrid? grid;

  /// Demande existante antérieure aux paliers : taux unique, sans minimum.
  final bool legacy;

  /// Prévient le parent qu'un devis chargé précédemment est périmé.
  final VoidCallback? onBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return TextFormField(
      key: const Key('total-budget-input'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      scrollPadding: kDonyKeyboardScrollPadding,
      // Le « touched » natif : le message n'apparaît qu'après une première
      // interaction, sans drapeau ni second afficheur d'erreur à tenir.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: cs.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md + 2,
        ),
        hintText: l10n.requestCreateBudgetInputHint,
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        suffixText: currency?.symbol,
        suffixStyle: tt.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: cs.onSurfaceVariant,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),
      onChanged: (text) {
        final value = double.tryParse(text.replaceAll(',', '.'));
        context.read<PackageRequestFormBloc>().add(
          PackageRequestTotalBudgetChanged(value),
        );
        onBudgetChanged?.call();
      },
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return l10n.requestCreateBudgetEmpty;
        }
        final d = double.tryParse(v.replaceAll(',', '.'));
        final effectiveCurrency = currency ?? SupportedCurrency.eur;
        if (!PackageRequestLimits.isBudgetValid(
          d,
          effectiveCurrency,
          grid: grid,
          legacy: legacy,
        )) {
          // Dans les bornes, mais sous les frais de service minimum de la
          // grille : le back refuserait la demande (422).
          final minimum = legacy
              ? null
              : grid?.minimumFor(effectiveCurrency.code);
          if (minimum != null &&
              PackageRequestLimits.isBelowCommissionMinimum(
                d,
                effectiveCurrency,
                grid: grid,
                legacy: legacy,
              )) {
            return l10n.requestBudgetBelowCommissionMinimum(
              CurrencyFormatter.format(minimum, effectiveCurrency),
            );
          }
          final min = CurrencyFormatter.formatOrPlain(
            PackageRequestLimits.minBudgetFor(effectiveCurrency),
            currency,
          );
          final max = CurrencyFormatter.formatOrPlain(
            PackageRequestLimits.maxBudgetFor(effectiveCurrency),
            currency,
          );
          return l10n.requestCreateBudgetRange(min, max);
        }
        return null;
      },
    );
  }
}

// ─── Net preview ─────────────────────────────────────────────────────────────

/// Décomposition transparente du budget public (TTC) de la demande.
///
/// Sous grille de commission, le budget contient le net du voyageur (le plus
/// grand net dont le total tient dans le budget, celui que le back stockera)
/// et les frais de service Yadony, minimum compris. Un code promo baisse alors
/// ce que paie l'expéditeur (devis de budget, spec §5.4) : les frais du devis
/// sont après code, une ligne de réduction et « Vous paierez » le disent.
///
/// Sans grille, chemin historique : la commission reste au taux de base et
/// c'est le net voyageur qui bouge quand un code promo est appliqué (le
/// budget de l'expéditeur ne change pas, cf. PackageRequestService.quote).
class _BudgetBreakdown extends StatelessWidget {
  const _BudgetBreakdown({
    required this.budgetEur,
    this.quote,
    required this.currency,
    this.grid,
    this.editing = false,
  });

  final double budgetEur;
  final NegotiationQuote? quote;
  final SupportedCurrency? currency;

  /// Grille de la demande (figée en édition, sinon en vigueur) ; `null` sans
  /// grille ou pour une demande existante antérieure aux paliers.
  final CommissionGrid? grid;

  /// Demande existante : le devis du back suit la grille en vigueur, ses
  /// montants ne valent que s'il porte la grille figée de la demande.
  final bool editing;

  /// Devis dont les montants valent pour cette demande.
  NegotiationQuote? get _amountQuote {
    final q = quote;
    if (q == null || !editing) return q;
    return q.commissionGridId == grid?.id ? q : null;
  }

  @override
  Widget build(BuildContext context) {
    final cur = currency ?? SupportedCurrency.eur;
    final q = _amountQuote;
    final underGrid =
        q?.commissionGridId != null || grid?.minimumFor(cur.code) != null;
    return underGrid ? _gridBreakdown(context, cur, q) : _legacy(context);
  }

  Widget _gridBreakdown(
    BuildContext context,
    SupportedCurrency cur,
    NegotiationQuote? q,
  ) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    String fmt(double v) => CurrencyFormatter.format(v, cur);

    final calcGrid = CommissionGridStore.byId(q?.commissionGridId) ?? grid;
    final net =
        q?.netEur ??
        PackageRequestLimits.netForBudget(budgetEur, cur, grid: calcGrid);
    // Budget sous les frais de service minimum : le message est sous le champ.
    if (net == null) return const SizedBox.shrink();

    // Total sans code promo : celui du budget public.
    final base = senderPriceForNet(net, cur.code, grid: calcGrid);
    final baseGross = base.fromGrid ? base.gross : budgetEur;
    final commission = q?.commissionEur ?? base.commission;
    final total = q?.totalEur ?? baseGross;
    final minimum = q?.minimumApplied ?? base.minimumApplied;
    final discount = baseGross - total;
    // Seul un code saisi et appliqué ouvre une ligne de réduction : sans code,
    // les frais du devis intègrent déjà un éventuel taux spécial.
    final hasDiscount =
        (q?.promoApplied ?? false) && discount > _halfMinorUnit(cur);

    return _card(
      cs,
      children: [
        _line(tt, cs, l10n.requestPublicBudget, fmt(budgetEur)),
        const SizedBox(height: DonySpacing.xs),
        _line(
          tt,
          cs,
          l10n.requestCreateCommissionLabel,
          serviceFeeAmountLabel(l10n, commission, cur.code, minimum: minimum),
        ),
        if (hasDiscount) ...[
          const SizedBox(height: DonySpacing.xs),
          _line(
            tt,
            cs,
            l10n.requestCreatePromoDiscountLabel,
            '−${fmt(discount)}',
          ),
        ],
        const SizedBox(height: DonySpacing.xs),
        Divider(color: cs.success.withValues(alpha: 0.2)),
        const SizedBox(height: DonySpacing.xs),
        _netRow(tt, cs, l10n, fmt(net)),
        if (hasDiscount) ...[
          const SizedBox(height: DonySpacing.xs),
          Row(
            key: const Key('request-budget-you-pay'),
            children: [
              Expanded(
                child: Text(
                  l10n.requestCreateYouPayLabel,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                fmt(total),
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.success,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legacy(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final netBase = PriceDisplay.netFromGross(budgetEur);
    final q = _amountQuote;
    final commissionEur = q?.commissionEur ?? (budgetEur - netBase);
    final net = q?.netEur ?? netBase;
    final promoApplied = q?.promoApplied ?? false;
    final boost = promoApplied ? net - netBase : 0.0;
    final hasRealBoost = boost > 0.005;

    return _card(
      cs,
      children: [
        _line(
          tt,
          cs,
          l10n.requestPublicBudget,
          CurrencyFormatter.formatOrPlain(budgetEur, currency),
        ),
        const SizedBox(height: DonySpacing.xs),
        _line(
          tt,
          cs,
          l10n.requestCreateCommissionLabel,
          CurrencyFormatter.formatOrPlain(commissionEur, currency),
        ),
        if (hasRealBoost) ...[
          const SizedBox(height: DonySpacing.xs),
          _line(
            tt,
            cs,
            l10n.requestCreatePromoBoostLabel,
            '+${CurrencyFormatter.formatOrPlain(boost, currency)}',
            valueColor: cs.success,
          ),
        ],
        const SizedBox(height: DonySpacing.xs),
        Divider(color: cs.success.withValues(alpha: 0.2)),
        const SizedBox(height: DonySpacing.xs),
        _netRow(tt, cs, l10n, CurrencyFormatter.formatOrPlain(net, currency)),
      ],
    );
  }

  /// Moitié de l'unité mineure de [cur] : en dessous, un écart n'est qu'un
  /// reste d'arrondi.
  static double _halfMinorUnit(SupportedCurrency cur) {
    var unit = 1.0;
    for (var i = 0; i < cur.minorUnit; i++) {
      unit /= 10;
    }
    return unit / 2;
  }

  Widget _card(ColorScheme cs, {required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(DonySpacing.base),
    decoration: BoxDecoration(
      color: cs.successLight,
      borderRadius: BorderRadius.circular(DonyRadius.md),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _netRow(
    TextTheme tt,
    ColorScheme cs,
    AppLocalizations l10n,
    String value,
  ) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        l10n.requestCreateTravelerReceivesLabel,
        style: tt.bodyMedium?.copyWith(fontSize: 13, color: cs.success),
      ),
      Text(
        value,
        style: tt.bodyMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: cs.success,
        ),
      ),
    ],
  );

  Widget _line(
    TextTheme tt,
    ColorScheme cs,
    String label,
    String value, {
    Color? valueColor,
  }) => Row(
    children: [
      Expanded(
        child: Text(label, style: tt.bodyMedium?.copyWith(color: cs.success)),
      ),
      const SizedBox(width: DonySpacing.sm),
      Text(
        value,
        style: tt.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: valueColor ?? cs.success,
        ),
      ),
    ],
  );
}

// ─── Negotiable toggle ────────────────────────────────────────────────────────

// ─── Payment method chips ─────────────────────────────────────────────────────

class _PaymentMethodChips extends StatelessWidget {
  const _PaymentMethodChips({required this.selected, required this.currency});
  final Set<PaymentMethod> selected;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // La devise borne les moyens : pas de carte en franc CFA, pas de mobile
    // money hors CFA. Une méthode déjà cochée hors de cette borne (demande en
    // édition : rail retiré comme Wave ou Orange Money, ou devise changée)
    // reste affichée pour que l'expéditeur puisse la décocher, tant qu'il en
    // garde au moins une (canDeselectPaymentMethod).
    final selectable = PaymentMethod.selectableIn(currency);
    final methods = [
      ...selectable,
      ...selected.where((m) => !selectable.contains(m)),
    ];
    // Carte dédiée + icônes + chips plus hauts : la version précédente était
    // une simple ligne de pastilles fines, facile à survoler sans la remarquer.
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: methods.map((method) {
          final isSelected = selected.contains(method);
          final isLastSelected =
              isSelected &&
              !PackageRequestFormBloc.canDeselectPaymentMethod(selected);
          return GestureDetector(
            onTap: () {
              // Le bloc refuse de vider la sélection. Sans ce mot, le refus se
              // lisait comme un tap perdu.
              if (isLastSelected) {
                DonySnackbar.show(
                  context,
                  message: context.l10n.requestCreateKeepOnePaymentMethod,
                );
                return;
              }
              context.read<PackageRequestFormBloc>().add(
                PackageRequestPaymentMethodToggled(method),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isSelected ? cs.primaryContainer : cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.xl),
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: isSelected ? 2 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    method.icon,
                    size: 20,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: DonySpacing.xs + 2),
                  Text(
                    method.label(context.l10n),
                    style: tt.bodyMedium?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: DonySpacing.xs),
                    DonyIcon('circle-check', size: 16, color: cs.primary),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Choix du mode de prix, en deux cartes plutôt qu'un interrupteur.
///
/// Un interrupteur nomme un réglage (« Prix négociable ») ; deux cartes
/// nomment deux conséquences. Surtout, c'est le choix qui porte la règle du
/// budget obligatoire, au lieu de la laisser surgir à la publication.
class _PriceModeChoice extends StatelessWidget {
  const _PriceModeChoice({required this.negotiable, required this.onChanged});

  final bool negotiable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        _PriceModeCard(
          key: const Key('price-mode-open'),
          emoji: '💬',
          title: l10n.requestCreatePriceModeOpenTitle,
          subtitle: l10n.requestCreatePriceModeOpenSubtitle,
          selected: negotiable,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: DonySpacing.sm),
        _PriceModeCard(
          key: const Key('price-mode-fixed'),
          emoji: '🏷️',
          title: l10n.requestCreatePriceModeFixedTitle,
          subtitle: l10n.requestCreatePriceModeFixedSubtitle,
          selected: !negotiable,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _PriceModeCard extends StatelessWidget {
  const _PriceModeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(DonyRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: selected ? cs.primary : cs.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: selected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
