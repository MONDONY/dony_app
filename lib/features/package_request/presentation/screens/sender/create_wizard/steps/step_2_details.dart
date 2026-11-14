import 'dart:async';

import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/core/utils/weight_input_format.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/core/widgets/money_keyword_warning.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_field_mark.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/matching/data/models/item_size.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/item_size_selector.dart';
import 'package:dony/features/package_request/bloc/package_request_form_bloc.dart';
import 'package:dony/features/package_request/bloc/package_request_form_event.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:dony/features/package_request/data/parcel_dimensions.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/package_request_photo_section.dart';
import 'package:dony/features/package_request/presentation/widgets/parcel_dimension_field.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  final _descriptionCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  /// Bloc des dimensions facultatives (« peu importe ») déplié : un seul sens,
  /// une fois ouvert il reste visible avec ce qui y est saisi.
  final _dimensionsExpanded = ValueNotifier<bool>(false);

  /// Libellé catalogue de la catégorie « autre », affiché dans le combo et
  /// intercepté à la sélection pour proposer une précision libre.
  static const _kAutreLabel = 'Autre';

  /// Catégories prédéfinies cochées (libellés).
  final Set<String> _selectedCats = {};

  /// Catégories libres ajoutées par l'utilisateur (ordonnées).
  final List<String> _customCats = [];

  /// Motif d'erreur si aucune catégorie n'est choisie (ou si la limite de
  /// sélection est atteinte). Un indicateur, pas un texte déjà traduit : le
  /// message ne serait plus à jour si la langue change pendant que l'état
  /// reste affiché.
  _CategoryError? _catError;

  /// Les messages rouges n'apparaissent qu'après une première interaction.
  bool _touched = false;

  /// Mode de la demande (`null` : « peu importe »), choisi à l'étape
  /// précédente. Un mode jamais choisi part en avion, comme à l'envoi.
  TransportMode? get _mode =>
      context.read<PackageRequestFormBloc>().state.requestTransportMode;

  /// Route ou bateau : un `,` ou `.` ambigu du poids (« 1,200 ») y est un
  /// séparateur de milliers.
  bool get _heavy => _mode?.isHeavy ?? false;

  /// Mêmes bornes que le validateur du champ, pour le mode de la demande. Le
  /// gate se contentait de `v > 0` : « Continuer » s'activait sur 0,2 kg puis
  /// refusait la saisie.
  bool get _isWeightValid => PackageRequestLimits.isWeightValidFor(
    parseWeightInput(_weightCtrl.text, heavy: _heavy),
    _mode,
  );

  /// Poids saisi au-dessus du plafond du mode (par exemple 1 200 kg repris
  /// d'une demande en route, puis mode passé en avion) : l'erreur se voit
  /// tout de suite, sans attendre « Continuer ».
  bool get _isWeightAboveMode {
    final w = parseWeightInput(_weightCtrl.text, heavy: _heavy);
    return w != null && w > PackageRequestLimits.maxWeightFor(_mode);
  }

  /// Dimensions obligatoires : bateau (le back refuse sinon).
  bool get _dimensionsRequired => ParcelDimensions.isRequiredFor(_mode);

  /// Dimensions portées par le mode : bateau (obligatoires) et « peu importe »
  /// (facultatives, tout ou rien). Jamais en avion ni en route.
  bool get _dimensionsKept => ParcelDimensions.isKeptFor(_mode);

  int? _cm(TextEditingController c) => int.tryParse(c.text.trim());

  bool get _anyDimensionTyped =>
      _lengthCtrl.text.trim().isNotEmpty ||
      _widthCtrl.text.trim().isNotEmpty ||
      _heightCtrl.text.trim().isNotEmpty;

  bool get _dimensionsValid => ParcelDimensions.areValid(
    _cm(_lengthCtrl),
    _cm(_widthCtrl),
    _cm(_heightCtrl),
  );

  /// Bateau : les trois dimensions valides. « Peu importe » : aucune, ou les
  /// trois valides (tout ou rien). Autres modes : sans objet.
  bool get _dimensionsOk {
    if (!_dimensionsKept) return true;
    if (_dimensionsRequired) return _dimensionsValid;
    return !_anyDimensionTyped || _dimensionsValid;
  }

  bool get _isComplete =>
      _isWeightValid && _allCategories.isNotEmpty && _dimensionsOk;

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
      setState(() => _catError = _CategoryError.maxExceeded);
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
    _catError = _allCategories.isEmpty ? _CategoryError.required : null;
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
    final l10n = context.l10n;
    VoidCallback? submitFn;
    final result = await DonyBottomSheet.show<String>(
      context,
      title: l10n.requestCreateAutrePrecisionTitle,
      subtitle: l10n.requestCreateAutrePrecisionSubtitle,
      child: _AutrePrecisionField(onSubmitReady: (fn) => submitFn = fn),
      stickyBottom: DonyButton(
        label: l10n.requestCreateAutrePrecisionValidate,
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

  /// Nombre max de catégories sélectionnables. Plafond de lisibilité, pas
  /// de capacité : le DTO backend (`PackageRequestCreateRequest.contentCategory`)
  /// accepte `@Size(max=500)`, largement de quoi tenir tout le catalogue joint
  /// par `categories.join(',')`.
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
      _weightCtrl.text = formatWeightInput(w);
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
    if (s.hasDimensions) {
      _lengthCtrl.text = '${s.lengthCm}';
      _widthCtrl.text = '${s.widthCm}';
      _heightCtrl.text = '${s.heightCm}';
      _dimensionsExpanded.value = true;
    }
    unawaited(_loadCatalog());
    _weightCtrl.addListener(_onFieldChanged);
    for (final c in [_lengthCtrl, _widthCtrl, _heightCtrl]) {
      c.addListener(_onFieldChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.canContinueNotifier?.value = _isComplete;
    });
  }

  void _onFieldChanged() => _sync();

  Future<void> _loadCatalog() async {
    final categories = await getIt<IContentCategoryRepository>()
        .getCategories();
    if (!mounted) return;
    setState(() => _predefined = categories);
  }

  @override
  void dispose() {
    _weightCtrl.removeListener(_onFieldChanged);
    _weightCtrl.dispose();
    for (final c in [_lengthCtrl, _widthCtrl, _heightCtrl]) {
      c
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    _dimensionsExpanded.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  List<String> get _allCategories => [..._selectedCats, ..._customCats];

  /// Message du champ poids hors des bornes du mode : au-delà de 32 kg en
  /// avion ou « peu importe », il invite à choisir Route (Q5), seulement si la
  /// route est proposée (interrupteur allumé) ; sinon la fourchette seule.
  String _weightErrorText(AppLocalizations l10n) =>
      _isWeightAboveMode && !(_mode?.isHeavy ?? false) && transportModes.road
      ? l10n.requestCreateWeightTooHeavyForMode
      : weightRangeLabel(l10n, mode: _mode);

  /// Aide sous le champ poids : la fourchette du mode, avec son point final.
  String _weightHelpText(AppLocalizations l10n) {
    final range = weightRangeLabel(l10n, mode: _mode);
    return range.endsWith('.') ? range : '$range.';
  }

  /// Traduit [_catError] au moment de l'affichage (jamais mis en cache dans
  /// l'état) : le message reste correct si la langue change pendant que
  /// l'erreur est visible.
  String? _catErrorText(AppLocalizations l10n) => switch (_catError) {
    null => null,
    _CategoryError.required => l10n.requestCreateCategoryRequired,
    _CategoryError.maxExceeded => l10n.requestCreateMaxCategories(
      _kMaxCategories,
    ),
  };

  /// Saisie de l'étape au format du brouillon local
  /// (`PackageRequestFormDraft`), validée ou non. Un poids illisible est
  /// laissé vide plutôt que gardé faux.
  Map<String, dynamic> get draftInput {
    final w = parseWeightInput(_weightCtrl.text, heavy: _heavy);
    final desc = _descriptionCtrl.text.trim();
    return {
      'weightKg': w,
      'parcelSize': w == null ? null : _sizeFromWeight(w).wireName,
      'categories': _allCategories,
      'description': desc.isEmpty ? null : desc,
      // Un jeu incomplet n'a pas de sens : tout ou rien, et seulement pour un
      // mode qui les porte.
      'lengthCm': _dimensionsKept && _dimensionsValid ? _cm(_lengthCtrl) : null,
      'widthCm': _dimensionsKept && _dimensionsValid ? _cm(_widthCtrl) : null,
      'heightCm': _dimensionsKept && _dimensionsValid ? _cm(_heightCtrl) : null,
    };
  }

  /// Vrai si l'étape porte une saisie que le bloc n'a pas encore reçue.
  bool get hasUnsubmittedInput {
    final s = context.read<PackageRequestFormBloc>().state;
    final w = parseWeightInput(_weightCtrl.text, heavy: _heavy);
    final desc = _descriptionCtrl.text.trim();
    final dimensionsChanged =
        _dimensionsKept &&
        (_cm(_lengthCtrl) != s.lengthCm ||
            _cm(_widthCtrl) != s.widthCm ||
            _cm(_heightCtrl) != s.heightCm);
    return w != s.weightKg ||
        !listEquals(_allCategories, s.categories) ||
        (desc.isEmpty ? null : desc) != s.description ||
        dimensionsChanged;
  }

  void submit() {
    // Backstop : « Continuer » est déjà grisé tant que l'étape est incomplète.
    final formOk = _formKey.currentState!.validate();
    final cats = _allCategories;
    if (cats.isEmpty) {
      _catError = _CategoryError.required;
    }
    if (!formOk || cats.isEmpty) {
      _sync(markTouched: true);
      return;
    }
    final w = parseWeightInput(_weightCtrl.text, heavy: _heavy)!;
    final desc = _descriptionCtrl.text.trim();
    context.read<PackageRequestFormBloc>().add(
      FormStep2Submitted(
        weightKg: w,
        parcelSize: _sizeFromWeight(w),
        categories: cats,
        description: desc.isEmpty ? null : desc,
        lengthCm: _dimensionsKept ? _cm(_lengthCtrl) : null,
        widthCm: _dimensionsKept ? _cm(_widthCtrl) : null,
        heightCm: _dimensionsKept ? _cm(_heightCtrl) : null,
      ),
    );
  }

  /// Erreur d'une dimension, traduite à l'affichage. Une case vide n'est une
  /// erreur qu'en bateau, ou en « peu importe » quand une autre est remplie
  /// (tout ou rien).
  String? _dimensionError(AppLocalizations l10n, String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return _dimensionsRequired || _anyDimensionTyped
          ? l10n.requestCreateDimensionRequired
          : null;
    }
    return ParcelDimensions.isValidCm(int.tryParse(text))
        ? null
        : l10n.requestCreateDimensionInvalid;
  }

  /// Le bloc des dimensions est-il montré ? Toujours en bateau ; en « peu
  /// importe » quand le bateau est proposé ou que des dimensions existent déjà
  /// (demande reprise) ; jamais en avion ni en route.
  bool get _showDimensions =>
      _dimensionsRequired ||
      (_mode == null && (transportModes.boat || _anyDimensionTyped));

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
              l10n.requestCreateStep2Title,
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l10n.requestCreateStep2Subtitle,
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
            AiFieldMark(
              fields: const ['weightKg'],
              child: _FieldLabel(l10n.requestCreateWeightLabel),
            ),
            const SizedBox(height: DonySpacing.xs),
            _WeightInput(
              controller: _weightCtrl,
              mode: _mode,
              forcedError: _isWeightAboveMode ? _weightErrorText(l10n) : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: DonySpacing.xs),
              child: Text(
                _weightHelpText(l10n),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Dimensions du colis ────────────────────────────────────────
            // Bateau : obligatoires, le transporteur facture au volume. « Peu
            // importe » : facultatives, bloc replié. Masqué en avion et en
            // route.
            if (_showDimensions) ...[
              _DimensionsSection(
                key: const Key('request-dimensions-section'),
                isRequired: _dimensionsRequired,
                expanded: _dimensionsExpanded,
                lengthCtrl: _lengthCtrl,
                widthCtrl: _widthCtrl,
                heightCtrl: _heightCtrl,
                validator: (v) => _dimensionError(l10n, v),
                volumeM3: ParcelDimensions.volumeM3(
                  _cm(_lengthCtrl),
                  _cm(_widthCtrl),
                  _cm(_heightCtrl),
                ),
              ),
              const SizedBox(height: DonySpacing.base),
            ],

            // ── Taille du colis (facultative) ──────────────────────────────
            // Route et « peu importe » seulement : en avion et en bateau elle
            // est masquée (et effacée par le bloc). « Peu importe » ne la
            // montre que si la route est proposée : avion seul, l'écran reste
            // celui d'avant.
            BlocBuilder<PackageRequestFormBloc, PackageRequestFormState>(
              buildWhen: (a, b) =>
                  a.itemSize != b.itemSize ||
                  a.modeHasItemSize != b.modeHasItemSize,
              builder: (context, s) =>
                  s.modeHasItemSize &&
                      (s.requestTransportMode != null || transportModes.road)
                  ? _ItemSizeSection(
                      selected: s.itemSize,
                      onChanged: (size) => context
                          .read<PackageRequestFormBloc>()
                          .add(FormItemSizeChanged(size)),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Contenu ────────────────────────────────────────────────────
            // Autocomplétion plutôt que liste dépliée : les onze catégories
            // occupaient ~900 px et repoussaient la description hors écran.
            // Même composant que la création de trajet. « Autre » fait partie
            // du catalogue : sa sélection déclenche une précision libre.
            AiFieldMark(
              fields: const ['categories'],
              child: _FieldLabel(l10n.requestCreateContentLabel),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              l10n.requestCreateContentHint,
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
              message: _touched ? _catErrorText(l10n) : null,
              textKey: const Key('categories-error'),
            ),
            const SizedBox(height: DonySpacing.base),

            // ── Description (optionnel) ────────────────────────────────────
            _FieldLabel(l10n.requestCreateDescriptionLabel),
            const SizedBox(height: DonySpacing.xs),
            _DescriptionInput(controller: _descriptionCtrl),
            // Non bloquant : rappel des CGU si la description évoque de
            // l'argent (le back signale la demande à la modération).
            MoneyKeywordWarning(controller: _descriptionCtrl),
          ],
        ),
      ),
    );
  }
}

// ─── Atoms ──────────────────────────────────────────────────────────────────

/// Dimensions du colis : longueur, largeur, hauteur en centimètres, et le
/// volume qui en découle. Facultatives et repliées tant que [isRequired] est
/// faux ; une fois dépliées, elles le restent.
class _DimensionsSection extends StatelessWidget {
  const _DimensionsSection({
    super.key,
    required this.isRequired,
    required this.expanded,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.heightCtrl,
    required this.validator,
    required this.volumeM3,
  });

  final bool isRequired;
  final ValueNotifier<bool> expanded;
  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final TextEditingController heightCtrl;
  final String? Function(String?) validator;

  /// Aperçu du volume, `null` sans trois dimensions valides.
  final double? volumeM3;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isOpen, _) {
        if (!isRequired && !isOpen) {
          return _DimensionsExpander(
            onTap: () => expanded.value = true,
            label: l10n.requestCreateDimensionsAdd,
            help: l10n.requestCreateDimensionsHelpAny,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FieldLabel(
              isRequired
                  ? l10n.requestCreateDimensionsLabel
                  : l10n.requestCreateDimensionsOptionalLabel,
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              isRequired
                  ? l10n.requestCreateDimensionsHelpBoat
                  : l10n.requestCreateDimensionsHelpAny,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ParcelDimensionField(
                    fieldKey: const Key('request-dimension-length'),
                    label: l10n.requestCreateDimensionLength,
                    controller: lengthCtrl,
                    validator: validator,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: ParcelDimensionField(
                    fieldKey: const Key('request-dimension-width'),
                    label: l10n.requestCreateDimensionWidth,
                    controller: widthCtrl,
                    validator: validator,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Expanded(
                  child: ParcelDimensionField(
                    fieldKey: const Key('request-dimension-height'),
                    label: l10n.requestCreateDimensionHeight,
                    controller: heightCtrl,
                    validator: validator,
                  ),
                ),
              ],
            ),
            if (volumeM3 != null)
              Padding(
                padding: const EdgeInsets.only(top: DonySpacing.sm),
                child: Text(
                  l10n.requestCreateVolumeLine(
                    formatParcelVolumeM3(l10n, volumeM3!),
                  ),
                  key: const Key('request-volume-preview'),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Entrée repliée des dimensions facultatives : une ligne qui déplie le bloc.
class _DimensionsExpander extends StatelessWidget {
  const _DimensionsExpander({
    required this.onTap,
    required this.label,
    required this.help,
  });

  final VoidCallback onTap;
  final String label;
  final String help;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: const Key('request-dimensions-add'),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              DonyIcon('plus', size: 18, color: cs.primary),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      help,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

/// Taille du colis, facultative : quatre tuiles, un second tap sur la tuile
/// choisie la retire. Ne bloque jamais « Continuer ».
class _ItemSizeSection extends StatelessWidget {
  const _ItemSizeSection({required this.selected, required this.onChanged});

  final ItemSize? selected;
  final ValueChanged<ItemSize?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Column(
      key: const Key('request-item-size-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(l10n.requestCreateItemSizeOptionalLabel),
        const SizedBox(height: DonySpacing.sm),
        ItemSizeSelector(
          sizes: ItemSize.values,
          selected: selected,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(top: DonySpacing.xs),
          child: Text(
            l10n.requestCreateItemSizeHelp,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: DonySpacing.base),
      ],
    );
  }
}

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
      hint: context.l10n.requestCreateAutrePrecisionHint,
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
    return DonyReplayMask(
      child: TextFormField(
        key: const Key('description-input'),
        controller: controller,
        scrollPadding: kDonyKeyboardScrollPadding,
        maxLines: 4,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: context.l10n.requestCreateDescriptionHint,
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
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
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
  const _WeightInput({
    required this.controller,
    required this.mode,
    this.forcedError,
  });
  final TextEditingController controller;

  /// Mode de la demande : il fixe le plafond du poids.
  final TransportMode? mode;

  /// Erreur à montrer tout de suite (poids repris d'un autre mode), sinon le
  /// message n'apparaît qu'à la validation.
  final String? forcedError;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DonyReplayMask(
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // Milliers groupés pendant la frappe (« 1 200 »), chiffres et une
        // seule marque décimale.
        inputFormatters: [
          GroupedWeightInputFormatter(heavy: mode?.isHeavy ?? false),
        ],
        forceErrorText: forcedError,
        scrollPadding: kDonyKeyboardScrollPadding,
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
          // « Au-delà de 32 kg, choisissez Route à l'étape précédente. » :
          // une ligne ne suffit pas à 360 dp, le message passe à la ligne au
          // lieu de finir en « … ».
          errorMaxLines: 3,
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
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
            borderSide: const BorderSide(color: DonyColors.error, width: 1.5),
          ),
        ),
        validator: (v) {
          final d = parseWeightInput(v ?? '', heavy: mode?.isHeavy ?? false);
          if (d == null) return context.l10n.requestCreateWeightInvalid;
          if (!PackageRequestLimits.isWeightValidFor(d, mode)) {
            return d > PackageRequestLimits.maxWeightFor(mode) &&
                    !(mode?.isHeavy ?? false) &&
                    transportModes.road
                ? context.l10n.requestCreateWeightTooHeavyForMode
                : weightRangeLabel(context.l10n, mode: mode);
          }
          return null;
        },
      ),
    );
  }
}

/// Motif de l'erreur de sélection des catégories — traduit uniquement dans
/// `build()`, jamais stocké déjà traduit dans l'état.
enum _CategoryError {
  /// Aucune catégorie sélectionnée.
  required,

  /// Plus de [Step2DetailsState._kMaxCategories] catégories sélectionnées.
  maxExceeded,
}
