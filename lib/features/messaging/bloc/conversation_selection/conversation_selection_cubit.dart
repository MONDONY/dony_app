import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Écran qui porte la sélection : liste des conversations ou archives.
enum ConversationSelectionSource { list, archives }

/// Mode sélection de la liste des conversations (FLUTTER-M4). Inactif tant
/// qu'aucune conversation n'est cochée : le mode s'ouvre par un appui long et
/// se referme quand la dernière case est décochée.
class ConversationSelectionState {
  final Set<String> selectedIds;
  const ConversationSelectionState([this.selectedIds = const {}]);

  bool get isActive => selectedIds.isNotEmpty;
  int get count => selectedIds.length;
  bool isSelected(String id) => selectedIds.contains(id);
}

/// Sélection propre à un écran (une instance par écran, `registerFactory`).
/// Les actions groupées passent par `ConversationListBloc`, qui garde les
/// listes : ce cubit ne connaît que les ids cochés.
class ConversationSelectionCubit extends Cubit<ConversationSelectionState> {
  ConversationSelectionCubit({
    AnalyticsService? analytics,
    this.source = ConversationSelectionSource.list,
  }) : _analytics = analytics,
       super(const ConversationSelectionState());

  final AnalyticsService? _analytics;
  final ConversationSelectionSource source;

  /// Appui long : ouvre le mode sur [id], ou le coche si le mode est ouvert.
  void startWith(String id) {
    if (state.isActive) {
      if (!state.isSelected(id)) emit(_with({...state.selectedIds, id}));
      return;
    }
    unawaited(
      _analytics?.logEvent(
        AnalyticsEvents.conversationSelectionStarted,
        properties: {'source': source.name},
      ),
    );
    emit(ConversationSelectionState({id}));
  }

  /// Coche ou décoche [id]. Décocher le dernier referme le mode.
  void toggle(String id) {
    final next = {...state.selectedIds};
    if (!next.remove(id)) next.add(id);
    emit(_with(next));
  }

  /// Raccourci « Sélectionner les terminées » : ajoute [ids] à la sélection.
  /// Rend le nombre d'ids réellement ajoutés.
  int addAll(Iterable<String> ids) {
    final next = {...state.selectedIds, ...ids};
    final added = next.length - state.count;
    if (added > 0) emit(_with(next));
    return added;
  }

  /// Retire de la sélection les ids qui ne sont plus affichés (conversation
  /// archivée, supprimée ou masquée entre-temps).
  void retainOnly(Set<String> visibleIds) {
    final next = state.selectedIds.where(visibleIds.contains).toSet();
    if (next.length != state.count) emit(_with(next));
  }

  /// Ferme le mode sélection.
  void clear() {
    if (state.isActive) emit(const ConversationSelectionState());
  }

  ConversationSelectionState _with(Set<String> ids) =>
      ConversationSelectionState(Set.unmodifiable(ids));
}
