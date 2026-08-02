import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_photos_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 3 / 3 — Budget & photo (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Budget" · récap · choix du mode de prix · budget requis ·
/// aperçu net voyageur · modes de paiement · mention CGU au-dessus du CTA.
class Step3RecapBudget extends StatefulWidget {
  const Step3RecapBudget({super.key, this.canContinueNotifier});

  /// Piloté par l'étape, lu par le bouton « Publier » de la coque.
  final ValueNotifier<bool>? canContinueNotifier;

  @override
  State<Step3RecapBudget> createState() => Step3RecapBudgetState();
}

class Step3RecapBudgetState extends State<Step3RecapBudget> {
  final _formKey = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (édition / retour à l'étape) du budget brut depuis l'état.
    final b = context.read<PackageRequestFormBloc>().state.totalBudgetEur;
    if (b != null) {
      _budgetCtrl.text = b == b.roundToDouble()
          ? b.toInt().toString()
          : b.toStringAsFixed(2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() {
    if (!mounted) return;
    final s = context.read<PackageRequestFormBloc>().state;
    widget.canContinueNotifier?.value = s.totalBudgetEur != null;
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void submit({bool saveAsDraft = false}) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final state = context.read<PackageRequestFormBloc>().state;
    if (state.totalBudgetEur == null) {
      // Backstop : le bouton « Aperçu » est déjà grisé dans ce cas.
      _sync();
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
                  'Vérifie ta demande, puis indique le budget à montrer aux voyageurs.',
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
                _FieldLabel(state.negotiable ? 'Budget indicatif' : 'Ton prix'),
                const SizedBox(height: DonySpacing.xs),
                _BudgetTotalInput(controller: _budgetCtrl),
                Padding(
                  padding: const EdgeInsets.only(top: DonySpacing.xs),
                  child: Text(
                    state.negotiable
                        ? 'Donne un ordre d\'idée pour attirer plus d\'offres, sans t\'engager.'
                        : 'Les voyageurs verront ce montant et pourront l\'accepter tel quel.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                DonyFieldError(
                  message: state.totalBudgetEur == null
                      ? 'Indique un budget pour continuer'
                      : null,
                  textKey: const Key('budget-error'),
                ),

                // ── Net voyageur preview ───────────────────────────────────
                if (state.totalBudgetEur != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  _NetPreview(totalBudgetEur: state.totalBudgetEur!),
                ],
                const SizedBox(height: DonySpacing.base),

                // ── Modes de paiement ──────────────────────────────────────
                const _FieldLabel('Paiement accepté'),
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
                          'prévenus. Tu recevras une notification à la première '
                          'offre.',
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
  const _BudgetTotalInput({required this.controller});
  final TextEditingController controller;

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
        suffixText: '€',
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
      },
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Indique un budget';
        }
        final d = double.tryParse(v.replaceAll(',', '.'));
        if (d == null || d < 0 || d > 500) {
          return 'Entre 0 et 500€';
        }
        return null;
      },
    );
  }
}

// ─── Net preview ─────────────────────────────────────────────────────────────

class _NetPreview extends StatelessWidget {
  const _NetPreview({required this.totalBudgetEur});
  final double totalBudgetEur;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final net = PriceDisplay.netFromGross(totalBudgetEur);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.successLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        children: [
          DonyIcon('info', size: 16, color: cs.success),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Text(
              'Le voyageur touchera ${PriceDisplay.eur(net)}',
              style: tt.bodySmall?.copyWith(
                color: cs.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: methods.map((method) {
        final isSelected = selected.contains(method);
        final label = method.displayLabel;
        return GestureDetector(
          onTap: () {
            context.read<PackageRequestFormBloc>().add(
              PackageRequestPaymentMethodToggled(method),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected ? cs.primaryContainer : cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.xl),
              border: Border.all(
                color: isSelected ? cs.primary : cs.outline,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              label,
              style: tt.labelMedium?.copyWith(
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
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
          subtitle: 'Les voyageurs proposent leur prix, tu choisis.',
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
