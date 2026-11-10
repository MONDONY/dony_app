import 'package:dony/core/utils/text_search.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:equatable/equatable.dart';

/// Texte de corridor comparable : sans casse, sans accent, sans espace ni
/// ponctuation de mot (tiret, apostrophe, point). « Côte d'Ivoire », « cote
/// divoire » et « COTE-D’IVOIRE » donnent la même clé.
String normalizeCorridorText(String? text) {
  if (text == null) return '';
  return normalizeSearch(text).replaceAll(RegExp(r"[\s\-'’.]+"), '');
}

/// Corridor d'un moment : ce que l'app sait du départ et de l'arrivée de la
/// recherche, du trajet ou du formulaire concerné.
///
/// Chaque côté garde plusieurs termes comparables (ville, code pays, nom du
/// pays en français et en anglais) : une campagne écrite « Paris » comme une
/// campagne écrite « France » reconnaît un trajet Paris vers Abidjan.
class VideoModalMomentCorridor extends Equatable {
  const VideoModalMomentCorridor._(this.from, this.to);

  /// Corridor sans termes (aucun départ ni arrivée connus).
  static const empty = VideoModalMomentCorridor._({}, {});

  /// Construit le corridor depuis les villes et codes pays pays connus (tous
  /// facultatifs).
  factory VideoModalMomentCorridor({
    String? fromCity,
    String? fromCountryCode,
    String? toCity,
    String? toCountryCode,
  }) => VideoModalMomentCorridor._(
    _terms(fromCity, fromCountryCode),
    _terms(toCity, toCountryCode),
  );

  /// Termes normalisés du départ et de l'arrivée.
  final Set<String> from;
  final Set<String> to;

  /// Rien n'est connu du corridor.
  bool get isEmpty => from.isEmpty && to.isEmpty;

  static final _fr = AppLocalizationsFr();
  static final _en = AppLocalizationsEn();

  static Set<String> _terms(String? city, String? countryCode) {
    final terms = <String>{};
    void add(String? text) {
      final key = normalizeCorridorText(text);
      if (key.isNotEmpty) terms.add(key);
    }

    add(city);
    final code = countryCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      add(code);
      // Un code inconnu de l'app est renvoyé tel quel : déjà ajouté.
      add(countryName(_fr, code));
      add(countryName(_en, code));
    }
    return terms;
  }

  @override
  List<Object?> get props => [from, to];
}

/// Une entrée de `corridors` d'une campagne : départ et arrivée en texte
/// libre (ville ou pays), `null` = n'importe lequel.
class VideoModalCorridor extends Equatable {
  const VideoModalCorridor({this.from, this.to});

  static const maxEntries = 10;

  final String? from;
  final String? to;

  /// Entrée lisible, ou `null` si ce n'est pas un objet ou si un côté n'est
  /// ni texte ni nul.
  static VideoModalCorridor? tryParse(Object? json) {
    if (json is! Map) return null;
    final from = _side(json['from']);
    final to = _side(json['to']);
    if (from == _invalid || to == _invalid) return null;
    return VideoModalCorridor(from: from as String?, to: to as String?);
  }

  static const _invalid = Object();

  static Object? _side(Object? value) {
    if (value == null) return null;
    if (value is! String) return _invalid;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// Le corridor du moment correspond à cette entrée. Un côté renseigné doit
  /// se retrouver parmi les termes du côté correspondant ; un moment sans
  /// corridor connu ne correspond à aucune entrée précise.
  bool matches(VideoModalMomentCorridor? corridor) {
    if (corridor == null || corridor.isEmpty) return false;
    final from = this.from;
    final to = this.to;
    if (from != null && !corridor.from.contains(normalizeCorridorText(from))) {
      return false;
    }
    if (to != null && !corridor.to.contains(normalizeCorridorText(to))) {
      return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [from, to];
}

/// Options des déclencheurs de moment (`triggerOptions`), avec les valeurs
/// d'un back qui ne les envoie pas.
class VideoModalTriggerOptions extends Equatable {
  const VideoModalTriggerOptions({
    this.fewResultsMax = defaultFewResultsMax,
    this.tripViewedTimes = defaultTripViewedTimes,
  });

  static const defaultFewResultsMax = 2;
  static const defaultTripViewedTimes = 3;
  static const minFewResultsMax = 1;
  static const maxFewResultsMax = 20;
  static const minTripViewedTimes = 2;
  static const maxTripViewedTimes = 10;

  /// `SEARCH_FEW_RESULTS` : de 1 résultat à ce nombre inclus.
  final int fewResultsMax;

  /// `TRIP_VIEWED_REPEATEDLY` : nombre de consultations du même trajet.
  final int tripViewedTimes;

  /// Lit l'objet du back. Un champ absent, illisible ou hors bornes retombe
  /// sur sa valeur par défaut.
  static VideoModalTriggerOptions parse(Object? json) {
    if (json is! Map) return const VideoModalTriggerOptions();
    return VideoModalTriggerOptions(
      fewResultsMax: _bounded(
        json['fewResultsMax'],
        minFewResultsMax,
        maxFewResultsMax,
        defaultFewResultsMax,
      ),
      tripViewedTimes: _bounded(
        json['tripViewedTimes'],
        minTripViewedTimes,
        maxTripViewedTimes,
        defaultTripViewedTimes,
      ),
    );
  }

  static int _bounded(Object? value, int min, int max, int fallback) {
    final n = value is num ? value.toInt() : null;
    return n != null && n >= min && n <= max ? n : fallback;
  }

  @override
  List<Object?> get props => [fewResultsMax, tripViewedTimes];
}
