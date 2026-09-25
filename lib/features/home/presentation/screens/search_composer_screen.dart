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
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/presentation/widgets/city_corridor_fields.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/home/bloc/search_composer_bloc.dart';
import 'package:dony/features/home/bloc/search_composer_event.dart';
import 'package:dony/features/home/bloc/search_composer_state.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/no_active_trip_sheet.dart';
import 'package:dony/features/home/presentation/widgets/parsed_recap_card.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/home/presentation/widgets/search_phrase_field.dart';
import 'package:dony/features/home/presentation/widgets/search_section_label.dart';
import 'package:dony/features/home/presentation/widgets/unresolved_question.dart';
import 'package:dony/features/matching/presentation/widgets/location_permission.dart';
import 'package:dony/features/matching/presentation/widgets/near_me_radius_sheet.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/l10n/l10n.dart';
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
  });

  final SearchMode mode;
  final HomeSearchFilters initialFilters;

  /// Nombre de trajets actifs de l'utilisateur, transmis par la route
  /// `/recherche/composer` (`lib/app/router.dart`). `null` : nombre inconnu,
  /// la pastille « Pour mes trajets » reste utilisable, le serveur tranchera.
  final int? activeTrips;

  /// Publication d'un trajet demandée depuis le garde-fou « Pour mes trajets ».
  final VoidCallback? onPublishTrip;

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

  // Vider un champ de ville DOIT vider le filtre correspondant : sans ça le
  // champ paraît vide alors que la recherche applique toujours l'ancienne
  // ville. `copyWith` n'expose qu'un seul drapeau d'effacement pour le
  // corridor (`clearCorridor`), qui efface les deux villes d'un coup : on
  // l'applique puis on réinjecte celle qu'on garde.
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: Text(
          widget.mode.isTrips
              ? l.homeComposerTitleTrips
              : l.homeComposerTitleParcels,
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<SearchComposerBloc>().add(
              const SearchComposerCleared(),
            ),
            child: Text(l.homeComposerClearAll),
          ),
          const DonyFeedbackButton(),
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
              // Le parseur serveur (/search/parse) ne comprend que le
              // français : la saisie en une phrase n'est proposée qu'en
              // français, les filtres au doigt restent disponibles partout.
              if (l.localeName == 'fr') ...[
                SearchSectionLabel(l.homeComposerSectionPhrase, optional: true),
                SearchPhraseField(
                  controller: _phraseController,
                  onSubmitted: _submitPhrase,
                  isParsing: state.isParsing,
                ).animate().fadeIn(duration: 250.ms),
                if (state.recognized.isNotEmpty)
                  ParsedRecapCard(state.recognized),
                for (final item in state.unresolved) UnresolvedQuestion(item),
              ],

              SearchSectionLabel(l.homeComposerSectionWhere),
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

              SearchSectionLabel(l.homeComposerSectionWhen),
              DatePresetsField(
                value: f,
                onChanged: _update,
              ).animate().fadeIn(delay: 20.ms),

              if (widget.mode.isTrips)
                ..._tripsBlocks(context, f)
              else
                ..._parcelsBlocks(context, f),

              SearchSectionLabel(l.homeComposerSectionAroundMe),
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
                  ? l.homeComposerSearch
                  : l.homeComposerSearchWithCount(state.resultCount!);
              return DonyButton(
                label: label,
                // `context.read` et non le `state` capturé par ce
                // `BlocBuilder` : son `buildWhen` ne rebuild que sur
                // `resultCount`, qui peut ne jamais changer (comptage en
                // échec, resté `null` du début à la fin) alors que les
                // filtres, eux, ont bougé. Lire l'état au tap plutôt que celui
                // du dernier rebuild garantit que ce sont les VRAIS derniers
                // filtres qui reviennent, pas une capture périmée.
                //
                // `phrase` retombe à '' dès « Tout effacer » (nouvel état
                // repartant de zéro) : un `cameFromPhrase` calculé ici, plutôt
                // que suivi par un flag séparé, épouse donc naturellement une
                // recherche recommencée au doigt après une phrase abandonnée.
                onPressed: () {
                  final latest = context.read<SearchComposerBloc>().state;
                  context.pop((
                    filters: latest.filters,
                    cameFromPhrase: latest.phrase.isNotEmpty,
                  ));
                },
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
    final l = context.l10n;
    return [
      SearchSectionLabel(l.homeComposerSectionWeightPrice),
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

      SearchSectionLabel(l.homeComposerSectionContents),
      // Autocomplétion plutôt que les onze types dépliés : la liste occuperait
      // l'écran entier. `singleSelection` conserve la sémantique du filtre.
      ContentCategorySelector(
        repository: getIt<IContentCategoryRepository>(),
        keyPrefix: 'filter-content',
        singleSelection: true,
        hint: l.homeComposerContentHint,
        selected: f.contentType == null ? const [] : [f.contentType!],
        onChanged: (sel) => _update(
          sel.isEmpty
              ? f.copyWith(clearContentType: true)
              : f.copyWith(contentType: sel.last),
        ),
      ).animate().fadeIn(delay: 80.ms),

      SearchSectionLabel(l.homeComposerSectionQuickFilters),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          QuickChip(
            label: 'Kilo Pro', // i18n-ignore
            iconAsset: 'award',
            active: f.kiloProOnly,
            onChanged: (v) => _update(f.copyWith(kiloProOnly: v)),
          ),
          QuickChip(
            label: l.homeComposerMinRating,
            iconAsset: 'star',
            active: f.minRating != null,
            onChanged: (v) => _update(
              v ? f.copyWith(minRating: 4.5) : f.copyWith(clearMinRating: true),
            ),
          ),
          QuickChip(
            label: l.homeComposerWeekend,
            iconAsset: 'sofa',
            active: f.weekendOnly,
            onChanged: (v) => _update(f.copyWith(weekendOnly: v)),
          ),
          QuickChip(
            label: l.homeComposerVerifiedIdentity,
            iconAsset: 'shield-check',
            active: f.kycVerifiedOnly,
            onChanged: (v) => _update(f.copyWith(kycVerifiedOnly: v)),
          ),
        ],
      ).animate().fadeIn(delay: 100.ms),

      SearchSectionLabel(l.homeComposerSectionUrgency),
      Text(
        l.homeComposerUrgencyHint,
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
    final l = context.l10n;
    return [
      SearchSectionLabel(l.homeComposerSectionMaxWeight),
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

      SearchSectionLabel(l.homeComposerSectionParcelSize),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          for (final size in ParcelSize.values)
            ContentTypeChip(
              label: _parcelSizeLabel(l, size),
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

      SearchSectionLabel(l.homeComposerSectionQuickFilters),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          Opacity(
            opacity: _canFilterOnMyTrips ? 1 : 0.4,
            child: QuickChip(
              key: const Key('chip-matching-my-trips'),
              label: l.homeComposerForMyTrips,
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
        l.homeComposerAlertTip,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ).animate().fadeIn(delay: 100.ms),
    ];
  }

  static String _parcelSizeLabel(AppLocalizations l, ParcelSize s) =>
      switch (s) {
        ParcelSize.small => l.parcelSizeSmall,
        ParcelSize.medium => l.parcelSizeMedium,
        ParcelSize.large => l.parcelSizeLarge,
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
      confirmLabel: context.l10n.commonApply,
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
    final l = context.l10n;

    return ValueListenableBuilder<bool>(
      valueListenable: _isLocating,
      builder: (context, isLocating, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuickChip(
            label: l.homeComposerAroundMe,
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
                  l.homeComposerLocating,
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
                      l.homeRadiusKm(
                        (widget.filters.nearMeRadiusKm ?? 25).round(),
                      ),
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
