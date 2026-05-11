import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart'
    show OptionButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 2 / 3 — Détails du colis (match maquette `v3/expéditeur_publie`).
///
/// Layout : titre "Décris ton colis" · poids (big input) · taille (3 cards
/// S/M/L) · catégorie principale (boutons option).
class Step2Details extends StatefulWidget {
  const Step2Details({super.key});

  @override
  State<Step2Details> createState() => Step2DetailsState();
}

class Step2DetailsState extends State<Step2Details> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  ParcelSize _size = ParcelSize.medium;
  ContentCategory _category = ContentCategory.vetements;

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void submit() {
    if (!_formKey.currentState!.validate()) return;
    final w = double.parse(_weightCtrl.text.replaceAll(',', '.'));
    context.read<PackageRequestFormBloc>().add(
          FormStep2Submitted(
            weightKg: w,
            parcelSize: _size,
            contentCategory: _category,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
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
              'Décris ton colis',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: DonyColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              "Ces infos aident les voyageurs à savoir s'ils peuvent transporter ton envoi.",
              style: tt.bodyMedium?.copyWith(
                color: DonyColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: DonySpacing.lg),

            // ── Poids ──────────────────────────────────────────────────────
            _FieldLabel('Poids approximatif'),
            const SizedBox(height: DonySpacing.xs),
            _WeightInput(controller: _weightCtrl),
            const SizedBox(height: DonySpacing.base),

            // ── Taille ─────────────────────────────────────────────────────
            _FieldLabel('Taille'),
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: ParcelSize.values
                  .map(
                    (s) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.xs / 2,
                        ),
                        child: _SizeCard(
                          size: s,
                          selected: s == _size,
                          onTap: () => setState(() => _size = s),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Catégorie ──────────────────────────────────────────────────
            _FieldLabel('Catégorie principale'),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: ContentCategory.values.map((c) {
                return OptionButton(
                  label: c.label,
                  emoji: c.emoji,
                  selected: c == _category,
                  onTap: () => setState(() => _category = c),
                );
              }).toList(),
            ),
          ],
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
            color: DonyColors.textPrimary,
            fontSize: 14,
          ),
    );
  }
}

class _WeightInput extends StatelessWidget {
  const _WeightInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        color: DonyColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md + 4,
        ),
        suffixText: 'kg',
        suffixStyle: tt.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: DonyColors.textMuted,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
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
        final d = double.tryParse(v?.replaceAll(',', '.') ?? '');
        if (d == null) return 'Valeur invalide';
        if (d < 0.5 || d > 30) return 'Entre 0.5 et 30 kg';
        return null;
      },
    );
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final ParcelSize size;
  final bool selected;
  final VoidCallback onTap;

  ({String emoji, String label, String hint}) get _meta => switch (size) {
        ParcelSize.small => (emoji: '📦', label: 'S', hint: 'Sac'),
        ParcelSize.medium => (emoji: '📫', label: 'M', hint: 'Carton'),
        ParcelSize.large => (emoji: '🧳', label: 'L', hint: 'Valise'),
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final m = _meta;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.md,
          horizontal: DonySpacing.xs,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: selected ? DonyColors.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(m.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              m.label,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: DonyColors.textPrimary,
              ),
            ),
            Text(
              m.hint,
              style: tt.bodySmall?.copyWith(
                fontSize: 11,
                color: DonyColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
