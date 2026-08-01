import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:dony/features/city/presentation/widgets/city_autocomplete_field.dart';
import 'package:dony/features/city/presentation/widgets/city_swap_button.dart';
import 'package:dony/features/matching/presentation/utils/city_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Champ de départ + champ d'arrivée, toujours ensemble : mêmes suggestions
/// « récents » (voir [RecentCityStore]) et même bouton d'interversion partout
/// dans l'app où un corridor ville A → ville B se saisit (recherche, création
/// de trajet, alerte corridor, modèle de trajet…) — pour que ces deux
/// fonctionnalités ne divergent jamais d'un écran à l'autre.
///
/// Rendu « billet » (référence compagnie aérienne) : deux rangées pleine
/// largeur dans une même carte, départ sur fond neutre, arrivée sur fond
/// légèrement teinté (`cs.surfaceWarm`) pour les distinguer sans bordure
/// interne. Ville en gros/gras + drapeau du pays, et bouton d'interversion
/// rond posé sur la couture entre les deux rangées, contre le bord droit.
///
/// Le bouton est centré verticalement sur la carte, ce qui **suppose les deux
/// rangées de hauteur égale** : d'où la hauteur figée de la ligne de valeur
/// côté champ, et le rendu des messages d'erreur sous la carte plutôt que
/// dans la rangée fautive (qui deviendrait plus haute que l'autre).
///
/// Ce bouton est un overlay ([Stack]) : il est donc **masqué dès qu'une liste
/// de suggestions s'ouvre**. Sans ça, la carte grandit, le bouton centré
/// glisse au milieu de la liste et intercepte le tap destiné à une suggestion
/// (constaté en test : 9 échecs « découverte croisée »).
class CityCorridorFields extends StatefulWidget {
  const CityCorridorFields({
    super.key,
    required this.departureValue,
    required this.arrivalValue,
    required this.departureFieldKey,
    required this.arrivalFieldKey,
    required this.onDepartureSelected,
    required this.onArrivalSelected,
    required this.onDepartureCleared,
    required this.onArrivalCleared,
    required this.onSwap,
    this.requiredLabels = false,
    this.departureError,
    this.arrivalError,
    this.departureCityBloc,
    this.arrivalCityBloc,
  });

  final String? departureValue;
  final String? arrivalValue;
  final Key departureFieldKey;
  final Key arrivalFieldKey;
  final ValueChanged<CityModel> onDepartureSelected;
  final ValueChanged<CityModel> onArrivalSelected;
  final VoidCallback onDepartureCleared;
  final VoidCallback onArrivalCleared;

  /// Échange départ et arrivée. Ce widget n'y touche pas lui-même : c'est
  /// l'appelant qui porte l'état (`HomeSearchFilters.swapCorridor()`, un
  /// `ValueNotifier`, un `setState` local…).
  final VoidCallback onSwap;

  /// Astérisque rouge sur les deux labels — à activer quand le corridor est
  /// obligatoire pour soumettre le formulaire (création de trajet, modèle…).
  final bool requiredLabels;

  /// Messages de champ obligatoire non renseigné, affichés sous la carte.
  /// `null` = aucun message (cas des écrans de recherche, où le corridor est
  /// facultatif).
  final String? departureError;
  final String? arrivalError;

  /// Blocs de recherche injectables — réservés aux tests, qui ont besoin de
  /// piloter l'état des suggestions. `null` en production : chaque champ crée
  /// alors le sien via GetIt.
  final CitySearchBloc? departureCityBloc;
  final CitySearchBloc? arrivalCityBloc;

  @override
  State<CityCorridorFields> createState() => _CityCorridorFieldsState();
}

class _CityCorridorFieldsState extends State<CityCorridorFields> {
  /// Rôles dont la liste de suggestions est ouverte. Un ensemble plutôt que
  /// deux booléens : la seule question posée est « y en a-t-il au moins une ».
  final _openSuggestions = <CityFieldRole>{};

  /// Piloté hors `setState` : masquer un bouton de 44 dp ne doit pas
  /// reconstruire toute la carte (donc les deux champs, leurs décorations et
  /// leurs listes) une frame sur deux pendant la saisie.
  final _showSwap = ValueNotifier<bool>(true);

  /// Espace réservé à droite dans chaque rangée pour que la valeur et le
  /// bouton « x » ne passent jamais sous le bouton rond superposé.
  static const double _swapInset = 12;
  static const EdgeInsets _rowPadding = EdgeInsets.fromLTRB(
    DonySpacing.base,
    DonySpacing.sm,
    kDonyMinTapTarget + _swapInset,
    DonySpacing.sm,
  );

  void _onSuggestions(CityFieldRole role, {required bool visible}) {
    final changed = visible
        ? _openSuggestions.add(role)
        : _openSuggestions.remove(role);
    if (changed) {
      _showSwap.value = _openSuggestions.isEmpty;
    }
  }

  @override
  void dispose() {
    _showSwap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: _rowPadding,
                    child: BlocProvider(
                      create: (_) =>
                          widget.departureCityBloc ?? getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        fieldKey: widget.departureFieldKey,
                        label: 'Départ',
                        requiredLabel: widget.requiredLabels,
                        initialValue: widget.departureValue,
                        variant: CityFieldVariant.connected,
                        recentRole: CityFieldRole.departure,
                        valueSuffix: _flagSuffix(widget.departureValue),
                        onSuggestionsVisibilityChanged: (visible) =>
                            _onSuggestions(
                              CityFieldRole.departure,
                              visible: visible,
                            ),
                        onSelected: widget.onDepartureSelected,
                        onCleared: widget.onDepartureCleared,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceWarm,
                      border: Border(top: BorderSide(color: cs.outline)),
                    ),
                    padding: _rowPadding,
                    child: BlocProvider(
                      create: (_) =>
                          widget.arrivalCityBloc ?? getIt<CitySearchBloc>(),
                      child: CityAutocompleteField(
                        fieldKey: widget.arrivalFieldKey,
                        label: 'Arrivée',
                        requiredLabel: widget.requiredLabels,
                        initialValue: widget.arrivalValue,
                        variant: CityFieldVariant.connected,
                        recentRole: CityFieldRole.arrival,
                        valueSuffix: _flagSuffix(widget.arrivalValue),
                        onSuggestionsVisibilityChanged: (visible) =>
                            _onSuggestions(
                              CityFieldRole.arrival,
                              visible: visible,
                            ),
                        onSelected: widget.onArrivalSelected,
                        onCleared: widget.onArrivalCleared,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: _swapInset,
              child: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showSwap,
                  builder: (context, visible, child) =>
                      visible ? child! : const SizedBox.shrink(),
                  child: CitySwapButton(onTap: widget.onSwap),
                ),
              ),
            ),
          ],
        ),
        // Sous la carte, pas dans la rangée fautive : un message inséré dans
        // une seule des deux rangées la rendrait plus haute que l'autre et
        // décalerait le bouton d'interversion de la couture.
        DonyFieldError(message: widget.departureError),
        DonyFieldError(message: widget.arrivalError),
      ],
    );
  }

  /// Drapeau du pays affiché juste après la ville (ex : « Paris 🇫🇷 »).
  /// `null` pour une ville inconnue de [cityFlag] — le champ reste alors
  /// sans décoration, pas de fallback visuel ici (la valeur seule suffit).
  Widget? _flagSuffix(String? city) {
    if (city == null || city.isEmpty) {
      return null;
    }
    final flag = cityFlag(city);
    if (flag == null) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: DonyEmoji(flag, size: 18, semanticLabel: city),
    );
  }
}
