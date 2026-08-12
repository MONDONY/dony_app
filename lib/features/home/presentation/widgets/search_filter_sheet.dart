// Feuille de filtres unique de l'écran Rechercher.
//
// Elle remplace les deux feuilles d'avant : `SearchFormBottomSheet` (riche,
// trajets) et le `_showPrFilterSheet` bricolé dans `home_screen.dart` (deux
// champs, colis). Le bloc du haut, corridor + date, est le MÊME
// [CommonFilterBlock] dans les deux branches de mode : c'est ce partage, et non
// une symétrie de façade, qui empêche le corridor de se perdre à la bascule.
//
// Ce que le mode colis n'expose volontairement pas : la note et la
// vérification d'identité. Le serveur ne filtre pas les demandes là-dessus,
// les proposer mentirait à l'utilisateur.

import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/content_categories/presentation/content_category_selector.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

export 'package:dony/features/home/presentation/widgets/search_filter_fields.dart'
    show CommonFilterBlock;

abstract final class SearchFilterSheet {
  /// Ouvre la feuille pour [mode], pré-remplie avec [initial].
  ///
  /// Retourne les filtres édités si l'utilisateur valide, `null` s'il ferme
  /// sans valider (croix, barrier, retour système).
  /// [activeTrips] : nombre de trajets actifs de l'utilisateur. À zéro, la
  /// pastille « Pour mes trajets » est désactivée, parce que le filtre
  /// renverrait zéro résultat sans raison visible. À `null` le nombre est
  /// **inconnu** (résumé pas encore chargé, ou échec réseau) : la pastille
  /// reste alors utilisable et c'est le serveur qui tranche, plutôt que
  /// d'affirmer « Aucun trajet actif » à un voyageur qui en a peut-être cinq.
  ///
  /// [onPublishTrip] : appelé quand l'utilisateur choisit « Publier un trajet »
  /// depuis le garde-fou. La feuille est fermée à cet instant, la navigation et
  /// le rechargement du résumé appartiennent donc à l'appelant, qui lui survit.
  static Future<HomeSearchFilters?> show(
    BuildContext context, {
    required SearchMode mode,
    required HomeSearchFilters initial,
    int? activeTrips,
    VoidCallback? onPublishTrip,
    double heightFraction = 0.85,
  }) {
    // État d'édition local : la feuille ne touche à rien tant que l'utilisateur
    // n'a pas validé. Le stickyBottom l'écoute pour savoir s'il doit proposer
    // « Tout effacer ».
    final notifier = ValueNotifier<HomeSearchFilters>(initial);

    return DonyBottomSheet.show<HomeSearchFilters>(
      context,
      title: mode.isTrips ? 'Filtrer les trajets' : 'Filtrer les colis',
      heightFraction: heightFraction,
      stickyBottom: ValueListenableBuilder<HomeSearchFilters>(
        valueListenable: notifier,
        builder: (ctx, value, _) {
          final hasActive = value.activeCountFor(mode) > 0;
          return Row(
            children: [
              if (hasActive) ...[
                Expanded(
                  child: _ClearAllButton(
                    onTap: () => notifier.value = _cleared(value, mode),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
              ],
              Expanded(
                flex: 2,
                child: DonyButton(
                  // Même libellé dans les deux modes : l'ancienne feuille colis
                  // disait « Appliquer », l'incohérence disparaît.
                  label: 'Rechercher',
                  onPressed: () => Navigator.of(
                    ctx,
                    rootNavigator: true,
                  ).pop(notifier.value),
                ),
              ),
            ],
          );
        },
      ),
      child: _SearchFilterContent(
        mode: mode,
        notifier: notifier,
        activeTrips: activeTrips,
        onPublishTrip: onPublishTrip,
      ),
    ).whenComplete(notifier.dispose);
  }

  /// Efface les filtres communs et ceux du mode courant. Ceux de l'autre mode
  /// sont préservés : ils ne sont pas comptés par `activeCountFor(mode)`, les
  /// effacer serait une surprise invisible.
  ///
  /// `urgentOnly` et `nearMeActive` sont bien effacés alors que la feuille ne
  /// les expose pas, et c'est volontaire : ce sont des filtres **communs**,
  /// comptés par `activeCountFor(mode)`, donc c'est notamment eux qui font
  /// apparaître le bouton « Tout effacer ». Les épargner produirait un « Tout
  /// effacer » qui n'efface pas tout et qui reste affiché après le tap, avec
  /// un badge de filtres toujours à 1. Leur disparition n'est pas invisible :
  /// leurs pastilles (🔥 Urgent, « Près de moi ») vivent sur l'écran
  /// Rechercher, derrière la feuille, et se désactivent dès la validation.
  static HomeSearchFilters _cleared(HomeSearchFilters value, SearchMode mode) {
    final common = value.copyWith(
      clearCorridor: true,
      datePreset: DonyDatePreset.none,
      clearCustomDate: true,
      urgentOnly: false,
      clearNearMe: true,
    );
    if (mode.isTrips) {
      return common.copyWith(
        clearMaxPricePerKg: true,
        clearWeight: true,
        kiloProOnly: false,
        clearMinRating: true,
        weekendOnly: false,
        clearTransportMode: true,
        kycVerifiedOnly: false,
        clearContentType: true,
        clearUrgencyFilter: true,
      );
    }
    return common.copyWith(
      clearMaxWeight: true,
      clearParcelSize: true,
      matchingMyTrips: false,
    );
  }
}

class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          border: Border.all(color: cs.outline),
        ),
        child: Center(
          child: Text(
            'Tout effacer',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contenu défilant ──────────────────────────────────────────────────────────

class _SearchFilterContent extends StatefulWidget {
  const _SearchFilterContent({
    required this.mode,
    required this.notifier,
    this.activeTrips,
    this.onPublishTrip,
  });

  final SearchMode mode;
  final ValueNotifier<HomeSearchFilters> notifier;

  /// Nombre de trajets actifs, `null` si inconnu — voir [SearchFilterSheet.show].
  final int? activeTrips;

  /// Publication d'un trajet demandée depuis le garde-fou — voir
  /// [SearchFilterSheet.show].
  final VoidCallback? onPublishTrip;

  @override
  State<_SearchFilterContent> createState() => _SearchFilterContentState();
}

class _SearchFilterContentState extends State<_SearchFilterContent> {
  // Le catalogue est chargé par ContentCategorySelector lui-même.

  static const _maxWeightPresets = <double>[5, 10, 20];

  HomeSearchFilters get _value => widget.notifier.value;

  void _update(HomeSearchFilters next) => widget.notifier.value = next;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HomeSearchFilters>(
      valueListenable: widget.notifier,
      builder: (context, f, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le bloc commun : un seul widget, instancié à l'identique dans
            // les deux modes.
            CommonFilterBlock(value: f, onChanged: _update),
            const SizedBox(height: DonySpacing.xl),
            if (widget.mode.isTrips)
              ..._tripsSection(context, f)
            else
              ..._parcelsSection(context, f),
            const SizedBox(height: DonySpacing.sm),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
    );
  }

  // ── Trajets ────────────────────────────────────────────────────────────────

  List<Widget> _tripsSection(BuildContext context, HomeSearchFilters f) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return [
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
                  maxPrice: _value.maxPricePerKg,
                  onApply: (v) => _update(
                    v == null
                        ? _value.copyWith(clearMaxPricePerKg: true)
                        : _value.copyWith(maxPricePerKg: v),
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
                  mode: _value.transportMode,
                  onApply: (v) => _update(
                    v == null
                        ? _value.copyWith(clearTransportMode: true)
                        : _value.copyWith(transportMode: v),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ).animate().fadeIn(delay: 60.ms),
      const SizedBox(height: DonySpacing.xl),

      _sectionLabel(context, 'FILTRES RAPIDES'),
      const SizedBox(height: DonySpacing.md),
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
      ).animate().fadeIn(delay: 80.ms),
      const SizedBox(height: DonySpacing.xl),

      _sectionLabel(context, 'MON COLIS CONTIENT'),
      const SizedBox(height: DonySpacing.md),
      // Autocomplétion plutôt que les onze types dépliés : la liste occupait
      // la feuille entière et repoussait « Urgence du départ » hors écran.
      // `singleSelection` conserve la sémantique du filtre, dont le critère
      // contenu est une valeur unique côté requête.
      //
      // Le selector charge lui-même le catalogue et le passe en
      // `ContentCategory` complets : pas de conversion depuis des libellés,
      // donc les emojis venus du backend sont conservés.
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
      ).animate().fadeIn(delay: 100.ms),
      const SizedBox(height: DonySpacing.xl),

      _sectionLabel(context, 'URGENCE DU DÉPART'),
      const SizedBox(height: DonySpacing.xs),
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

  // ── Colis ──────────────────────────────────────────────────────────────────

  List<Widget> _parcelsSection(BuildContext context, HomeSearchFilters f) {
    return [
      _sectionLabel(context, 'POIDS MAXIMAL'),
      const SizedBox(height: DonySpacing.md),
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
      const SizedBox(height: DonySpacing.xl),

      _sectionLabel(context, 'TAILLE DU COLIS'),
      const SizedBox(height: DonySpacing.md),
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
      const SizedBox(height: DonySpacing.xl),

      _sectionLabel(context, 'FILTRES RAPIDES'),
      const SizedBox(height: DonySpacing.md),
      Wrap(
        spacing: DonySpacing.sm,
        runSpacing: DonySpacing.sm,
        children: [
          // Sans trajet actif le filtre renverrait zéro sans raison visible :
          // la pastille est grisée et son tap explique la situation au lieu de
          // lancer une recherche vide. Nombre INCONNU (résumé en échec) : la
          // pastille reste utilisable, on ne grise pas sur une supposition.
          Opacity(
            opacity: _canFilterOnMyTrips ? 1 : 0.4,
            child: QuickChip(
              key: const Key('chip-matching-my-trips'),
              label: 'Pour mes trajets',
              iconAsset: 'plane',
              active: f.matchingMyTrips,
              onChanged: _canFilterOnMyTrips
                  ? (v) => _update(f.copyWith(matchingMyTrips: v))
                  : (_) => _showNoActiveTripSheet(context),
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

  /// Le filtre n'est bloqué que sur une certitude : zéro trajet actif CONNU.
  /// Nombre inconnu (`null`) → pastille utilisable, le serveur tranchera.
  bool get _canFilterOnMyTrips {
    final trips = widget.activeTrips;
    return trips == null || trips > 0;
  }

  /// Depuis la feuille de filtres, deux feuilles sont empilées : l'explication
  /// et la feuille elle-même.
  Future<void> _showNoActiveTripSheet(BuildContext context) =>
      showNoActiveTripSheet(
        context,
        sheetsToPop: 2,
        onPublishTrip: widget.onPublishTrip,
      );

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

/// Explique pourquoi « Pour mes trajets » est indisponible et propose l'action
/// qui le débloque. Source unique de cette formulation : le filtre est offert à
/// deux endroits, la rangée de chips et la feuille de filtres, et les deux
/// doivent dire la même chose.
///
/// [sheetsToPop] vaut 1 depuis la rangée de chips, où seule l'explication est
/// ouverte, et 2 depuis la feuille de filtres, qui reste empilée dessous. Les
/// feuilles se ferment avant la navigation, sinon la création de trajet
/// s'ouvrirait derrière elles.
///
/// La navigation appartient à l'appelant, seul à survivre à la fermeture : lui
/// seul peut attendre le retour de la création de trajet puis recharger le
/// résumé, sans quoi la pastille resterait grisée au retour.
Future<void> showNoActiveTripSheet(
  BuildContext context, {
  required int sheetsToPop,
  VoidCallback? onPublishTrip,
}) {
  final sheetNavigator = Navigator.of(context, rootNavigator: true);
  return DonyBottomSheet.show<void>(
    context,
    title: 'Aucun trajet actif',
    subtitle:
        'Ce filtre ne montre que les colis compatibles avec tes '
        'trajets à venir. Publie un trajet pour t\'en servir.',
    stickyBottom: DonyButton(
      label: 'Publier un trajet',
      onPressed: () {
        for (var i = 0; i < sheetsToPop; i++) {
          sheetNavigator.pop();
        }
        onPublishTrip?.call();
      },
    ),
    child: const SizedBox.shrink(),
  );
}
