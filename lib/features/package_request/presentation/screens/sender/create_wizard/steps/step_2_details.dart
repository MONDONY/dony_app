import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/package_request_photo_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Étape 2 / 3 — Détails du colis.
///
/// Layout : photos (CTA proéminent) · poids (big input) · catégories
/// MULTIPLES (combobox catalogue + « Autre » avec précision libre en option)
/// · description. La taille (S/M/L) n'est plus saisie manuellement : la photo
/// suffit à la montrer, elle est dérivée du poids pour les filtres de
/// recherche existants ([ParcelSize]).
class Step2Details extends StatefulWidget {
  const Step2Details({super.key, this.canContinueNotifier});

  /// Piloté par l'étape, lu par le bouton « Continuer » de la coque.
  final ValueNotifier<bool>? canContinueNotifier;

  @override
  State<Step2Details> createState() => Step2DetailsState();
}

class Step2DetailsState extends State<Step2Details> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _customCatCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  /// Libellé catalogue de la catégorie « autre », affiché dans le combo et
  /// intercepté à la sélection pour proposer une précision libre.
  static const _kAutreLabel = 'Autre';

  /// Catégories prédéfinies cochées (libellés).
  final Set<String> _selectedCats = {};

  /// Catégories libres ajoutées par l'utilisateur (ordonnées).
  final List<String> _customCats = [];

  /// Message d'erreur si aucune catégorie n'est choisie (ou si la limite de
  /// sélection est atteinte).
  String? _catError;

  /// Les messages rouges n'apparaissent qu'après une première interaction.
  bool _touched = false;

  bool get _isWeightValid {
    final raw = _weightCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    return v != null && v > 0;
  }

  bool get _isComplete => _isWeightValid && _allCategories.isNotEmpty;

  void _sync({bool markTouched = false}) {
    if (markTouched) _touched = true;
    widget.canContinueNotifier?.value = _isComplete;
    if (mounted) setState(() {});
  }

  /// Reçoit la sélection complète du combo et la répartit entre catalogue et
  /// libellés libres, comme le fait la création de trajet.
  void _onCategoriesChanged(List<String> labels) {
    final catalogLabels = _predefined.map((c) => c.label).toSet();
    if (labels.length > _kMaxCategories) {
      setState(() => _catError = 'Maximum $_kMaxCategories catégories');
      return;
    }
    final autreJustAdded =
        labels.contains(_kAutreLabel) && !_allCategories.contains(_kAutreLabel);
    _selectedCats
      ..clear()
      ..addAll(labels.where(catalogLabels.contains));
    _customCats
      ..clear()
      ..addAll(labels.where((l) => !catalogLabels.contains(l)));
    _catError = _allCategories.isEmpty
        ? 'Choisis au moins une catégorie'
        : null;
    _sync(markTouched: true);
    // « Autre » seul ne dit rien au voyageur : on propose tout de suite une
    // précision libre, sans l'imposer (bottom sheet annulable).
    if (autreJustAdded) {
      unawaited(_promptAutreDetail());
    }
  }

  /// Ouvre une saisie libre pour préciser « Autre » juste après sa sélection.
  /// Si l'expéditeur renseigne un texte, il remplace « Autre » dans la
  /// sélection (catégorie libre) ; sinon « Autre » reste tel quel.
  Future<void> _promptAutreDetail() async {
    VoidCallback? submitFn;
    final result = await DonyBottomSheet.show<String>(
      context,
      title: 'Précise le contenu (optionnel)',
      subtitle: 'Ça aide le voyageur à savoir ce qu\'il transporte.',
      child: _AutrePrecisionField(onSubmitReady: (fn) => submitFn = fn),
      stickyBottom: DonyButton(
        label: 'Valider',
        onPressed: () => submitFn?.call(),
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _selectedCats.remove(_kAutreLabel);
      _customCats.add(result);
      _catError = null;
    });
    _sync(markTouched: true);
  }

  /// Nombre max de catégories sélectionnables. Le DTO backend
  /// (`PackageRequestCreateRequest.contentCategory`) est `@Size(max=255)` et
  /// la valeur envoyée est `categories.join(',')` : 11 libellés canoniques
  /// joints avoisinent déjà ~250 caractères, donc on plafonne côté Flutter
  /// plutôt que de risquer un 422 silencieux sur une sélection large.
  static const _kMaxCategories = 5;

  /// Catégories prédéfinies (dont « Autre ») proposées dans le combo —
  /// seedées synchrone avec le catalogue embarqué, puis remplacées par le
  /// catalogue live du repository dès qu'il répond (repli hors ligne intégré).
  List<ContentCategory> _predefined = fallbackCatalog;

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
    final predefinedLabels = _predefined.map((c) => c.label).toSet();
    for (final cat in s.categories) {
      if (predefinedLabels.contains(cat)) {
        _selectedCats.add(cat);
      } else {
        _customCats.add(cat);
      }
    }
    if (s.description != null && s.description!.isNotEmpty) {
      _descriptionCtrl.text = s.description!;
    }
    unawaited(_loadCatalog());
    _weightCtrl.addListener(_onWeightChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.canContinueNotifier?.value = _isComplete;
    });
  }

  void _onWeightChanged() => _sync();

  Future<void> _loadCatalog() async {
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (!mounted) return;
    setState(() => _predefined = categories);
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_onWeightChanged);
    _weightCtrl.dispose();
    _customCatCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  List<String> get _allCategories => [..._selectedCats, ..._customCats];

  void submit() {
    // Backstop : « Continuer » est déjà grisé tant que l'étape est incomplète.
    final formOk = _formKey.currentState!.validate();
    final cats = _allCategories;
    if (cats.isEmpty) {
      _catError = 'Choisis au moins une catégorie';
    }
    if (!formOk || cats.isEmpty) {
      _sync(markTouched: true);
      return;
    }
    final w = double.parse(_weightCtrl.text.replaceAll(',', '.'));
    final desc = _descriptionCtrl.text.trim();
    context.read<PackageRequestFormBloc>().add(
      FormStep2Submitted(
        weightKg: w,
        parcelSize: _sizeFromWeight(w),
        categories: cats,
        description: desc.isEmpty ? null : desc,
      ),
    );
  }

  /// La taille n'est plus saisie manuellement (la photo suffit à la montrer)
  /// mais reste nécessaire au filtre « Taille » de la recherche — dérivée du
  /// poids, seul signal encore disponible à cette étape.
  ParcelSize _sizeFromWeight(double weightKg) {
    if (weightKg <= 3) return ParcelSize.small;
    if (weightKg <= 10) return ParcelSize.medium;
    return ParcelSize.large;
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
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
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              "Ces infos aident les voyageurs à savoir s'ils peuvent transporter ton envoi.",
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
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

            // ── Contenu ────────────────────────────────────────────────────
            // Autocomplétion plutôt que liste dépliée : les onze catégories
            // occupaient ~900 px et repoussaient la description hors écran.
            // Même composant que la création de trajet. « Autre » fait partie
            // du catalogue : sa sélection déclenche une précision libre.
            _FieldLabel('Contenu'),
            const SizedBox(height: DonySpacing.xs),
            Text(
              'Tape pour chercher, ou écris ta propre catégorie.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.sm),
            ContentCategoryComboBox(
              keyPrefix: 'package-content',
              catalog: _predefined,
              selected: _allCategories,
              onChanged: _onCategoriesChanged,
            ),
            DonyFieldError(
              message: _touched ? _catError : null,
              textKey: const Key('categories-error'),
            ),
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

/// Champ de précision libre du bottom sheet « Autre ». Le controller est
/// possédé par ce widget (pas par l'appelant) : le dispose intervient au
/// démontage réel, après l'animation de fermeture du sheet — un dispose
/// manuel juste après le pop plante l'EditableText encore en transition.
class _AutrePrecisionField extends StatefulWidget {
  const _AutrePrecisionField({required this.onSubmitReady});
  final void Function(VoidCallback) onSubmitReady;

  @override
  State<_AutrePrecisionField> createState() => _AutrePrecisionFieldState();
}

class _AutrePrecisionFieldState extends State<_AutrePrecisionField> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady(_submit);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context, rootNavigator: true).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return DonyTextField(
      key: const Key('autre-detail-input'),
      controller: _ctrl,
      hint: 'Ex. Instruments de musique',
      autofocus: true,
    );
  }
}

class _DescriptionInput extends StatelessWidget {
  const _DescriptionInput({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
        fillColor: cs.surface,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
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
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
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
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      style: tt.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 26,
        color: cs.onSurface,
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
          color: cs.onSurfaceVariant,
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
