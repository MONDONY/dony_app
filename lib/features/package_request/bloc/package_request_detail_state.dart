import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:equatable/equatable.dart';

enum RequestDetailNoticeKind {
  actionFailed,
  invitationSent,
  invitationRefused,
  invitationNotInvitable,
  invitationLimitReached,
}

/// Message ponctuel (snackbar). `serial` distingue deux notices identiques successives.
class RequestDetailNotice extends Equatable {
  const RequestDetailNotice(this.kind, this.serial);
  final RequestDetailNoticeKind kind;
  final int serial;

  @override
  List<Object?> get props => [kind, serial];
}

sealed class PackageRequestDetailState extends Equatable {
  const PackageRequestDetailState();

  @override
  List<Object?> get props => const [];
}

final class PackageRequestDetailLoading extends PackageRequestDetailState {
  const PackageRequestDetailLoading();
}

final class PackageRequestDetailError extends PackageRequestDetailState {
  const PackageRequestDetailError({this.notFound = false});

  /// 404 sur le chargement initial : la demande a été annulée/supprimée
  /// (soft-delete) entre le moment où le lien a été ouvert (ex. notification)
  /// et l'affichage de l'écran. Distinct d'un échec réseau générique.
  final bool notFound;

  @override
  List<Object?> get props => [notFound];
}

final class PackageRequestDetailLoaded extends PackageRequestDetailState {
  const PackageRequestDetailLoaded({
    required this.request,
    required this.threads,
    this.insights,
    this.compatibleTrips,
    this.materializedBid,
    this.cancelledLocally = false,
    this.actionInFlight = false,
    this.invitationsSupported = false,
    this.invitedAnnouncementIds = const {},
    this.invitingAnnouncementIds = const {},
    this.notice,
  });

  final PackageRequest request;
  final List<NegotiationThread> threads;
  final PackageRequestInsights? insights;

  /// `null` = non chargée (statut qui n'en a pas besoin, ou échec) ; vide = personne.
  final List<AnnouncementModel>? compatibleTrips;
  final BidModel? materializedBid;
  final bool cancelledLocally;
  final bool actionInFlight;
  final bool invitationsSupported;
  final Set<String> invitedAnnouncementIds;
  final Set<String> invitingAnnouncementIds;
  final RequestDetailNotice? notice;

  RequestScreenCase get screenCase => resolveRequestScreenCase(
    request: request,
    threads: threads,
    cancelledLocally: cancelledLocally,
    materializedBid: materializedBid,
    compatibleTrips: compatibleTrips,
  );

  RequestScreenActions get actions =>
      requestActionsFor(screenCase, request: request, threads: threads, materializedBid: materializedBid);

  PackageRequestDetailLoaded copyWith({
    bool? cancelledLocally,
    bool? actionInFlight,
    bool? invitationsSupported,
    Set<String>? invitedAnnouncementIds,
    Set<String>? invitingAnnouncementIds,
    RequestDetailNotice? notice,
  }) => PackageRequestDetailLoaded(
    request: request,
    threads: threads,
    insights: insights,
    compatibleTrips: compatibleTrips,
    materializedBid: materializedBid,
    cancelledLocally: cancelledLocally ?? this.cancelledLocally,
    actionInFlight: actionInFlight ?? this.actionInFlight,
    invitationsSupported: invitationsSupported ?? this.invitationsSupported,
    invitedAnnouncementIds: invitedAnnouncementIds ?? this.invitedAnnouncementIds,
    invitingAnnouncementIds:
        invitingAnnouncementIds ?? this.invitingAnnouncementIds,
    notice: notice ?? this.notice,
  );

  @override
  List<Object?> get props => [
    request, threads, insights, compatibleTrips, materializedBid, cancelledLocally,
    actionInFlight, invitationsSupported, invitedAnnouncementIds, invitingAnnouncementIds, notice,
  ];
}
