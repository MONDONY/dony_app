import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_photo_upload.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 3 / 3 — Budget & photo (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Budget & photo" · récap (beige) · photo (optionnelle) ·
/// budget total · aperçu net voyageur · toggle négociable ·
/// modes de paiement · mention CGU au-dessus du CTA.
class Step3RecapBudget extends StatefulWidget {
  const Step3RecapBudget({super.key});

  @override
  State<Step3RecapBudget> createState() => Step3RecapBudgetState();
}

class Step3RecapBudgetState extends State<Step3RecapBudget> {
  final _formKey = GlobalKey<FormState>();
  final _budgetCtrl = TextEditingController();
  File? _photo;

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<PackageRequestFormBloc>().add(
          FormStep3Submitted(photoFile: _photo),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
      builder: (context, state) {
        final bool canSubmit = state.negotiable || state.totalBudgetEur != null;

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
                  'Budget & photo',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Optionnel — accélère les offres.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.lg),

                // ── Récap (beige bg) ───────────────────────────────────────
                WizardSummaryCard(state: state),
                const SizedBox(height: DonySpacing.base),

                // ── Photo ──────────────────────────────────────────────────
                const _FieldLabel('Photo (optionnelle)'),
                const SizedBox(height: DonySpacing.xs),
                WizardPhotoUpload(
                  photoFile: _photo,
                  onPhotoPicked: (f) => setState(() => _photo = f),
                ),
                const SizedBox(height: DonySpacing.base),

                // ── Budget total ───────────────────────────────────────────
                const _FieldLabel('Budget total'),
                const SizedBox(height: DonySpacing.xs),
                _BudgetTotalInput(controller: _budgetCtrl),

                // ── Net voyageur preview ───────────────────────────────────
                if (state.totalBudgetEur != null) ...[
                  const SizedBox(height: DonySpacing.sm),
                  _NetPreview(totalBudgetEur: state.totalBudgetEur!),
                ],
                const SizedBox(height: DonySpacing.base),

                // ── Toggle négociable ──────────────────────────────────────
                _NegotiableToggle(negotiable: state.negotiable),

                // ── Validation hint when non-négociable without budget ─────
                if (!state.negotiable && state.totalBudgetEur == null) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.xs,
                    ),
                    child: Text(
                      'Indique un budget pour continuer (prix ferme requis).',
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                ],
                const SizedBox(height: DonySpacing.base),

                // ── Modes de paiement ──────────────────────────────────────
                const _FieldLabel('Modes de paiement acceptés'),
                const SizedBox(height: DonySpacing.sm),
                _PaymentMethodChips(
                  selected: state.acceptedPaymentMethods,
                ),
                const SizedBox(height: DonySpacing.xl),

                // ── Mention CGU ────────────────────────────────────────────
                Text(
                  'En publiant, tu acceptes les Conditions Générales d\'Utilisation de dony.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DonySpacing.base),

                // ── CTA Publier ────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: (canSubmit &&
                            state.submissionStatus !=
                                FormSubmissionStatus.submitting)
                        ? submit
                        : null,
                    child: state.submissionStatus ==
                            FormSubmissionStatus.submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Publier ma demande',
                            style: tt.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
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
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
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
          return null;
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
    final net = totalBudgetEur / 1.12;
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
          Icon(Icons.info_outline_rounded, size: 16, color: cs.success),
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

class _NegotiableToggle extends StatelessWidget {
  const _NegotiableToggle({required this.negotiable});
  final bool negotiable;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prix négociable',
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    negotiable
                        ? 'Les voyageurs peuvent faire des offres'
                        : 'Off = prix ferme, les voyageurs prennent ou laissent',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Switch(
              key: const Key('negotiable-toggle'),
              value: negotiable,
              onChanged: (v) {
                context.read<PackageRequestFormBloc>().add(
                      PackageRequestNegotiableToggled(v),
                    );
              },
              activeThumbColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Payment method chips ─────────────────────────────────────────────────────

/// Labels displayed to the user for each payment method.
const _kPaymentLabels = {
  PaymentMethod.stripe: 'Carte',
  PaymentMethod.cash: 'Cash',
  PaymentMethod.wave: 'Wave',
  PaymentMethod.orangeMoney: 'Orange Money',
};

class _PaymentMethodChips extends StatelessWidget {
  const _PaymentMethodChips({required this.selected});
  final Set<PaymentMethod> selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: PaymentMethod.values.map((method) {
        final isSelected = selected.contains(method);
        final label = _kPaymentLabels[method] ?? method.wireName;
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
