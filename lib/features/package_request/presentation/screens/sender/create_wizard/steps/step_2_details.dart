import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/steps/step_1_trajet_colis.dart'
    show OptionButton;
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/package_request_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 2 / 3 — Détails du colis.
///
/// Layout : poids (big input) · taille (3 cards S/M/L) · catégories MULTIPLES
/// (chips prédéfinies multi-sélection + chips libres supprimables + input
/// toujours visible pour en ajouter, comme la création d'un trajet) · description.
class Step2Details extends StatefulWidget {
  const Step2Details({super.key});

  @override
  State<Step2Details> createState() => Step2DetailsState();
}

class Step2DetailsState extends State<Step2Details> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  ParcelSize _size = ParcelSize.medium;

  /// Catégories prédéfinies cochées (libellés).
  final Set<String> _selectedCats = {};

  /// Catégories libres ajoutées par l'utilisateur (ordonnées).
  final List<String> _customCats = [];

  /// Message d'erreur si aucune catégorie n'est choisie à la soumission.
  String? _catError;

  /// Catégories prédéfinies (hors « Autre ») proposées en chips.
  static final _predefined = ContentCategory.values
      .where((c) => c != ContentCategory.autre)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    // Pré-remplissage (édition / retour à l'étape) depuis l'état du bloc.
    final s = context.read<PackageRequestFormBloc>().state;
    if (s.weightKg != null) {
      final w = s.weightKg!;
      _weightCtrl.text = w == w.roundToDouble()
          ? w.toInt().toString()
          : w.toString();
    }
    if (s.parcelSize != null) _size = s.parcelSize!;
    for (final cat in s.categories) {
      if (ContentCategory.predefinedLabels.contains(cat)) {
        _selectedCats.add(cat);
      } else {
        _customCats.add(cat);
      }
    }
    if (s.description != null && s.description!.isNotEmpty) {
      _descriptionCtrl.text = s.description!;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _customCatCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _toggleCat(String label) {
    setState(() {
      if (_selectedCats.contains(label)) {
        _selectedCats.remove(label);
      } else {
        _selectedCats.add(label);
      }
      _catError = null;
    });
  }

  void _addCustom() {
    final v = _customCatCtrl.text.trim();
    if (v.isEmpty) return;
    if (!_customCats.contains(v) && !_selectedCats.contains(v)) {
      setState(() {
        _customCats.add(v);
        _catError = null;
      });
    }
    _customCatCtrl.clear();
  }

  void _removeCustom(String label) {
    setState(() => _customCats.remove(label));
  }

  List<String> get _allCategories => [..._selectedCats, ..._customCats];

  void submit() {
    final formOk = _formKey.currentState!.validate();
    final cats = _allCategories;
    if (cats.isEmpty) {
      setState(() => _catError = 'Choisis au moins une catégorie');
    }
    if (!formOk || cats.isEmpty) return;
    final w = double.parse(_weightCtrl.text.replaceAll(',', '.'));
    final desc = _descriptionCtrl.text.trim();
    context.read<PackageRequestFormBloc>().add(
      FormStep2Submitted(
        weightKg: w,
        parcelSize: _size,
        categories: cats,
        description: desc.isEmpty ? null : desc,
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

            // ── Photos du colis (max 4) ────────────────────────────────────
            const PackageRequestPhotoSection(),
            const SizedBox(height: DonySpacing.base),

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

            // ── Catégories (multiples) ─────────────────────────────────────
            _FieldLabel('Catégories'),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Choisis une ou plusieurs catégories, ou ajoute la tienne.',
              style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
            ),
            const SizedBox(height: DonySpacing.sm),
            Wrap(
              spacing: DonySpacing.sm,
              runSpacing: DonySpacing.sm,
              children: [
                for (final c in _predefined)
                  OptionButton(
                    label: c.label,
                    emoji: c.emoji,
                    selected: _selectedCats.contains(c.label),
                    onTap: () => _toggleCat(c.label),
                  ),
              ],
            ),
            if (_customCats.isNotEmpty) ...[
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.sm,
                runSpacing: DonySpacing.sm,
                children: [
                  for (final c in _customCats)
                    _RemovableChip(label: c, onRemove: () => _removeCustom(c)),
                ],
              ),
            ],
            const SizedBox(height: DonySpacing.sm),
            _InlineAddRow(
              controller: _customCatCtrl,
              hint: 'Autre catégorie…',
              onAdd: _addCustom,
            ),
            if (_catError != null) ...[
              const SizedBox(height: DonySpacing.xs),
              Text(
                _catError!,
                style: tt.bodySmall?.copyWith(color: DonyColors.error),
              ),
            ],
            const SizedBox(height: DonySpacing.base),

            // ── Description (optionnel) ────────────────────────────────────
            _FieldLabel('Description (optionnel)'),
            const SizedBox(height: DonySpacing.xs),
            _DescriptionInput(controller: _descriptionCtrl),
          ],
        ),
      ),
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────────────────

/// Input + bouton « + » toujours visible pour ajouter une catégorie libre.
class _InlineAddRow extends StatelessWidget {
  const _InlineAddRow({
    required this.controller,
    required this.hint,
    required this.onAdd,
  });
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('custom-category-input'),
            controller: controller,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: const BorderSide(color: DonyColors.neutral200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                borderSide: const BorderSide(
                  color: DonyColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: DonySpacing.sm),
        Material(
          color: DonyColors.primary,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: InkWell(
            key: const Key('add-category-btn'),
            borderRadius: BorderRadius.circular(DonyRadius.md),
            onTap: onAdd,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip catégorie libre, supprimable via la croix.
class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(
        left: DonySpacing.md,
        right: DonySpacing.sm,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            key: Key('remove-cat-$label'),
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 16, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

class _DescriptionInput extends StatelessWidget {
  const _DescriptionInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('description-input'),
      controller: controller,
      maxLines: 4,
      maxLength: 500,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText:
            'Précisions utiles : fragile, contenu exact, instructions de remise…',
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.primary, width: 2),
        ),
      ),
    );
  }
}

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
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        color: DonyColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
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
    final cs = Theme.of(context).colorScheme;
    final m = _meta;
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
          color: selected ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
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
                color: selected ? cs.primary : DonyColors.textPrimary,
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
