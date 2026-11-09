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
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_field_mark.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/data/per_kilo_pricing.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_palette.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/wizard_currency.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Étape 3 / 3 — Le prix (maquette `sorties/maquettes/demande_etape3.html`).
///
/// Layout : résumé du colis sur une ligne · 1 devise · 2 paiement accepté ·
/// 3 prix (mode, total ou au kilo, champ, frais) · code promo · information de
/// publication. Devise et paiement viennent AVANT le prix : changer la devise
/// change les moyens de paiement et l'unité du prix.
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

  /// « Prix au kilo » choisi : l'utilisateur saisit un prix au kilo, l'app en
  /// déduit le total (poids × prix) et n'envoie que ce total. État de pure
  /// présentation, absent du contrat avec le back.
  final _perKiloMode = ValueNotifier<bool>(false);

  // NegotiationQuote une fois chargé, String si le dernier essai de promo a
  // échoué (message affiché inline), null tant qu'aucun devis serveur n'est
  // arrivé (l'aperçu retombe alors sur l'estimation locale instantanée).
  final _quoteNotifier = ValueNotifier<Object?>(null);
  final _quoteLoadingNotifier = ValueNotifier<bool>(false);

  /// Devis serveur demandé en fond, sans attendre un code promo, pour que les
  /// frais de service affichés au récapitulatif soient ceux qui seront
  /// prélevés (palier + minimum de la grille, appliqués par le back).
  Timer? _backgroundQuoteTimer;

  /// Numéro du dernier devis demandé : une réponse plus ancienne est écartée.
  int _quoteSeq = 0;

  static const _backgroundQuoteDelay = Duration(milliseconds: 400);

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
      _scheduleBackgroundQuote();
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
    // Un devis de fond encore en vol ne doit pas écraser celui-ci.
    _backgroundQuoteTimer?.cancel();
    final seq = ++_quoteSeq;
    _quoteLoadingNotifier.value = true;
    try {
      // La devise de la demande : sous grille, elle choisit le minimum de
      // frais de service du devis (ignorée par un back sans grille).
      final quote = await getIt<PackageRequestRepository>().quote(
        budget,
        promoCode: code.isEmpty ? null : code,
        currency: _resolveCurrency(state).code,
      );
      if (seq != _quoteSeq) return;
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
    _scheduleBackgroundQuote();
  }

  /// Redemande le devis serveur [_backgroundQuoteDelay] après le dernier
  /// changement de budget (et à l'ouverture de l'étape).
  void _scheduleBackgroundQuote() {
    _backgroundQuoteTimer?.cancel();
    _backgroundQuoteTimer = Timer(
      _backgroundQuoteDelay,
      () => unawaited(_fetchBackgroundQuote()),
    );
  }

  /// Devis de fond avec le code promo déjà accepté s'il y en a un. Un échec
  /// garde l'estimation locale, sans message : seul « Appliquer » signale
  /// un code refusé.
  Future<void> _fetchBackgroundQuote() async {
    if (!mounted) return;
    final state = context.read<PackageRequestFormBloc>().state;
    final budget = state.totalBudgetEur;
    if (budget == null || budget <= 0) return;
    final seq = ++_quoteSeq;
    try {
      final quote = await getIt<PackageRequestRepository>().quote(
        budget,
        promoCode: state.promoCode,
        currency: _resolveCurrency(state).code,
      );
      if (!mounted || seq != _quoteSeq) return;
      _quoteNotifier.value = quote;
    } on Object {
      // Estimation locale conservée.
    }
  }

  @override
  void dispose() {
    _backgroundQuoteTimer?.cancel();
    _budgetCtrl.dispose();
    _promoCtrl.dispose();
    _perKiloMode.dispose();
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

  /// Bascule entre « Prix total » et « Prix au kilo » en gardant la valeur
  /// saisie quand c'est possible : total → au kilo si le prix au kilo qui
  /// redonne exactement ce total existe, au kilo → total toujours (le total
  /// calculé devient la valeur du champ).
  void _setPriceBasis(bool perKilo, PackageRequestFormState state) {
    if (_perKiloMode.value == perKilo) return;
    if (perKilo && !PerKiloPricing.isAvailable(state.weightKg)) return;
    final bloc = context.read<PackageRequestFormBloc>();
    final total = state.totalBudgetEur;
    _perKiloMode.value = perKilo;
    if (perKilo) {
      final perKiloValue = PerKiloPricing.perKiloFor(
        total: total,
        weightKg: state.weightKg,
        currency: _resolveCurrency(state),
      );
      _budgetCtrl.text = perKiloValue == null ? '' : _plainNumber(perKiloValue);
      // Le total ne se convertit pas exactement : on repart d'un champ vide
      // plutôt que de changer le total en silence.
      if (total != null && perKiloValue == null) {
        bloc.add(const PackageRequestTotalBudgetChanged(null));
        _invalidateQuote();
      }
    } else {
      _budgetCtrl.text = total == null ? '' : _plainNumber(total);
    }
  }

  static String _plainNumber(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);

    return BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
      builder: (context, state) {
        // Rejoue la synchro du bouton sticky à chaque changement d'état
        // (prix, mode, etc.) — le seul appel dans initState/toggle ratait
        // le cas "prix tapé après avoir choisi le mode ferme".
        WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
        final currency = _resolveCurrency(state);
        final l10n = context.l10n;
        return ValueListenableBuilder<bool>(
          valueListenable: _perKiloMode,
          builder: (context, perKiloChosen, _) {
            final weightKnown = PerKiloPricing.isAvailable(state.weightKg);
            // Sans poids connu, le prix au kilo n'existe pas : on retombe sur
            // le prix total, quoi qu'ait choisi l'utilisateur avant.
            final perKilo = perKiloChosen && weightKnown;
            return _buildBody(context, state, currency, l10n, p, perKilo);
          },
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PackageRequestFormState state,
    SupportedCurrency currency,
    AppLocalizations l10n,
    WizardPalette p,
    bool perKilo,
  ) {
    final weight = state.weightKg;
    final grid = _legacyPricing(state)
        ? null
        : _frozenGridNotifier.value ?? activeCommissionGrid;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, DonySpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Résumé du colis, sur une ligne ─────────────────────────────
            WizardSummaryCard.compact(state: state),
            const SizedBox(height: 8),

            // ── 1 · Devise ─────────────────────────────────────────────────
            // Figée une fois la demande créée : en édition, simple rappel en
            // lecture seule (ni « Changer », ni sélecteur).
            _Zone('1 · ${l10n.requestCreateCurrencyLabel}'),
            if (state.isEditing)
              _CurrencyLockedRow(currency: currency)
            else
              _CurrencySelectionRow(currency: currency),

            // ── 2 · Paiement accepté ───────────────────────────────────────
            AiFieldMark(
              fields: const ['acceptedPaymentMethods'],
              child: _Zone(
                '2 · ${l10n.requestCreatePaymentAcceptedLabel}',
                top: 9,
              ),
            ),
            _PaymentMethodChips(
              selected: state.acceptedPaymentMethods,
              currency: currency,
            ),
            if (_mobileMoneyAccountMissing(state))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _MobileMoneyWarning(
                  key: const Key('request-mobile-money-setup-notice'),
                  message: l10n.requestCreateMobileMoneyAccountRequired,
                  ctaLabel: l10n.requestCreateMobileMoneyAccountCta,
                  onCtaTap: () async {
                    await context.push<void>('/payments/mobile-money/account');
                    if (mounted) widget.onMobileMoneySetupReturned?.call();
                  },
                ),
              ),

            // ── 3 · Prix ───────────────────────────────────────────────────
            AiFieldMark(
              fields: const ['totalBudget'],
              child: _Zone(
                '3 · ${l10n.requestCreatePriceSectionLabel}',
                top: 9,
              ),
            ),
            // Deux cartes plutôt qu'un interrupteur : chacune annonce sa
            // conséquence, et c'est le choix qui porte la règle du prix
            // obligatoire.
            _PriceModeChoice(
              negotiable: state.negotiable,
              onChanged: (v) {
                context.read<PackageRequestFormBloc>().add(
                  PackageRequestNegotiableToggled(v),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
              },
            ),
            const SizedBox(height: 7),
            _PriceBasisSelector(
              perKilo: perKilo,
              perKiloAvailable: PerKiloPricing.isAvailable(weight),
              onChanged: (v) => _setPriceBasis(v, state),
            ),
            if (!PerKiloPricing.isAvailable(weight))
              Padding(
                padding: const EdgeInsets.fromLTRB(1, 3, 1, 0),
                child: Text(
                  l10n.requestCreatePriceBasisPerKiloNeedsWeight,
                  key: const Key('price-basis-per-kilo-hint'),
                  style: WizardPalette.text(
                    size: 11.5,
                    weight: FontWeight.w400,
                    color: p.n600,
                    height: 1.4,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            _BudgetTotalInput(
              key: _budgetFieldKey,
              controller: _budgetCtrl,
              onBudgetChanged: _invalidateQuote,
              currency: currency,
              grid: grid,
              legacy: _legacyPricing(state),
              perKiloWeightKg: perKilo ? weight : null,
              semanticLabel: state.negotiable
                  ? l10n.requestCreateBudgetLabelNegotiable
                  : l10n.requestCreateBudgetLabelFixed,
            ),
            // Prix ferme : ce que les voyageurs verront. La fourchette admise
            // n'est donnée que par l'erreur du champ : le minimum de frais de
            // service n'est jamais cité (YADONY-FLUTTER-PROD-1J).
            if (!state.negotiable) _Hint(l10n.requestCreateBudgetHintFixed),

            // ── Calcul au kilo + frais : le total est ce qui part au back ──
            if (state.totalBudgetEur != null) ...[
              if (perKilo)
                ListenableBuilder(
                  listenable: _budgetCtrl,
                  builder: (context, _) {
                    final perKiloValue = _parseNumber(_budgetCtrl.text);
                    final total = state.totalBudgetEur!;
                    if (perKiloValue == null || weight == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        key: const Key('price-per-kilo-computed'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: p.blue50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.requestCreatePerKiloComputed(
                            formatWeightKg(l10n, weight),
                            CurrencyFormatter.format(
                              perKiloValue,
                              currency,
                              compact: true,
                            ),
                            CurrencyFormatter.format(
                              total,
                              currency,
                              compact: true,
                            ),
                          ),
                          style: WizardPalette.text(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: p.calcText,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _quoteNotifier,
                  _frozenGridNotifier,
                ]),
                builder: (context, _) {
                  final quoteVal = _quoteNotifier.value;
                  final quote = quoteVal is NegotiationQuote ? quoteVal : null;
                  return _BudgetBreakdown(
                    budgetEur: state.totalBudgetEur!,
                    quote: quote,
                    currency: currency,
                    grid: _requestGrid,
                    editing: state.isEditing,
                    priceLabel: perKilo && weight != null
                        ? l10n.requestCreateShipmentPriceWithCalc(
                            formatWeightKg(l10n, weight),
                            CurrencyFormatter.format(
                              _parseNumber(_budgetCtrl.text) ?? 0,
                              currency,
                              compact: true,
                            ),
                          )
                        : l10n.requestCreateShipmentPriceLabel,
                  );
                },
              ),

              // ── Code promo ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Text(
                  l10n.requestCreatePromoLabel,
                  style: WizardPalette.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.n800,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _quoteNotifier,
                  _quoteLoadingNotifier,
                ]),
                builder: (context, _) {
                  final loading = _quoteLoadingNotifier.value;
                  final quoteVal = _quoteNotifier.value;
                  final quote = quoteVal is NegotiationQuote ? quoteVal : null;
                  final promoError = quoteVal is String ? quoteVal : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DonyReplayMask(
                              child: TextFormField(
                                key: const Key('promo-code-input'),
                                controller: _promoCtrl,
                                scrollPadding: kDonyKeyboardScrollPadding,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: WizardPalette.text(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: p.n800,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.requestCreatePromoHint,
                                  hintStyle: WizardPalette.text(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: p.placeholder,
                                  ),
                                  filled: true,
                                  fillColor: p.white,
                                  isDense: true,
                                  constraints: const BoxConstraints(
                                    minHeight: 42,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 11,
                                  ),
                                  border: _fieldBorder(p.border),
                                  enabledBorder: _fieldBorder(p.border),
                                  focusedBorder: _fieldBorder(p.blue),
                                  suffixIcon: loading
                                      ? const Padding(
                                          padding: EdgeInsets.all(10),
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
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 42,
                            width: 92,
                            child: FilledButton(
                              key: const Key('apply-promo-code-btn'),
                              onPressed: loading ? null : _applyPromoCode,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(92, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: WizardPalette.text(
                                  size: 13,
                                  weight: FontWeight.w800,
                                  color: p.white,
                                ),
                              ),
                              child: Text(
                                l10n.commonApply,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _Hint(l10n.promoCodeNotReferralHint),
                      if (quote != null && quote.promoApplied)
                        _PromoNote(
                          quote.promoLabel ??
                              l10n.requestCreatePromoAppliedFallback,
                          color: p.okText,
                        ),
                      // Code valide, mais le minimum de frais de service
                      // annule tout le gain : indice, sans style d'erreur.
                      if (quote != null && quote.promoIneffectiveBecauseMinimum)
                        _PromoNote(
                          l10n.promoIneffectiveCommissionMinimum,
                          color: p.n600,
                          noteKey: const Key('request-promo-ineffective'),
                        ),
                      if (promoError != null)
                        _PromoNote(promoError, color: p.red),
                    ],
                  );
                },
              ),
            ],

            // ── Information de publication ─────────────────────────────────
            // L'écran s'arrêtait sur la mention CGU, qui répond à une
            // obligation légale, pas à « et maintenant ? ».
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.info,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: p.infoBorder),
              ),
              child: Text(
                l10n.requestCreatePublishInfoBanner,
                style: WizardPalette.text(
                  size: 11.5,
                  weight: FontWeight.w400,
                  color: p.n600,
                  height: 1.4,
                ),
              ),
            ),
            // Le CTA « Publier ma demande » + la mention CGU sont portés par
            // la barre sticky du wizard (_StickyCta) — pas de bouton inline ici.
          ],
        ),
      ),
    );
  }
}

double? _parseNumber(String text) => double.tryParse(text.replaceAll(',', '.'));

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(13),
  borderSide: BorderSide(color: color, width: 1.5),
);

/// Intitulé de section de la maquette : « 1 · DEVISE », bleu, 11 px, espacé.
class _Zone extends StatelessWidget {
  const _Zone(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: WizardPalette.text(
          size: 11,
          weight: FontWeight.w800,
          color: WizardPalette.of(context).blue,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Ligne d'aide sous un champ (11,5 px, gris).
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 5, 1, 0),
      child: Text(
        text,
        style: WizardPalette.text(
          size: 11.5,
          weight: FontWeight.w400,
          color: WizardPalette.of(context).n600,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Note sous le code promo : appliqué (vert), sans effet (gris), refusé (rouge).
class _PromoNote extends StatelessWidget {
  const _PromoNote(this.text, {required this.color, this.noteKey});

  final String text;
  final Color color;
  final Key? noteKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: noteKey,
      padding: const EdgeInsets.fromLTRB(1, 5, 1, 0),
      child: Text(
        text,
        style: WizardPalette.text(
          size: 11.5,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Avertissement orange : un mobile money coché sans compte configuré.
class _MobileMoneyWarning extends StatelessWidget {
  const _MobileMoneyWarning({
    super.key,
    required this.message,
    required this.ctaLabel,
    required this.onCtaTap,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.warnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.warnBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: WizardPalette.text(
              size: 11.5,
              weight: FontWeight.w400,
              color: p.warnText,
              height: 1.4,
            ),
          ),
          // Le lien passe sous le texte, jamais à côté : il reste lisible
          // quelle que soit la taille de police choisie par l'utilisateur.
          InkWell(
            key: const Key('request-activate-mobile-money-cta'),
            onTap: onCtaTap,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                ctaLabel,
                style: WizardPalette.text(
                  size: 11.5,
                  weight: FontWeight.w800,
                  color: p.blue,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
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
      grouped: true,
    );
    if (selected != null) {
      formBloc.add(PackageRequestCurrencyChanged(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
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
          borderRadius: BorderRadius.circular(13),
          onTap: () => unawaited(_openSelector(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: p.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: p.border, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${currency.name(l10n)} (${currency.code})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WizardPalette.text(
                      size: 13,
                      weight: FontWeight.w700,
                      color: p.n800,
                    ),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  l10n.requestCreateChangeCurrency,
                  maxLines: 1,
                  softWrap: false,
                  style: WizardPalette.text(
                    size: 12.5,
                    weight: FontWeight.w800,
                    color: p.blue,
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

/// Rappel en lecture seule de la devise figée d'une demande en édition : même
/// gabarit que [_CurrencySelectionRow], fond grisé, sans « Changer » ni action.
class _CurrencyLockedRow extends StatelessWidget {
  const _CurrencyLockedRow({required this.currency});

  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    final l10n = context.l10n;
    return Semantics(
      container: true,
      label: l10n.requestCreateCurrencyLockedSemanticLabel(
        currency.name(l10n),
        currency.code,
      ),
      child: ExcludeSemantics(
        child: Container(
          key: const Key('package-request-currency-locked-row'),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: p.n100,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: p.border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${currency.name(l10n)} (${currency.code})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WizardPalette.text(
                    size: 13,
                    weight: FontWeight.w700,
                    color: p.n800,
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                l10n.requestCreateCurrencyLockedTag,
                maxLines: 1,
                softWrap: false,
                style: WizardPalette.text(
                  size: 11,
                  weight: FontWeight.w700,
                  color: p.n500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Champ du prix ───────────────────────────────────────────────────────────

class _BudgetTotalInput extends StatelessWidget {
  const _BudgetTotalInput({
    super.key,
    required this.controller,
    this.onBudgetChanged,
    required this.currency,
    this.grid,
    this.legacy = false,
    this.perKiloWeightKg,
    this.semanticLabel,
  });
  final TextEditingController controller;
  final SupportedCurrency? currency;

  /// Prévient le parent qu'un devis chargé précédemment est périmé.
  final VoidCallback? onBudgetChanged;

  /// Grille de commission de la demande, `null` sans grille.
  final CommissionGrid? grid;

  /// Demande existante antérieure aux paliers : taux unique, sans minimum.
  final bool legacy;

  /// Poids du colis quand le champ saisit un prix AU KILO ; `null` quand il
  /// saisit le total. Dans les deux cas le bloc ne reçoit que le total.
  final double? perKiloWeightKg;

  /// Libellé lu par les lecteurs d'écran (la maquette n'affiche pas de titre
  /// au-dessus du champ).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    final l10n = context.l10n;
    final perKilo = perKiloWeightKg != null;
    final effectiveCurrency = currency ?? SupportedCurrency.eur;

    /// Total que représente la saisie : elle-même, ou poids × prix au kilo.
    double? totalOf(String text) {
      final value = _parseNumber(text);
      if (!perKilo) return value;
      return PerKiloPricing.totalFor(
        weightKg: perKiloWeightKg,
        perKilo: value,
        currency: effectiveCurrency,
      );
    }

    final symbol = currency?.symbol ?? '';
    final field = DonyReplayMask(
      child: TextFormField(
        key: const Key('total-budget-input'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        scrollPadding: kDonyKeyboardScrollPadding,
        // Le « touched » natif : le message n'apparaît qu'après une première
        // interaction, sans drapeau ni second afficheur d'erreur à tenir.
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: WizardPalette.text(
          size: 18,
          weight: FontWeight.w800,
          color: p.n800,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: p.white,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 46),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11.5,
          ),
          hintText: perKilo
              ? l10n.requestCreatePerKiloInputHint
              : l10n.requestCreateBudgetInputHint,
          hintStyle: WizardPalette.text(
            size: 15,
            weight: FontWeight.w600,
            color: p.placeholder,
          ),
          suffixText: perKilo
              ? l10n.requestCreatePriceUnitPerKilo(symbol)
              : l10n.requestCreatePriceUnitTotal(symbol),
          suffixStyle: WizardPalette.text(
            size: 12,
            weight: FontWeight.w700,
            color: p.n600,
          ),
          errorStyle: WizardPalette.text(
            size: 11.5,
            weight: FontWeight.w700,
            color: p.red,
          ),
          errorMaxLines: 2,
          border: _fieldBorder(p.border),
          enabledBorder: _fieldBorder(p.border),
          focusedBorder: _fieldBorder(p.blue),
          errorBorder: _fieldBorder(p.red),
          focusedErrorBorder: _fieldBorder(p.red),
        ),
        onChanged: (text) {
          // Au kilo ou non, le bloc reçoit le TOTAL : le contrat avec le back
          // ne change pas.
          context.read<PackageRequestFormBloc>().add(
            PackageRequestTotalBudgetChanged(
              perKilo ? totalOf(text) : _parseNumber(text),
            ),
          );
          onBudgetChanged?.call();
        },
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return l10n.requestCreateBudgetEmpty;
          }
          final d = totalOf(v);
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
              // Le minimum n'est jamais cité (YADONY-FLUTTER-PROD-1J).
              return l10n.requestBudgetBelowServiceFee;
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
      ),
    );
    return semanticLabel == null
        ? field
        : Semantics(label: semanticLabel, child: field);
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
    required this.priceLabel,
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

  /// Libellé de la ligne du prix (« Prix de l'envoi », avec le calcul au kilo).
  final String priceLabel;

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
    // Sous grille, ~7 % des budgets ne sont pas atteignables au centime (le
    // total saute de 2 centimes) : le back stocke et prélève le brut
    // atteignable, inférieur au budget saisi. C'est lui qu'on affiche.
    final publicBudget = baseGross < budgetEur ? baseGross : budgetEur;
    final commission = q?.commissionEur ?? base.commission;
    final total = q?.totalEur ?? baseGross;
    final discount = baseGross - total;
    // Seul un code saisi et appliqué ouvre une ligne de réduction : sans code,
    // les frais du devis intègrent déjà un éventuel taux spécial.
    final hasDiscount =
        (q?.promoApplied ?? false) && discount > halfMinorUnit(cur);

    return _card(
      cs,
      children: [
        _line(tt, cs, priceLabel, fmt(publicBudget)),
        const SizedBox(height: 5),
        _line(
          tt,
          cs,
          l10n.requestCreateCommissionLabel,
          serviceFeeAmountLabel(commission, cur.code),
        ),
        if (hasDiscount) ...[
          const SizedBox(height: 5),
          _line(
            tt,
            cs,
            l10n.requestCreatePromoDiscountLabel,
            '−${fmt(discount)}',
          ),
        ],
        _rule(cs),
        _netRow(tt, cs, l10n, fmt(net)),
        if (hasDiscount) ...[
          const SizedBox(height: 5),
          Row(
            key: const Key('request-budget-you-pay'),
            children: [
              Expanded(
                child: Text(
                  l10n.requestCreateYouPayLabel,
                  style: WizardPalette.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: WizardPalette.fromScheme(cs).okText,
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Text(
                fmt(total),
                style: WizardPalette.text(
                  size: 12,
                  weight: FontWeight.w800,
                  color: WizardPalette.fromScheme(cs).okText,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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

    final netBase = netForSenderGross(budgetEur, null, legacy: true);
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
          priceLabel,
          CurrencyFormatter.formatOrPlain(budgetEur, currency),
        ),
        const SizedBox(height: 5),
        _line(
          tt,
          cs,
          l10n.requestCreateCommissionLabel,
          CurrencyFormatter.formatOrPlain(commissionEur, currency),
        ),
        if (hasRealBoost) ...[
          const SizedBox(height: 5),
          _line(
            tt,
            cs,
            l10n.requestCreatePromoBoostLabel,
            '+${CurrencyFormatter.formatOrPlain(boost, currency)}',
            valueColor: WizardPalette.fromScheme(cs).okText,
          ),
        ],
        _rule(cs),
        _netRow(tt, cs, l10n, CurrencyFormatter.formatOrPlain(net, currency)),
      ],
    );
  }

  Widget _card(ColorScheme cs, {required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: WizardPalette.fromScheme(cs).ok,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  /// Filet entre les lignes et le total : 6 px de marge de chaque côté.
  Widget _rule(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(
      height: 1,
      thickness: 1,
      color: WizardPalette.fromScheme(cs).okRule,
    ),
  );

  Widget _netRow(
    TextTheme tt,
    ColorScheme cs,
    AppLocalizations l10n,
    String value,
  ) {
    final p = WizardPalette.fromScheme(cs);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            l10n.requestCreateTravelerReceivesLabel,
            style: WizardPalette.text(
              size: 12,
              weight: FontWeight.w400,
              color: p.okText,
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Text(
          value,
          style: WizardPalette.text(
            size: 21,
            weight: FontWeight.w700,
            color: p.okText,
          ),
        ),
      ],
    );
  }

  Widget _line(
    TextTheme tt,
    ColorScheme cs,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final p = WizardPalette.fromScheme(cs);
    final style = WizardPalette.text(
      size: 12,
      weight: FontWeight.w400,
      color: p.okText,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: DonySpacing.sm),
        Text(value, style: style.copyWith(color: valueColor ?? p.okText)),
      ],
    );
  }
}

// ─── Payment method chips ─────────────────────────────────────────────────────

class _PaymentMethodChips extends StatelessWidget {
  const _PaymentMethodChips({required this.selected, required this.currency});
  final Set<PaymentMethod> selected;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
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
    return Row(
      children: [
        for (var i = 0; i < methods.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PaymentChip(
              method: methods[i],
              isSelected: selected.contains(methods[i]),
              isLastSelected:
                  selected.contains(methods[i]) &&
                  !PackageRequestFormBloc.canDeselectPaymentMethod(selected),
              palette: p,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.method,
    required this.isSelected,
    required this.isLastSelected,
    required this.palette,
  });

  final PaymentMethod method;
  final bool isSelected;
  final bool isLastSelected;
  final WizardPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? p.blue50 : p.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? p.blue : p.border,
              width: 1.5,
            ),
          ),
          child: Text(
            method.label(context.l10n),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WizardPalette.text(
              size: 12,
              weight: FontWeight.w800,
              color: isSelected ? p.blue : p.n600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Choix du mode de prix, en deux cartes côte à côte plutôt qu'un
/// interrupteur.
///
/// Un interrupteur nomme un réglage (« Prix négociable ») ; deux cartes
/// nomment deux conséquences. Surtout, c'est le choix qui porte la règle du
/// prix obligatoire, au lieu de la laisser surgir à la publication.
class _PriceModeChoice extends StatelessWidget {
  const _PriceModeChoice({required this.negotiable, required this.onChanged});

  final bool negotiable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PriceModeCard(
              key: const Key('price-mode-open'),
              title: l10n.requestCreatePriceModeOpenTitle,
              subtitle: l10n.requestCreatePriceModeOpenSubtitle,
              selected: negotiable,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _PriceModeCard(
              key: const Key('price-mode-fixed'),
              title: l10n.requestCreatePriceModeFixedTitle,
              subtitle: l10n.requestCreatePriceModeFixedSubtitle,
              selected: !negotiable,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceModeCard extends StatelessWidget {
  const _PriceModeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? p.blue50 : p.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? p.blue : p.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: WizardPalette.text(
                  size: 12,
                  weight: FontWeight.w700,
                  color: selected ? p.blue : p.n800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: WizardPalette.text(
                  size: 10.5,
                  weight: FontWeight.w400,
                  color: p.n600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur « Prix total » / « Prix au kilo » : deux segments, le segment
/// actif en blanc sur fond gris. « Prix au kilo » est grisé sans poids connu.
class _PriceBasisSelector extends StatelessWidget {
  const _PriceBasisSelector({
    required this.perKilo,
    required this.perKiloAvailable,
    required this.onChanged,
  });

  final bool perKilo;
  final bool perKiloAvailable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.n100,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              key: const Key('price-basis-total'),
              label: l10n.requestCreatePriceBasisTotal,
              selected: !perKilo,
              enabled: true,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              key: const Key('price-basis-per-kilo'),
              label: l10n.requestCreatePriceBasisPerKilo,
              selected: perKilo,
              enabled: perKiloAvailable,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = WizardPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: WizardPalette.text(
              size: 12.5,
              weight: FontWeight.w800,
              color: !enabled
                  ? p.placeholder
                  : selected
                  ? p.blue
                  : p.n600,
            ),
          ),
        ),
      ),
    );
  }
}
