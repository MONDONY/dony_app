import 'package:dony/features/corridor_alerts/data/corridor_alert_repository.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum CorridorAlertSummaryStatus { initial, loading, loaded, hidden }

/// Ce que le hub Activités montre des alertes sans ouvrir leur écran : ce
/// qui est arrivé depuis la dernière visite, et sur quels corridors.
class CorridorAlertSummaryState extends Equatable {
  const CorridorAlertSummaryState._(
    this.status, {
    this.newMatchCount = 0,
    this.newCorridors = const [],
  });

  const CorridorAlertSummaryState.initial()
    : this._(CorridorAlertSummaryStatus.initial);
  const CorridorAlertSummaryState.loading()
    : this._(CorridorAlertSummaryStatus.loading);

  /// Échec réseau : la tuile retombe sur son état de configuration, sans
  /// jamais afficher un faux « rien de neuf ».
  const CorridorAlertSummaryState.hidden()
    : this._(CorridorAlertSummaryStatus.hidden);

  factory CorridorAlertSummaryState.fromAlerts(
    List<CorridorAlertModel> alerts, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    // Une alerte en pause ou expirée n'alimente pas le signal : l'utilisateur
    // l'a coupée, ou elle ne peut plus rien trouver de neuf.
    final live =
        alerts
            .where((a) => a.active && !a.isExpiredAt(at) && a.hasNews)
            .toList()
          ..sort((a, b) => b.newMatchCount.compareTo(a.newMatchCount));
    final corridors = <String>[];
    for (final a in live) {
      if (!corridors.contains(a.corridorLabel)) {
        corridors.add(a.corridorLabel);
      }
    }
    return CorridorAlertSummaryState._(
      CorridorAlertSummaryStatus.loaded,
      newMatchCount: live.fold(0, (sum, a) => sum + a.newMatchCount),
      newCorridors: corridors,
    );
  }

  final CorridorAlertSummaryStatus status;

  /// Nouveautés cumulées sur les alertes actives et non expirées.
  final int newMatchCount;

  /// Corridors concernés, celui qui a le plus de nouveautés en premier.
  final List<String> newCorridors;

  bool get isLoaded => status == CorridorAlertSummaryStatus.loaded;
  bool get hasNews => isLoaded && newMatchCount > 0;

  @override
  List<Object?> get props => [status, newMatchCount, newCorridors];
}

class CorridorAlertSummaryCubit extends Cubit<CorridorAlertSummaryState> {
  CorridorAlertSummaryCubit(this._repository)
    : super(const CorridorAlertSummaryState.initial());

  final CorridorAlertRepository _repository;

  Future<void> load() async {
    // Rechargement : on garde le dernier résumé à l'écran, sinon la pastille
    // clignote à chaque retour sur l'onglet.
    if (!state.isLoaded) {
      emit(const CorridorAlertSummaryState.loading());
    }
    try {
      final alerts = await _repository.getMyAlerts();
      emit(CorridorAlertSummaryState.fromAlerts(alerts));
    } catch (_) {
      emit(const CorridorAlertSummaryState.hidden());
    }
  }
}
