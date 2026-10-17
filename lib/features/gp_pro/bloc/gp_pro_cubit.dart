import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/app_log.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/data/repositories/gp_pro_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Demande GP Pro : statut, formulaire, justificatifs et annulation.
class GpProCubit extends Cubit<GpProCubitState> {
  GpProCubit(this._repository, this._analytics)
    : super(const GpProCubitState());

  final GpProRepository _repository;
  final AnalyticsService _analytics;

  int _counter = 0;
  bool _openedLogged = false;

  /// Codes 409 du back : une demande existe déjà, le statut local est périmé.
  static const _conflictCodes = {
    'gp-pro-application-open',
    'gp-pro-already-active',
  };

  Future<void> load() async {
    // Pas de flash de chargement lors d'un rechargement d'un écran déjà prêt.
    if (state.load != GpProLoadStatus.ready) {
      emit(state.copyWith(load: GpProLoadStatus.loading));
    }
    try {
      final status = await _repository.fetchStatus();
      emit(
        state.copyWith(
          load: GpProLoadStatus.ready,
          status: status,
          pieces: _merge(status),
          clearError: true,
        ),
      );
      if (!_openedLogged) {
        _openedLogged = true;
        unawaited(
          _analytics.logEvent(
            AnalyticsEvents.gpProApplicationOpened,
            properties: {'status': status.state.wire},
          ),
        );
      }
    } on GpProUnavailableException {
      emit(state.copyWith(load: GpProLoadStatus.unavailable));
    } catch (e) {
      AppLog.warn('gp_pro_load_failed', data: {'code': _code(e)});
      emit(state.copyWith(load: GpProLoadStatus.failure));
    }
  }

  void selectFrequency(GpProFrequency frequency) =>
      emit(state.copyWith(frequency: frequency));

  Future<void> addPiece({
    required String filePath,
    required GpProDocType type,
  }) async {
    if (!state.canAddPiece || state.submitting) return;
    final localId = 'p${_counter++}';
    String? uploadedId;
    emit(
      state.copyWith(
        clearError: true,
        pieces: [
          ...state.pieces,
          GpProPiece(localId: localId, type: type, localPath: filePath),
        ],
      ),
    );
    try {
      final doc = await _repository.uploadDocument(
        filePath: filePath,
        type: type,
      );
      uploadedId = doc.id;
      var status = state.status;
      if (status != null && status.isOpen) {
        status = await _repository.attachDocuments([doc.id]);
      }
      final pieces = _replace(
        state.pieces,
        localId,
        (p) => p.copyWith(remoteId: doc.id, status: GpProUploadStatus.ready),
      );
      emit(
        state.copyWith(
          status: status,
          pieces: status == null ? pieces : _merge(status, base: pieces),
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.gpProDocumentAdded,
          properties: {'doc_type': type.wire},
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          pieces: _replace(
            state.pieces,
            localId,
            (p) => p.copyWith(
              remoteId: uploadedId,
              status: GpProUploadStatus.failed,
            ),
          ),
          errorCode: _code(e),
        ),
      );
    }
  }

  Future<void> removePiece(String localId) async {
    final index = state.pieces.indexWhere((p) => p.localId == localId);
    if (index < 0) return;
    final piece = state.pieces[index];
    final remoteId = piece.remoteId;
    if (remoteId == null) {
      emit(state.copyWith(pieces: _without(localId)));
      return;
    }
    emit(state.copyWith(clearError: true));
    try {
      await _repository.removeDocument(remoteId);
      final status = state.status;
      final attached =
          status != null &&
          status.isOpen &&
          (status.documents?.any((d) => d.id == remoteId) ??
              piece.status == GpProUploadStatus.ready);
      emit(
        state.copyWith(
          pieces: _without(localId),
          status: attached
              ? status.copyWith(
                  documentCount: status.documentCount > 0
                      ? status.documentCount - 1
                      : 0,
                  documents: status.documents
                      ?.where((d) => d.id != remoteId)
                      .toList(),
                )
              : null,
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.gpProDocumentRemoved,
          properties: {'doc_type': piece.type.wire},
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorCode: _code(e)));
    }
  }

  Future<void> submit({String? commercialName}) async {
    final frequency = state.frequency;
    if (frequency == null || !state.canSubmit) return;
    final name = commercialName?.trim();
    final cleanName = (name == null || name.isEmpty) ? null : name;
    final ids = [
      for (final p in state.pieces)
        if (p.status == GpProUploadStatus.ready && p.remoteId != null)
          p.remoteId!,
    ];
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final status = await _repository.apply(
        frequency: frequency,
        commercialName: cleanName,
        documentIds: ids,
        source: GpProSource.profile,
      );
      emit(
        state.copyWith(
          submitting: false,
          restarting: false,
          status: status,
          pieces: _merge(status),
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.gpProApplicationSubmitted,
          properties: {
            'source': GpProSource.profile.name,
            'frequency': frequency.wire,
            'document_count': ids.length,
            'has_commercial_name': cleanName != null,
          },
        ),
      );
    } on GpProException catch (e) {
      if (e.status == 409 || _conflictCodes.contains(e.code)) {
        emit(state.copyWith(submitting: false, restarting: false));
        await load();
      } else {
        emit(state.copyWith(submitting: false, errorCode: e.code));
      }
    } catch (_) {
      emit(state.copyWith(submitting: false, errorCode: 'unknown'));
    }
  }

  Future<void> cancel() async {
    emit(state.copyWith(cancelling: true, clearError: true));
    try {
      await _repository.cancel();
      emit(state.copyWith(cancelling: false, pieces: const []));
      unawaited(_analytics.logEvent(AnalyticsEvents.gpProApplicationCancelled));
      await load();
    } on GpProException catch (e) {
      if (e.status == 404) {
        emit(state.copyWith(cancelling: false));
        await load();
      } else {
        emit(state.copyWith(cancelling: false, errorCode: e.code));
      }
    } catch (_) {
      emit(state.copyWith(cancelling: false, errorCode: 'unknown'));
    }
  }

  /// « Refaire une demande » après un refus ou une révocation.
  void restart() {
    if (!(state.status?.isOpen ?? false)) {
      // Un document non rattaché compte dans la limite du back pendant 24 h :
      // on le supprime au mieux, sans bloquer ni signaler d'erreur.
      for (final p in state.pieces) {
        final id = p.remoteId;
        if (id != null) unawaited(_discard(id));
      }
    }
    emit(
      GpProCubitState(load: state.load, status: state.status, restarting: true),
    );
  }

  Future<void> _discard(String id) async {
    try {
      await _repository.removeDocument(id);
    } catch (_) {}
  }

  /// Pièces affichées reconstruites depuis `status.documents`. Les pièces
  /// locales en cours ou en échec sont conservées ; sans liste (back plus
  /// ancien), les pièces locales restent telles quelles.
  List<GpProPiece> _merge(GpProStatus status, {List<GpProPiece>? base}) {
    final current = base ?? state.pieces;
    final docs = status.documents;
    if (docs == null) return current;
    final byRemote = {
      for (final p in current)
        if (p.remoteId != null) p.remoteId!: p,
    };
    final fromServer = [
      for (final d in docs)
        byRemote[d.id] ??
            GpProPiece(
              localId: 'r-${d.id}',
              type: d.type,
              remoteId: d.id,
              status: GpProUploadStatus.ready,
            ),
    ];
    final serverIds = {for (final d in docs) d.id};
    final extras = [
      for (final p in current)
        // Prêtes mais pas encore rattachées (aucune demande ouverte) : gardées.
        if (p.remoteId == null ||
            p.status == GpProUploadStatus.failed ||
            (!serverIds.contains(p.remoteId) && !status.isOpen))
          p,
    ];
    return [...fromServer, ...extras];
  }

  List<GpProPiece> _replace(
    List<GpProPiece> pieces,
    String localId,
    GpProPiece Function(GpProPiece) change,
  ) => [for (final p in pieces) p.localId == localId ? change(p) : p];

  List<GpProPiece> _without(String localId) =>
      state.pieces.where((p) => p.localId != localId).toList();

  String _code(Object e) => e is GpProException ? e.code : 'unknown';
}
