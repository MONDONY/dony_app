import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const int kMaxCompatibleTrips = 5;

const _liveStatuses = {
  PackageRequestStatus.draft,
  PackageRequestStatus.open,
  PackageRequestStatus.negotiating,
};

/// État de « Ma demande » (écran et sheet). Remplace le `setState` de l'ancien écran.
class PackageRequestDetailCubit extends Cubit<PackageRequestDetailState> {
  PackageRequestDetailCubit(
    this._requests,
    this._announcements,
    this._bids,
    this._analytics, {
    required this.requestId,
  }) : super(const PackageRequestDetailLoading());

  final PackageRequestRepository _requests;
  final AnnouncementRepository _announcements;
  final BidRepository _bids;
  final AnalyticsService _analytics;
  final String requestId;
  int _noticeSerial = 0;

  Future<void> load() async {
    final previous = state;
    // Le back soft-delete une demande annulée : un rafraîchissement (pull-to-
    // refresh, retour de navigation) appellerait getById → 404, et afficherait
    // à tort une notice d'erreur sur un écran pourtant déjà correct. L'état
    // local annulé reste la seule vérité une fois posé.
    if (previous is PackageRequestDetailLoaded && previous.cancelledLocally) {
      return;
    }
    if (previous is! PackageRequestDetailLoaded) {
      emit(const PackageRequestDetailLoading());
    }
    try {
      final request = await _requests.getById(requestId);
      final (threads, insights) = await (_threads(), _insights(request)).wait;
      final (trips, bid) = await (
        _compatibleTrips(request, threads),
        _materializedBid(request, threads),
      ).wait;
      emit(PackageRequestDetailLoaded(
        request: request,
        threads: threads,
        insights: insights,
        compatibleTrips: trips,
        materializedBid: bid,
        invitationsSupported: insights != null,
        invitedAnnouncementIds: insights?.invitedAnnouncementIds ?? const {},
      ));
    } catch (e) {
      if (previous is PackageRequestDetailLoaded) {
        emit(previous.copyWith(
          actionInFlight: false,
          notice: _notice(RequestDetailNoticeKind.actionFailed),
        ));
      } else {
        // 404 au premier chargement (ex. lien de notification vers une
        // demande annulée/supprimée entre-temps, back soft-delete) : message
        // dédié plutôt que le générique « vérifie ta connexion ».
        emit(PackageRequestDetailError(notFound: e is DioException && e.response?.statusCode == 404));
      }
    }
  }

  Future<void> publish() => _runThenReload(
    () => _requests.publish(requestId),
    AnalyticsEvents.packageRequestPublished,
  );

  Future<void> unpublish() => _runThenReload(
    () => _requests.unpublish(requestId),
    AnalyticsEvents.packageRequestUnpublished,
  );

  /// Pas de rechargement : le back soft-delete la demande, un GET rendrait 404.
  Future<void> cancel() async {
    final s = state;
    if (s is! PackageRequestDetailLoaded || s.actionInFlight) return;
    emit(s.copyWith(actionInFlight: true));
    try {
      await _requests.cancel(requestId);
      unawaited(_analytics.logEvent(AnalyticsEvents.packageRequestCancelled));
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      emit(current.copyWith(actionInFlight: false, cancelledLocally: true));
    } catch (_) {
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      emit(current.copyWith(actionInFlight: false, notice: _notice(RequestDetailNoticeKind.actionFailed)));
    }
  }

  Future<void> invite(String announcementId) async {
    final s = state;
    if (s is! PackageRequestDetailLoaded || s.invitingAnnouncementIds.contains(announcementId)) {
      return;
    }
    emit(s.copyWith(invitingAnnouncementIds: {...s.invitingAnnouncementIds, announcementId}));
    try {
      final outcome = await _requests.inviteTraveler(requestId, announcementId);
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      final inviting = {...current.invitingAnnouncementIds}..remove(announcementId);
      switch (outcome) {
        case InvitationOutcome.notFound:
          // Insights déjà répondu (back à jour) : la route existe, c'est le
          // trajet qui a disparu entre-temps → un refus normal, on n'éteint
          // pas les invitations. Insights jamais répondu (ancien back) :
          // garder le comportement historique, masquer les invitations.
          emit(current.invitationsSupported
              ? current.copyWith(
                  invitingAnnouncementIds: inviting,
                  notice: _notice(RequestDetailNoticeKind.invitationRefused),
                )
              : current.copyWith(invitingAnnouncementIds: inviting, invitationsSupported: false));
        case InvitationOutcome.notInvitable:
          emit(current.copyWith(
            invitingAnnouncementIds: inviting,
            notice: _notice(RequestDetailNoticeKind.invitationNotInvitable),
          ));
        case InvitationOutcome.limitReached:
          emit(current.copyWith(
            invitingAnnouncementIds: inviting,
            notice: _notice(RequestDetailNoticeKind.invitationLimitReached),
          ));
        case InvitationOutcome.sent || InvitationOutcome.alreadySent:
          unawaited(_analytics.logEvent(
            AnalyticsEvents.packageRequestTravelerInvited,
            properties: {'outcome': outcome == InvitationOutcome.sent ? 'sent' : 'already_sent'},
          ));
          emit(current.copyWith(
            invitingAnnouncementIds: inviting,
            invitedAnnouncementIds: {...current.invitedAnnouncementIds, announcementId},
            notice: outcome == InvitationOutcome.sent
                ? _notice(RequestDetailNoticeKind.invitationSent)
                : null,
          ));
      }
    } on DioException catch (e) {
      // Le repository ne traduit que les statuts qu'il reconnaît (404/409/422
      // limite) : tout le reste (autre raison 422, 500…) remonte ici tel
      // quel. Un 422 non spécifique reste un refus ; le reste, un échec
      // générique.
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      emit(current.copyWith(
        invitingAnnouncementIds: {...current.invitingAnnouncementIds}..remove(announcementId),
        notice: _notice(e.response?.statusCode == 422
            ? RequestDetailNoticeKind.invitationRefused
            : RequestDetailNoticeKind.actionFailed),
      ));
    } catch (_) {
      // Exception non-Dio (ex. timeout, erreur inattendue) : ne jamais
      // laisser l'id « en cours d'invitation » orphelin.
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      emit(current.copyWith(
        invitingAnnouncementIds: {...current.invitingAnnouncementIds}..remove(announcementId),
        notice: _notice(RequestDetailNoticeKind.actionFailed),
      ));
    }
  }

  void trackShared() => unawaited(_analytics.logEvent(AnalyticsEvents.packageRequestShared));

  void trackMenuOpened() =>
      unawaited(_analytics.logEvent(AnalyticsEvents.packageRequestMenuOpened));

  void trackDuplicateStarted(String source) => unawaited(_analytics.logEvent(
    AnalyticsEvents.packageRequestDuplicateStarted,
    properties: {'source': source},
  ));

  Future<void> _runThenReload(Future<Object?> Function() action, String successEvent) async {
    final s = state;
    if (s is! PackageRequestDetailLoaded || s.actionInFlight) return;
    emit(s.copyWith(actionInFlight: true));
    try {
      await action();
      unawaited(_analytics.logEvent(successEvent));
    } catch (_) {
      final current = state;
      if (current is! PackageRequestDetailLoaded) return;
      emit(current.copyWith(actionInFlight: false, notice: _notice(RequestDetailNoticeKind.actionFailed)));
      return;
    }
    await load();
  }

  RequestDetailNotice _notice(RequestDetailNoticeKind kind) => RequestDetailNotice(kind, ++_noticeSerial);

  Future<List<NegotiationThread>> _threads() async {
    try {
      return await _requests.listThreadsForRequest(requestId);
    } catch (_) {
      return const [];
    }
  }

  Future<PackageRequestInsights?> _insights(PackageRequest request) async {
    if (!_liveStatuses.contains(request.status)) return null;
    try {
      return await _requests.getInsights(requestId);
    } catch (_) {
      return null;
    }
  }

  Future<List<AnnouncementModel>?> _compatibleTrips(
    PackageRequest request,
    List<NegotiationThread> threads,
  ) async {
    if (!_liveStatuses.contains(request.status)) return null;
    final tolerance = Duration(days: request.dateToleranceDays);
    try {
      final trips = await _announcements.searchAnnouncements(
        departureCity: request.departureCity,
        arrivalCity: request.arrivalCity,
        departureDateFrom: request.desiredDate.subtract(tolerance),
        departureDateTo: request.desiredDate.add(tolerance),
        minAvailableKg: request.weightKg,
      );
      final excluded = {request.senderId, for (final t in threads) t.travelerId};
      return trips.where((a) => !excluded.contains(a.travelerId)).take(kMaxCompatibleTrips).toList();
    } catch (_) {
      // Zone secondaire : son échec ne doit ni bloquer l'écran ni afficher « personne ».
      return null;
    }
  }

  Future<BidModel?> _materializedBid(PackageRequest request, List<NegotiationThread> threads) async {
    if (request.status != PackageRequestStatus.accepted &&
        request.status != PackageRequestStatus.completed) {
      return null;
    }
    final bidId = threads.map((t) => t.materializedBidId).whereType<String>().firstOrNull;
    if (bidId == null) return null;
    try {
      return await _bids.getBidById(bidId);
    } catch (_) {
      return null;
    }
  }
}
