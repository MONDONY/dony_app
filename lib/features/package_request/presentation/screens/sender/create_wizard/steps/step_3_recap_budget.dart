import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_photo_upload.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 3 / 3 — Budget & photo (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Budget & photo" · récap (beige) · photo (optionnelle) ·
/// budget cible · mention CGU au-dessus du CTA.
class Step3RecapBudget extends StatefulWidget {
  const Step3RecapBudget({super.key});

  @override
  State<Step3RecapBudget> createState() => Step3RecapBudgetState();
}

class Step3RecapBudgetState extends State<Step3RecapBudget> {
  final _formKey = GlobalKey<FormState>();
  final _targetCtrl = TextEditingController();
  File? _photo;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  void submit() {
    if (!_formKey.currentState!.validate()) return;
    final target = _targetCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_targetCtrl.text.replaceAll(',', '.'));
    context.read<PackageRequestFormBloc>().add(
          FormStep3Submitted(targetPriceEur: target),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
      builder: (context, state) {
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
                    color: DonyColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  'Optionnel — accélère les offres.',
                  style: tt.bodyMedium?.copyWith(
                    color: DonyColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DonySpacing.lg),

                // ── Récap (beige bg) ───────────────────────────────────────
                WizardSummaryCard(state: state),
                const SizedBox(height: DonySpacing.base),

                // ── Photo ──────────────────────────────────────────────────
                _FieldLabel('Photo (optionnelle)'),
                const SizedBox(height: DonySpacing.xs),
                WizardPhotoUpload(
                  photoFile: _photo,
                  onPhotoPicked: (f) => setState(() => _photo = f),
                ),
                const SizedBox(height: DonySpacing.base),

                // ── Budget cible ───────────────────────────────────────────
                _FieldLabel('Budget cible'),
                const SizedBox(height: DonySpacing.xs),
                _BudgetInput(controller: _targetCtrl),
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
            color: DonyColors.textPrimary,
            fontSize: 14,
          ),
    );
  }
}

class _BudgetInput extends StatelessWidget {
  const _BudgetInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: DonyColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md + 2,
        ),
        hintText: 'Laisse vide pour ne pas indiquer',
        hintStyle: tt.bodyMedium?.copyWith(color: DonyColors.textSubtle),
        suffixText: '€',
        suffixStyle: tt.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: DonyColors.textMuted,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.error, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final d = double.tryParse(v.replaceAll(',', '.'));
        if (d == null || d < 0 || d > 500) return 'Entre 0 et 500€';
        return null;
      },
    );
  }
}
