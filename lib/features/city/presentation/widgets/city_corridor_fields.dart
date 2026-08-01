import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
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
/// Ce bouton est un overlay ([Stack]) : il est donc **masqué dès qu'une liste
/// de suggestions s'ouvre**. Sans ça, la carte grandit, le bouton centré
/// glisse au milieu de la liste et intercepte le tap destiné à une suggestion
/// (constaté en test : 9 échecs « découverte croisée »). Les deux rangées
/// ayant une structure identique, la couture est exactement au centre vertical
/// de la carte tant qu'aucune suggestion n'est ouverte — d'où le centrage
/// simple par [Positioned] plein hauteur.
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

  /// Messages de champ obligatoire non renseigné, affichés sous la valeur
  /// concernée. `null` = aucun message (cas des écrans de recherche, où le
  /// corridor est facultatif).
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
  bool _departureSuggestions = false;
  bool _arrivalSuggestions = false;

  bool get _showSwap => !_departureSuggestions && !_arrivalSuggestions;

  /// Espace réservé à droite dans chaque rangée pour que la valeur et le
  /// bouton « x » ne passent jamais sous le bouton rond superposé.
  static const double _swapInset = 12;
  static const double _rowRightPadding = kDonyMinTapTarget + _swapInset;

  void _onDepartureSuggestions(bool visible) {
    if (_departureSuggestions != visible) {
      setState(() => _departureSuggestions = visible);
    }
  }

  void _onArrivalSuggestions(bool visible) {
    if (_arrivalSuggestions != visible) {
      setState(() => _arrivalSuggestions = visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
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
              _TicketRow(
                background: cs.surface,
                rightPadding: _rowRightPadding,
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
                    errorText: widget.departureError,
                    onSuggestionsVisibilityChanged: _onDepartureSuggestions,
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
                child: _TicketRow(
                  background: Colors.transparent,
                  rightPadding: _rowRightPadding,
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
                      errorText: widget.arrivalError,
                      onSuggestionsVisibilityChanged: _onArrivalSuggestions,
                      onSelected: widget.onArrivalSelected,
                      onCleared: widget.onArrivalCleared,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showSwap)
          Positioned(
            top: 0,
            bottom: 0,
            right: _swapInset,
            child: Center(child: CitySwapButton(onTap: widget.onSwap)),
          ),
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
      child: Text(flag, style: const TextStyle(fontSize: 18)),
    );
  }
}

/// Rangée pleine largeur d'une carte billet : padding généreux uniforme, et
/// une marge droite élargie pour laisser passer le bouton d'interversion.
class _TicketRow extends StatelessWidget {
  const _TicketRow({
    required this.background,
    required this.rightPadding,
    required this.child,
  });

  final Color background;
  final double rightPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: EdgeInsets.fromLTRB(
        DonySpacing.base, DonySpacing.sm, rightPadding, DonySpacing.sm,
      ),
      child: child,
    );
  }
}
