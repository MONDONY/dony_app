import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/form_draft_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Geste qui a enregistré ou supprimé un brouillon (propriété `source`).
enum FormDraftSource {
  /// Dialogue de sortie du formulaire.
  exitDialog('exit_dialog'),

  /// Bouton « Brouillon » de la barre du formulaire.
  appBar('app_bar');

  const FormDraftSource(this.wire);

  final String wire;
}

/// Dernière opération réussie sur le brouillon.
enum FormDraftStatus { idle, saved, discarded }

/// Brouillon local d'un formulaire de publication (trajet ou demande d'envoi).
///
/// Ne connaît pas le contenu du formulaire : l'écran lui donne une carte de
/// champs à garder. La reprise se décide avant le formulaire, dans la feuille
/// des brouillons de l'écran d'introduction, qui lui transmet le brouillon.
class FormDraftCubit extends Cubit<FormDraftStatus> {
  FormDraftCubit(this._store, this._analytics, this.kind)
    : super(FormDraftStatus.idle);

  final FormDraftStore _store;
  final AnalyticsService _analytics;
  final FormDraftKind kind;

  /// Enregistre la saisie. Rend `false` si le trousseau a refusé l'écriture.
  Future<bool> save(
    Map<String, dynamic> data, {
    required FormDraftSource source,
  }) async {
    final saved = await _store.save(kind, data);
    if (saved) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.formDraftSaved,
          properties: {
            'kind': kind.wire,
            'step': (data['step'] as num?)?.toInt() ?? 0,
            'source': source.wire,
          },
        ),
      );
      if (!isClosed) emit(FormDraftStatus.saved);
    }
    return saved;
  }

  /// L'utilisateur quitte sans garder sa saisie : l'ancien brouillon
  /// disparaît aussi, sans quoi il réapparaîtrait à la prochaine publication.
  Future<void> discard({required FormDraftSource source}) async {
    await _store.delete(kind);
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.formDraftDiscarded,
        properties: {'kind': kind.wire, 'source': source.wire},
      ),
    );
    if (!isClosed) emit(FormDraftStatus.discarded);
  }

  /// Publication (ou brouillon serveur) réussie : la saisie locale est
  /// devenue inutile.
  Future<void> clear() => _store.delete(kind);
}
