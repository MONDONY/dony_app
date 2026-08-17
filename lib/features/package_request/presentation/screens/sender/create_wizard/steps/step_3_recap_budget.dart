import 'dart:async';

import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/data/models/negotiation_quote.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 3 / 3 — Budget & photo (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Budget" · récap · choix du mode de prix · budget requis ·
/// aperçu net voyageur · modes de paiement · mention CGU au-dessus du CTA.
class Step3RecapBudget extends StatefulWidget {
  const Step3RecapBudget({super.key, this.canContinueNotifier, this.currency});

  /// Piloté par l'étape, lu par le bouton « Publier » de la coque.
  final ValueNotifier<bool>? canContinueNotifier;
  final SupportedCurrency? currency;

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

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (édition / retour à l'étape) du budget brut depuis l'état.
    final s = context.read<PackageRequestFormBloc>().state;
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
      if (mounted) _sync();
    });
  }

  /// Les messages rouges n'apparaissent qu'après une première saisie, comme
  /// aux étapes 1 et 2 : l'étape s'ouvrait sinon sur « Indique un budget »
  /// avant même que le champ ait été touché.
  bool _touched = false;

  /// Budget accepté par le backend (`@DecimalMin("0.0") @DecimalMax("560.0")`),
  /// borne basse relevée : un budget nul ne rémunère personne.
  static const _kMinBudget = 1.0;
  static const _kMaxBudget = 560.0;

  static bool _isBudgetValid(double? v) =>
      v != null && v >= _kMinBudget && v <= _kMaxBudget;

  /// Dit ce qui manque, pas seulement qu'il manque quelque chose : un budget
  /// hors bornes recevait le même « Indique un budget » qu'un champ vide.
  String _budgetErrorText(double? v) {
    if (v == null) return 'Indiquez un budget pour continuer';
    final min = CurrencyFormatter.formatOrPlain(_kMinBudget, widget.currency);
    final max = CurrencyFormatter.formatOrPlain(_kMaxBudget, widget.currency);
    return 'Le budget doit être compris entre $min et $max';
  }

  /// Le bouton ne doit être actif que si la publication peut réellement
  /// aboutir : il l'était dès qu'un montant était saisi, y compris hors
  /// bornes, et la publication échouait ensuite sans un mot.
  void _sync() {
    if (!mounted) return;
    final s = context.read<PackageRequestFormBloc>().state;
    widget.canContinueNotifier?.value = _isBudgetValid(s.totalBudgetEur);
  }

  Future<void> _applyPromoCode() async {
    final budget = context.read<PackageRequestFormBloc>().state.totalBudgetEur;
    if (budget == null) return;
    final code = _promoCtrl.text.trim();
    _quoteLoadingNotifier.value = true;
    try {
      final quote = await getIt<PackageRequestRepository>().quote(
        budget,
        promoCode: code.isEmpty ? null : code,
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
          : ErrorPresenter.resolve(e).message;
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
    super.dispose();
  }

  void submit({bool saveAsDraft = false}) {
    final state = context.read<PackageRequestFormBloc>().state;
    if (!_formKey.currentState!.validate() ||
        !_isBudgetValid(state.totalBudgetEur)) {
      // Backstop : le bouton « Aperçu » est déjà grisé dans ce cas. On révèle
      // quand même les messages et on remonte au champ fautif — cette sortie
      // était muette, et l'aperçu venait de se refermer : côté utilisateur,
      // « Publier » ne faisait tout simplement rien.
      setState(() => _touched = true);
      _sync();
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
                  'Budget',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Vérifiez votre demande, puis indiquez le budget à montrer aux voyageurs.',
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
                const _FieldLabel('Comment fixer le prix ?'),
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

                // ── Budget ─────────────────────────────────────────────────
                _FieldLabel(
                  state.negotiable ? 'Budget indicatif' : 'Votre prix',
                ),
                const SizedBox(height: DonySpacing.xs),
                _BudgetTotalInput(
                  key: _budgetFieldKey,
                  controller: _budgetCtrl,
                  onBudgetChanged: _invalidateQuote,
                  currency: widget.currency,
                  minBudget: _kMinBudget,
                  maxBudget: _kMaxBudget,
                  onTouched: () {
                    if (!_touched) setState(() => _touched = true);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Text(
                    state.negotiable
                        ? 'Donnez un ordre d\'idée pour attirer plus d\'offres, sans vous engager.'
                        : 'Les voyageurs verront ce montant et pourront l\'accepter tel quel.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                DonyFieldError(
                  message: _touched && !_isBudgetValid(state.totalBudgetEur)
                      ? _budgetErrorText(state.totalBudgetEur)
                      : null,
                  textKey: const Key('budget-error'),
                ),

                // ── Net voyageur : décomposition transparente ───────────────
                if (state.totalBudgetEur != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  ListenableBuilder(
                    listenable: _quoteNotifier,
                    builder: (context, _) {
                      final quoteVal = _quoteNotifier.value;
                      final quote = quoteVal is NegotiationQuote
                          ? quoteVal
                          : null;
                      return _BudgetBreakdown(
                        budgetEur: state.totalBudgetEur!,
                        quote: quote,
                        currency: widget.currency,
                      );
                    },
                  ),
                  const SizedBox(height: DonySpacing.base),

                  // ── Code promo ────────────────────────────────────────────
                  const _FieldLabel('Code promo (optionnel)'),
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
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: WELCOME10',
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
                                  child: const Text('Appliquer'),
                                ),
                              ),
                            ],
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
                                    quote.promoLabel ?? 'Code appliqué',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.success,
                                      fontWeight: FontWeight.w600,
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
                const _FieldLabel('Paiement accepté'),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Choisissez comment vous paierez le voyageur.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: DonySpacing.sm),
                _PaymentMethodChips(selected: state.acceptedPaymentMethods),
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
                          'Une fois publiée, les voyageurs sur ce trajet sont '
                          'prévenus. Vous recevrez une notification à la '
                          'première offre.',
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
    required this.minBudget,
    required this.maxBudget,
    required this.onTouched,
  });
  final TextEditingController controller;
  final SupportedCurrency? currency;
  final double minBudget;
  final double maxBudget;

  /// Signale la première saisie : les messages rouges restent muets avant.
  final VoidCallback onTouched;

  /// Prévient le parent qu'un devis chargé précédemment est périmé.
  final VoidCallback? onBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      key: const Key('total-budget-input'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
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
        hintText: 'Ex. 40,00',
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
        onTouched();
        final value = double.tryParse(text.replaceAll(',', '.'));
        context.read<PackageRequestFormBloc>().add(
          PackageRequestTotalBudgetChanged(value),
        );
        onBudgetChanged?.call();
      },
      // Bornes alignées sur PackageRequestCreateRequest côté backend
      // (@DecimalMax 560.0) : le plafond était figé à 500 côté Flutter.
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Indiquez un budget';
        }
        final d = double.tryParse(v.replaceAll(',', '.'));
        if (d == null || d < minBudget || d > maxBudget) {
          return 'Entre ${CurrencyFormatter.formatOrPlain(minBudget, currency)} '
              'et ${CurrencyFormatter.formatOrPlain(maxBudget, currency)}';
        }
        return null;
      },
    );
  }
}

// ─── Net preview ─────────────────────────────────────────────────────────────

/// Décomposition transparente du budget : la commission Yadony reste
/// toujours affichée au taux de base (jamais faussée par le promo — même
/// contrat que les autres devis de l'app), et c'est le net voyageur qui
/// bouge quand un code promo est appliqué (le budget de l'expéditeur, lui,
/// ne change pas : un promo rend son offre plus attractive à dépense égale,
/// au lieu de réduire ce qu'il paie — cf. PackageRequestService.quote).
class _BudgetBreakdown extends StatelessWidget {
  const _BudgetBreakdown({
    required this.budgetEur,
    this.quote,
    required this.currency,
  });

  final double budgetEur;
  final NegotiationQuote? quote;
  final SupportedCurrency? currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final rate = quote?.rate ?? PriceDisplay.previewRate;
    final netBase = PriceDisplay.netFromGross(budgetEur);
    final commissionEur = quote?.commissionEur ?? (budgetEur - netBase);
    final net = quote?.netEur ?? netBase;
    final promoApplied = quote?.promoApplied ?? false;
    final boost = promoApplied ? net - netBase : 0.0;
    final hasRealBoost = boost > 0.005;
    final ratePct = _ratePercentLabel(rate);

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(
            tt,
            cs,
            'Budget',
            CurrencyFormatter.formatOrPlain(budgetEur, currency),
          ),
          const SizedBox(height: DonySpacing.xs),
          _line(
            tt,
            cs,
            'Commission Yadony ($ratePct %)',
            CurrencyFormatter.formatOrPlain(commissionEur, currency),
          ),
          if (hasRealBoost) ...[
            const SizedBox(height: DonySpacing.xs),
            _line(
              tt,
              cs,
              'Grâce au code promo, le voyageur touche',
              '+${CurrencyFormatter.formatOrPlain(boost, currency)}',
              valueColor: cs.success,
            ),
          ],
          const SizedBox(height: DonySpacing.xs),
          Divider(color: cs.success.withValues(alpha: 0.2)),
          const SizedBox(height: DonySpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Le voyageur touchera',
                style: tt.bodyMedium?.copyWith(fontSize: 13, color: cs.success),
              ),
              Text(
                CurrencyFormatter.formatOrPlain(net, currency),
                style: tt.bodyMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cs.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

  /// Libellé pourcentage : entier si rond, sinon 1 décimale virgule FR.
  String _ratePercentLabel(double rate) {
    final pct = rate * 100;
    return pct % 1 == 0
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1).replaceFirst('.', ',');
  }
}

// ─── Negotiable toggle ────────────────────────────────────────────────────────

// ─── Payment method chips ─────────────────────────────────────────────────────

class _PaymentMethodChips extends StatelessWidget {
  const _PaymentMethodChips({required this.selected});
  final Set<PaymentMethod> selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Mobile money retiré des nouvelles demandes ; on garde toutefois les
    // méthodes legacy déjà cochées (édition) pour pouvoir les décocher.
    final methods = [
      ...PaymentMethod.selectable,
      ...selected.where((m) => !PaymentMethod.selectable.contains(m)),
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
          final isLastSelected = isSelected && selected.length == 1;
          return GestureDetector(
            onTap: () {
              // Le bloc refuse de vider la sélection. Sans ce mot, le refus se
              // lisait comme un tap perdu.
              if (isLastSelected) {
                DonySnackbar.show(
                  context,
                  message: 'Gardez au moins un mode de paiement.',
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
                    method.displayLabel,
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
    return Column(
      children: [
        _PriceModeCard(
          key: const Key('price-mode-open'),
          emoji: '💬',
          title: "J'ouvre aux offres",
          subtitle: 'Les voyageurs proposent leur prix, vous choisissez.',
          selected: negotiable,
          onTap: () => onChanged(true),
        ),
        const SizedBox(height: DonySpacing.sm),
        _PriceModeCard(
          key: const Key('price-mode-fixed'),
          emoji: '🏷️',
          title: 'Je fixe mon prix',
          subtitle: 'Un montant ferme, sans négociation.',
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
