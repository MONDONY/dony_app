import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Champs obligatoires des étapes 1 (Trajet) et 2 (Lieux et capacité) du
/// formulaire « Publier un trajet ». Le nom de chaque valeur est aussi son
/// nom technique dans l'analytics (jamais de valeur saisie).
enum TripRequiredField {
  departureCity,
  arrivalCity,
  departureDate,
  departureTime,
  transportMode,
  handoverDeadline,
  pickupAddress,
  deliveryAddress,
}

class TripMissingFieldsState extends Equatable {
  const TripMissingFieldsState({
    this.step = 0,
    this.attempted = false,
    this.missing = const [],
    this.focusField,
    this.focusSeq = 0,
  });

  /// Étape à laquelle se rapportent [missing] et [attempted] (0 Trajet,
  /// 1 Lieux et capacité).
  final int step;

  /// « Continuer » touché à cette étape alors qu'il manquait des champs : les
  /// champs manquants sont marqués, le bandeau et les pastilles s'affichent.
  final bool attempted;

  /// Champs obligatoires encore vides, dans l'ordre d'affichage.
  final List<TripRequiredField> missing;

  /// Champ vers lequel défiler, renouvelé par [focusSeq] (même champ deux
  /// fois de suite : deux défilements).
  final TripRequiredField? focusField;
  final int focusSeq;

  /// Le champ [f] est à marquer (contour, valeur « Choisir », message).
  bool isMarked(TripRequiredField f) => attempted && missing.contains(f);

  /// Bandeau et pastilles visibles à l'étape [currentStep].
  bool showSummaryAt(int currentStep) =>
      attempted && step == currentStep && missing.isNotEmpty;

  TripMissingFieldsState copyWith({
    int? step,
    bool? attempted,
    List<TripRequiredField>? missing,
    TripRequiredField? focusField,
    int? focusSeq,
  }) => TripMissingFieldsState(
    step: step ?? this.step,
    attempted: attempted ?? this.attempted,
    missing: missing ?? this.missing,
    focusField: focusField ?? this.focusField,
    focusSeq: focusSeq ?? this.focusSeq,
  );

  @override
  List<Object?> get props => [step, attempted, missing, focusField, focusSeq];
}

/// Champs obligatoires manquants des étapes 1 et 2 de la création d'un
/// trajet : « Continuer » reste actif, et un appui avec des champs vides
/// n'avance pas, les signale et fait défiler jusqu'au premier.
///
/// Le formulaire calcule lui-même la liste des manquants (ses règles de
/// validation restent les siennes) et la pousse ici à chaque changement.
class TripMissingFieldsCubit extends Cubit<TripMissingFieldsState> {
  TripMissingFieldsCubit(this._analytics)
    : super(const TripMissingFieldsState());

  final AnalyticsService _analytics;

  /// Relit les manquants de l'étape [step]. Changer d'étape efface la
  /// tentative : l'étape suivante s'ouvre sans marque.
  void sync(int step, List<TripRequiredField> missing) {
    final stepChanged = step != state.step;
    final next = state.copyWith(
      step: step,
      missing: List.unmodifiable(missing),
      attempted: stepChanged ? false : state.attempted,
    );
    if (next != state) emit(next);
  }

  /// Appui sur « Continuer » à l'étape [step]. Vrai : rien ne manque, le
  /// formulaire peut avancer. Faux : les champs sont marqués et l'écran
  /// défile vers le premier.
  bool tryContinue(int step, List<TripRequiredField> missing) {
    sync(step, missing);
    if (missing.isEmpty) return true;
    emit(
      state.copyWith(
        attempted: true,
        focusField: missing.first,
        focusSeq: state.focusSeq + 1,
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripStepBlockedMissingFields,
        properties: {
          'step': step,
          'count': missing.length,
          'fields': [for (final f in missing) f.name],
        },
      ),
    );
    return false;
  }

  /// Pastille d'un champ manquant touchée : l'écran défile jusqu'à lui.
  void chipTapped(TripRequiredField field) {
    emit(state.copyWith(focusField: field, focusSeq: state.focusSeq + 1));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripMissingFieldChipTapped,
        properties: {'field': field.name},
      ),
    );
  }
}
