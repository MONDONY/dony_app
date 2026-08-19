// Écran plein de composition de recherche — remplace la feuille de filtres
// (`SearchFilterSheet`) comme point d'entrée « Filtrer » de l'écran Rechercher.
//
// Parité stricte avec la feuille : les huit blocs de filtres (OÙ, QUAND,
// POIDS ET PRIX / POIDS MAXIMAL + TAILLE DU COLIS, MON COLIS CONTIENT,
// FILTRES RAPIDES, URGENCE DU DÉPART, AUTOUR DE MOI) sont tous présents, sans
// qu'aucun ne soit retiré. Le seul ajout est le bloc « EN UNE PHRASE » en
// tête, qui porte la MÊME étiquette de section que les autres — juste
// marquée `optional: true` — plutôt qu'un champ héros : chercher aux
// filtres seuls, sans jamais toucher la barre, doit rester un parcours
// complet et non un pis-aller.
//
// La route (Task 5) fournira le `BlocProvider<SearchComposerBloc>` ancêtre :
// cet écran ne le crée pas lui-même, il le consomme via `context.read`.

import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/parsed_recap_card.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_sheet.dart'
    show showNoActiveTripSheet;
import 'package:dony/features/home/presentation/widgets/search_phrase_field.dart';
import 'package:dony/features/home/presentation/widgets/search_section_label.dart';
import 'package:dony/features/home/presentation/widgets/unresolved_question.dart';
import 'package:dony/features/home/presentation/widgets/voice_dictation_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class SearchComposerScreen extends StatefulWidget {
  const SearchComposerScreen({
    super.key,
    required this.mode,
    required this.initialFilters,
    this.activeTrips,
    this.onPublishTrip,
    this.speechAvailable = true,
  });

  final SearchMode mode;
  final HomeSearchFilters initialFilters;

  /// Nombre de trajets actifs de l'utilisateur — voir `SearchFilterSheet.show`.
  /// `null` : nombre inconnu, la pastille « Pour mes trajets » reste
  /// utilisable, le serveur tranchera.
  final int? activeTrips;

  /// Publication d'un trajet demandée depuis le garde-fou « Pour mes trajets ».
  final VoidCallback? onPublishTrip;

  /// Disponibilité de la dictée vocale, injectée pour la rendre testable sans
  /// plateforme. `true` par défaut : l'appelant réel n'a rien à faire tant
  /// que `VoiceDictationSheet.show` gère lui-même l'indisponibilité
  /// (`initialize()` en échec ou permission refusée) en renvoyant `null`, ce
  /// qui masque déjà le micro à la prochaine ouverture. Ce paramètre sert
  /// surtout aux tests, qui n'ont pas de plateforme de reconnaissance vocale.
  final bool speechAvailable;

  @override
  State<SearchComposerScreen> createState() => _SearchComposerScreenState();
}

class _SearchComposerScreenState extends State<SearchComposerScreen> {
  final _phraseController = TextEditingController();

  static const _maxWeightPresets = <double>[5, 10, 20];

  @override
  void initState() {
    super.initState();
    // Événement de vue/intention à l'ouverture — pattern accepté par le
    // projet (voir CLAUDE.md) : mesure l'ouverture et déclenche le premier
    // comptage sur les filtres hérités de l'onglet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SearchComposerBloc>().add(const SearchComposerStarted());
      }
    });
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  void _update(HomeSearchFilters filters) {
    context.read<SearchComposerBloc>().add(
      SearchComposerFiltersChanged(filters),
    );
  }

  void _submitPhrase(String text) {
    if (text.trim().isEmpty) return;
    context.read<SearchComposerBloc>().add(SearchComposerPhraseSubmitted(text));
  }

  /// Ouvre la feuille de dictée. Au relâchement du micro, le texte reconnu
  /// remplit le champ visible puis déclenche le même parsing qu'une saisie
  /// au clavier, marqué `fromVoice: true` pour l'entonnoir analytics du BLoC.
  Future<void> _onMicPressed() async {
    final text = await VoiceDictationSheet.show(context);
    if (text == null || !mounted) return;

    _phraseController.text = text;
    context.read<SearchComposerBloc>().add(
      SearchComposerPhraseSubmitted(text, fromVoice: true),
    );
    unawaited(
      getIt<AnalyticsService>().logEvent(AnalyticsEvents.searchVoiceUsed),
    );
  }

  // Voir `CommonFilterBlock._clearDeparture`/`_clearArrival` dans
  // search_filter_fields.dart : même logique, dupliquée ici parce que l'écran
  // n'utilise pas ce widget composite (il sépare OÙ et QUAND sous deux
  // étiquettes distinctes, voir le squelette imposé de la Task 3).
  void _clearDeparture(HomeSearchFilters f) => _update(
    f.copyWith(clearCorridor: true).copyWith(arrivalCity: f.arrivalCity),
  );

  void _clearArrival(HomeSearchFilters f) => _update(
    f.copyWith(clearCorridor: true).copyWith(departureCity: f.departureCity),
  );

  bool get _canFilterOnMyTrips {
    final trips = widget.activeTrips;
    return trips == null || trips > 0;
  }

  Future<void> _showNoActiveTripSheet(BuildContext context) =>
      showNoActiveTripSheet(
        context,
        sheetsToPop: 1,
        onPublishTrip: widget.onPublishTrip,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: Text(
          widget.mode.isTrips ? 'Filtrer les trajets' : 'Filtrer les colis',
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<SearchComposerBloc>().add(
              const SearchComposerCleared(),
            ),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
      body: BlocConsumer<SearchComposerBloc, SearchComposerState>(
        // `error` persiste dans l'état tant qu'aucune nouvelle valeur ne le
        // remplace : sans ce garde, chaque changement de filtre (isCounting,
        // resultCount…) redéclencherait la même snackbar.
        listenWhen: (previous, current) => current.error != previous.error,
        listener: (context, state) {
          if (state.error != null) {
            unawaited(ErrorPresenter.show(context, state.error));
          }
        },
        builder: (context, state) {
          final f = state.filters;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              const SearchSectionLabel('EN UNE PHRASE', optional: true),
              SearchPhraseField(
                controller: _phraseController,
                onSubmitted: _submitPhrase,
                onMicPressed: widget.speechAvailable
                    ? () => unawaited(_onMicPressed())
                    : null,
                isParsing: state.isParsing,
              ).animate().fadeIn(duration: 250.ms),
              if (state.recognized.isNotEmpty)
                ParsedRecapCard(state.recognized),
              for (final item in state.unresolved) UnresolvedQuestion(item),

              const SearchSectionLabel('OÙ'),
              CityCorridorFields(
                departureValue: f.departureCity,
                arrivalValue: f.arrivalCity,
                departureFieldKey: const Key('composer-departure-city'),
                arrivalFieldKey: const Key('composer-arrival-city'),
                onDepartureSelected: (CityModel city) =>
                    _update(f.copyWith(departureCity: city.name)),
                onArrivalSelected: (CityModel city) =>
                    _update(f.copyWith(arrivalCity: city.name)),
                onDepartureCleared: () => _clearDeparture(f),
                onArrivalCleared: () => _clearArrival(f),
                onSwap: () => _update(f.swapCorridor()),
              ).animate().fadeIn(duration: 250.ms),

              const SearchSectionLabel('QUAND'),
              DatePresetsField(
                value: f,
                onChanged: _update,
              ).animate().fadeIn(delay: 20.ms),

              if (widget.mode.isTrips)
                ..._tripsBlocks(context, f)
              else
                ..._parcelsBlocks(context, f),

              const SearchSectionLabel('AUTOUR DE MOI'),
              _AroundMeBlock(filters: f).animate().fadeIn(delay: 120.ms),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: BlocBuilder<SearchComposerBloc, SearchComposerState>(
            buildWhen: (previous, current) =>
                current.resultCount != previous.resultCount,
            builder: (context, state) {
              // Le compteur remplace la liste absente de cet écran. Il ne
              // conditionne jamais l'activation du bouton : chercher sans
              // compteur (comptage en échec) reste possible.
              final label = state.resultCount == null
                  ? 'Rechercher'
                  : 'Rechercher (${state.resultCount})';
              return DonyButton(
                label: label,
                onPressed: () => context.pop(
                  context.read<SearchComposerBloc>().state.filters,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Trajets ──────────────────────────────────────────────────────────────

  List<Widget> _tripsBlocks(BuildContext context, HomeSearchFilters f) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return [
      const SearchSectionLabel('POIDS ET PRIX'),
      Row(
        children: [
          Expanded(
            child: WeightField(
              weightKg: f.weightMin ?? 6,
              onChanged: (v) => _update(
                v == 6
                    ? f.copyWith(clearWeight: true)
                    : f.copyWith(weightMin: v),
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: PriceField(
              maxPrice: f.maxPricePerKg,
              onTap: () => unawaited(
                showPricePicker(
                  context,
                  maxPrice: f.maxPricePerKg,
                  onApply: (v) => _update(
                    v == null
                        ? f.copyWith(clearMaxPricePerKg: true)
                        : f.copyWith(maxPricePerKg: v),
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 40.ms),
      const SizedBox(height: DonySpacing.base),
      Row(
        children: [
          Expanded(
            child: TransportModeField(
              mode: f.transportMode,
              onTap: () => unawaited(
                showTransportPicker(
                  context,
                  mode: f.transportMode,
                  onApply: (v) => _update(
                    v == null
                        ? f.copyWith(clearTransportMode: true)
                        : f.copyWith(transportMode: v),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ).animate().fadeIn(delay: 60.ms),

      const SearchSectionLabel('MON COLIS CONTIENT'),
      // Autocomplétion plutôt que les onze types dépliés : la liste occuperait
      // l'écran entier. `singleSelection` conserve la sémantique du filtre.
      ContentCategorySelector(
        repository: getIt<IContentCategoryRepository>(),
        keyPrefix: 'filter-content',
        singleSelection: true,
        hint: 'Rechercher un type de contenu…',
        selected: f.contentType == null ? const [] : [f.contentType!],
        onChanged: (sel) => _update(
          sel.isEmpty
              ? f.copyWith(clearContentType: true)
              : f.copyWith(contentType: sel.last),
        ),
      ).animate().fadeIn(delay: 80.ms),

      const SearchSectionLabel('FILTRES RAPIDES'),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          QuickChip(
            label: 'Kilo Pro',
            iconAsset: 'award',
            active: f.kiloProOnly,
            onChanged: (v) => _update(f.copyWith(kiloProOnly: v)),
          ),
          QuickChip(
            label: 'Note ≥ 4.5',
            iconAsset: 'star',
            active: f.minRating != null,
            onChanged: (v) => _update(
              v ? f.copyWith(minRating: 4.5) : f.copyWith(clearMinRating: true),
            ),
          ),
          QuickChip(
            label: 'Week-end',
            iconAsset: 'sofa',
            active: f.weekendOnly,
            onChanged: (v) => _update(f.copyWith(weekendOnly: v)),
          ),
          QuickChip(
            label: 'Identité vérifiée',
            iconAsset: 'shield-check',
            active: f.kycVerifiedOnly,
            onChanged: (v) => _update(f.copyWith(kycVerifiedOnly: v)),
          ),
        ],
      ).animate().fadeIn(delay: 100.ms),

      const SearchSectionLabel('URGENCE DU DÉPART'),
      Text(
        'Filtrer les trajets selon leur proximité de départ',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: DonySpacing.md),
      UrgencyFilterChips(
        selected: f.urgencyFilter,
        onChanged: (v) => _update(
          v == null
              ? f.copyWith(clearUrgencyFilter: true)
              : f.copyWith(urgencyFilter: v),
        ),
      ).animate().fadeIn(delay: 120.ms),
    ];
  }

  // ── Colis ────────────────────────────────────────────────────────────────

  List<Widget> _parcelsBlocks(BuildContext context, HomeSearchFilters f) {
    return [
      const SearchSectionLabel('POIDS MAXIMAL'),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          for (final kg in _maxWeightPresets)
            QuickChip(
              label: '≤ ${kg.toInt()} kg',
              iconAsset: 'scale',
              active: f.maxWeight == kg,
              onChanged: (v) => _update(
                v
                    ? f.copyWith(maxWeight: kg)
                    : f.copyWith(clearMaxWeight: true),
              ),
            ),
        ],
      ).animate().fadeIn(delay: 40.ms),

      const SearchSectionLabel('TAILLE DU COLIS'),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          for (final size in ParcelSize.values)
            ContentTypeChip(
              label: _parcelSizeLabel(size),
              emoji: _parcelSizeEmoji(size),
              selected: f.parcelSize == size,
              onTap: () => _update(
                f.parcelSize == size
                    ? f.copyWith(clearParcelSize: true)
                    : f.copyWith(parcelSize: size),
              ),
            ),
        ],
      ).animate().fadeIn(delay: 60.ms),

      const SearchSectionLabel('FILTRES RAPIDES'),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          Opacity(
            opacity: _canFilterOnMyTrips ? 1 : 0.4,
            child: QuickChip(
              key: const Key('chip-matching-my-trips'),
              label: 'Pour mes trajets',
              iconAsset: 'plane',
              active: f.matchingMyTrips,
              onChanged: _canFilterOnMyTrips
                  ? (v) => _update(f.copyWith(matchingMyTrips: v))
                  : (_) => unawaited(_showNoActiveTripSheet(context)),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 80.ms),
      const SizedBox(height: DonySpacing.md),
      Text(
        'Astuce, tu peux être prévenu des nouveaux colis compatibles depuis '
        'Réglages, Notifications.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ).animate().fadeIn(delay: 100.ms),
    ];
  }

  static String _parcelSizeLabel(ParcelSize s) => switch (s) {
    ParcelSize.small => 'Petit',
    ParcelSize.medium => 'Moyen',
    ParcelSize.large => 'Grand',
  };

  static String _parcelSizeEmoji(ParcelSize s) => switch (s) {
    ParcelSize.small => '📦',
    ParcelSize.medium => '📫',
    ParcelSize.large => '🧳',
  };
}

// ── AUTOUR DE MOI ────────────────────────────────────────────────────────────

/// Interrupteur de proximité + rayon.
///
/// Contrepartie, pour l'écran de composition, du FAB « Près de moi » de la
/// carte (`home_screen.dart`) : même filtre serveur (`nearMeActive`,
/// `nearMeRadiusKm`, `userLat`/`userLng`), même service de localisation,
/// exposés ici comme un bloc de filtre ordinaire plutôt que comme une action
/// flottante — cet écran n'a pas de carte sous les yeux.
///
/// Pas de `setState` : le seul état local (`_isLocating`, le temps de
/// récupérer la position) vit dans un `ValueNotifier`, sur le même principe
/// que les sheets de sélection de cet écran (poids, prix, rayon).
class _AroundMeBlock extends StatefulWidget {
  const _AroundMeBlock({required this.filters});

  final HomeSearchFilters filters;

  @override
  State<_AroundMeBlock> createState() => _AroundMeBlockState();
}

class _AroundMeBlockState extends State<_AroundMeBlock> {
  final _isLocating = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isLocating.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    const service = GeolocatorLocationService();
    final access = await requestLocationAccess(service);
    if (!mounted) return;
    if (access != LocationAccess.granted) {
      await LocationDeniedSheet.show(context, access: access);
      return;
    }

    _isLocating.value = true;
    Position? position;
    try {
      position = await service.getCurrentPosition();
    } catch (_) {
      // `position` reste `null` : voir la vérification juste après.
    }

    // Un seul point de vérification `mounted`, après le dernier `await` : on
    // ne touche ni `_isLocating` (peut avoir été disposé) ni `context` avant.
    if (!mounted) return;
    _isLocating.value = false;
    if (position == null) return;

    context.read<SearchComposerBloc>().add(
      SearchComposerFiltersChanged(
        widget.filters.copyWith(
          nearMeActive: true,
          nearMeRadiusKm: widget.filters.nearMeRadiusKm ?? 25,
          userLat: position.latitude,
          userLng: position.longitude,
        ),
      ),
    );
  }

  void _deactivate() {
    context.read<SearchComposerBloc>().add(
      SearchComposerFiltersChanged(widget.filters.copyWith(clearNearMe: true)),
    );
  }

  Future<void> _changeRadius() async {
    final radiusKm = await NearMeRadiusSheet.show(
      context,
      initialRadiusKm: widget.filters.nearMeRadiusKm ?? 25,
      confirmLabel: 'Appliquer',
    );
    if (radiusKm == null || !mounted) return;
    context.read<SearchComposerBloc>().add(
      SearchComposerFiltersChanged(
        widget.filters.copyWith(nearMeRadiusKm: radiusKm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final active = widget.filters.nearMeActive;

    return ValueListenableBuilder<bool>(
      valueListenable: _isLocating,
      builder: (context, isLocating, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuickChip(
            label: 'Autour de moi',
            iconAsset: 'circle-dot',
            active: active,
            onChanged: (v) {
              if (isLocating) return;
              if (v) {
                unawaited(_activate());
              } else {
                _deactivate();
              }
            },
          ),
          if (isLocating) ...[
            const SizedBox(height: DonySpacing.sm),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                Text(
                  'Localisation en cours…',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (active && !isLocating) ...[
            const SizedBox(height: DonySpacing.sm),
            GestureDetector(
              onTap: _changeRadius,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                  border: Border.all(color: cs.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rayon · ${(widget.filters.nearMeRadiusKm ?? 25).round()} km',
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
