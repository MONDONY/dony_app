import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:dony/features/package_request/presentation/request_time_label.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_offer_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_progress_timeline.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_state_banner.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_status_pill.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_ticket_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_travelers_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Gestes de la vue, câblés par l'écran (navigation, sheets, cubit).
class RequestDetailCallbacks {
  const RequestDetailCallbacks({
    required this.onOpenThread,
    required this.onOpenTrip,
    required this.onInvite,
    required this.onCreateAlert,
    required this.onWidenDates,
  });

  factory RequestDetailCallbacks.noop() => RequestDetailCallbacks(
    onOpenThread: (_) {},
    onOpenTrip: (_) {},
    onInvite: (_) {},
    onCreateAlert: () {},
    onWidenDates: () {},
  );

  final void Function(String threadId) onOpenThread;
  final void Function(AnnouncementModel trip) onOpenTrip;
  final void Function(String announcementId) onInvite;
  final VoidCallback onCreateAlert;
  final VoidCallback onWidenDates;

  RequestDetailCallbacks copyWith({
    void Function(String threadId)? onOpenThread,
  }) => RequestDetailCallbacks(
    onOpenThread: onOpenThread ?? this.onOpenThread,
    onOpenTrip: onOpenTrip,
    onInvite: onInvite,
    onCreateAlert: onCreateAlert,
    onWidenDates: onWidenDates,
  );
}

class RequestDetailView extends StatelessWidget {
  const RequestDetailView({
    required this.state,
    required this.callbacks,
    this.now,
    super.key,
  });

  final PackageRequestDetailLoaded state;
  final RequestDetailCallbacks callbacks;

  /// Injectable pour les tests ; `DateTime.now()` sinon.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final c = s.screenCase;
    final r = s.request;
    final active = s.threads.where((t) => t.status.isActive).toList();
    final focus = focusThreadFor(c, s.threads);
    final trips = s.compatibleTrips ?? const <AnnouncementModel>[];

    final l = context.l10n;
    final meta = [
      if (s.insights != null && s.insights!.viewCount > 0)
        l.requestDetailViews(s.insights!.viewCount),
      requestTimeLabel(
        r.createdAt,
        now: now ?? DateTime.now(),
        l10n: context.l10n,
        verb: c == RequestScreenCase.draft
            ? RequestTimeVerb.created
            : RequestTimeVerb.posted,
      ),
    ].join(' · ');

    final children = <Widget>[
      RequestTicketCard(
        request: r,
        statusPill: RequestStatusPill(screenCase: c, count: active.length),
        metaLabel: meta,
        dimmed:
            c == RequestScreenCase.expired || c == RequestScreenCase.cancelled,
        footer:
            (c == RequestScreenCase.accepted ||
                    c == RequestScreenCase.delivered) &&
                focus != null
            ? _TravelerStub(
                thread: focus,
                delivered: c == RequestScreenCase.delivered,
              )
            : null,
      ),
      ..._banner(l, c, focus),
      ..._zones(l, c, s, active, focus, trips),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, w) in children.indexed) ...[
          if (i > 0) const SizedBox(height: DonySpacing.md),
          w,
        ],
      ],
    );
  }

  List<Widget> _banner(
    AppLocalizations l,
    RequestScreenCase c,
    NegotiationThread? focus,
  ) {
    final name = focus?.travelerName ?? l.requestTravelerFallbackName;
    final banner = switch (c) {
      RequestScreenCase.draft => RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'eye-off',
        title: l.requestDetailNotVisibleTitle,
        message: l.requestDetailNotVisibleMessage,
      ),
      RequestScreenCase.cashCommissionPending => RequestStateBanner(
        tone: RequestBannerTone.warning,
        icon: 'clock',
        title: l.requestDetailCashCommissionTitle(name),
        message: l.requestDetailCashCommissionMessage,
      ),
      RequestScreenCase.toFinalize => RequestStateBanner(
        tone: RequestBannerTone.info,
        icon: 'credit-card',
        title: l.requestDetailFinalizeTitle,
        message: l.requestDetailFinalizeMessage,
      ),
      RequestScreenCase.expired => RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'clock',
        title: l.requestDetailExpiredTitle,
        message: l.requestDetailExpiredMessage,
      ),
      RequestScreenCase.cancelled => RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'circle-x',
        title: l.requestDetailCancelledTitle,
        message: l.requestDetailCancelledMessage,
      ),
      _ => null,
    };
    return [?banner];
  }

  List<Widget> _zones(
    AppLocalizations l,
    RequestScreenCase c,
    PackageRequestDetailLoaded s,
    List<NegotiationThread> active,
    NegotiationThread? focus,
    List<AnnouncementModel> trips,
  ) {
    final r = s.request;
    Widget offer(NegotiationThread t, {bool highlighted = false}) =>
        RequestOfferCard(
          thread: t,
          firmPrice: !r.negotiable,
          highlighted: highlighted,
          onTap: () => callbacks.onOpenThread(t.id),
        );
    Widget? fold(String label) =>
        trips.isEmpty ? null : RequestTravelersFold(trips: trips, label: label);

    switch (c) {
      case RequestScreenCase.draft:
        return [?fold(l.requestDetailTravelersWillSee(trips.length))];
      case RequestScreenCase.noOffers:
        // `trips` fusionne `null` (recherche en échec) et `[]` (aucun
        // voyageur) : distinguer explicitement via `s.compatibleTrips` pour
        // ne pas afficher un silence identique à une vraie absence.
        if (s.compatibleTrips == null) {
          return [
            RequestStateBanner(
              tone: RequestBannerTone.neutral,
              icon: 'wifi-off',
              title: l.requestDetailNoSearchTitle,
              message: l.requestDetailNoSearchMessage,
            ),
          ];
        }
        if (trips.isEmpty) return const [];
        return [
          RequestTravelersList(
            trips: trips,
            requestWeightKg: r.weightKg,
            inviteStateFor: (id) => !s.invitationsSupported
                ? TravelerInviteState.hidden
                : s.invitingAnnouncementIds.contains(id)
                ? TravelerInviteState.sending
                : s.invitedAnnouncementIds.contains(id)
                ? TravelerInviteState.invited
                : TravelerInviteState.idle,
            onInvite: callbacks.onInvite,
            onOpenTrip: callbacks.onOpenTrip,
          ),
        ];
      case RequestScreenCase.noTravelers:
        return [
          RequestNoTravelersEmpty(
            corridor: '${r.departureCity} → ${r.arrivalCity}',
            onCreateAlert: callbacks.onCreateAlert,
            onWidenDates: callbacks.onWidenDates,
          ),
        ];
      case RequestScreenCase.offersReceived:
        final sorted = [...active]
          ..sort((a, b) => (b.isMyTurn ? 1 : 0) - (a.isMyTurn ? 1 : 0));
        return [
          RequestSectionTitle(
            l.requestDetailOffersReceivedTitle,
            count: sorted.length,
          ),
          for (final t in sorted) offer(t, highlighted: t.isMyTurn),
          ?fold(l.requestDetailTravelersOnRouteCount(trips.length)),
        ];
      case RequestScreenCase.firmCandidates:
        return [
          RequestSectionTitle(
            l.requestDetailInterestedTravelersTitle,
            count: active.length,
          ),
          for (final t in active) offer(t),
          RequestStateBanner(
            tone: RequestBannerTone.warning,
            icon: 'info',
            title: l.requestDetailSingleChoiceTitle,
            message: l.requestDetailSingleChoiceMessage,
          ),
          ?fold(l.requestDetailTravelersOnRouteCount(trips.length)),
        ];
      case RequestScreenCase.cashCommissionPending:
        final others = active.where((t) => t.id != focus?.id);
        return [
          RequestSectionTitle(l.requestDetailOffersTitle, count: active.length),
          if (focus != null) offer(focus, highlighted: true),
          for (final t in others) offer(t),
        ];
      case RequestScreenCase.toFinalize:
        return [
          RequestSectionTitle(l.requestDetailSelectedOfferTitle),
          if (focus != null) offer(focus, highlighted: true),
        ];
      case RequestScreenCase.accepted:
        final bidStatus = s.materializedBid?.status;
        // Bid null (pas encore chargé/échec) : comportement inchangé, on
        // affiche la frise par défaut. Bid connu mais hors des statuts « sur
        // les rails » (CANCELLED, NO_SHOW, PARCEL_REFUSED…) : le trajet n'a
        // pas abouti, la frise de progression n'a plus de sens.
        if (bidStatus != null && !isBidOnTrack(bidStatus)) {
          return [
            RequestStateBanner(
              tone: RequestBannerTone.neutral,
              icon: 'circle-x',
              title: l.requestDetailTripNotCompletedTitle,
              message: l.requestDetailTripNotCompletedMessage,
            ),
          ];
        }
        return [
          RequestProgressTimeline(
            travelerName:
                focus?.travelerName ?? l.requestDetailYourTravelerFallback,
            arrivalCity: r.arrivalCity,
            currentStep: progressStepForBid(s.materializedBid?.status),
          ),
        ];
      case RequestScreenCase.delivered:
      case RequestScreenCase.expired:
      case RequestScreenCase.cancelled:
        return const [];
    }
  }
}

class _TravelerStub extends StatelessWidget {
  const _TravelerStub({required this.thread, required this.delivered});
  final NegotiationThread thread;
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final name = thread.travelerName ?? l.tripTravelerFallbackName;
    final price = PriceDisplay.money(
      thread.grossPriceEur ?? PriceDisplay.grossFromNet(thread.currentPriceEur),
      thread.currency,
    );
    // Espèces : aucun argent ne transite par Yadony, le libellé « bloqué chez
    // Yadony »/« versé au voyageur » serait faux. Cf. le vocabulaire déjà
    // établi (payment_recap_bottom_sheet.dart) : « en main propre ».
    final isCash = thread.paymentMethod == PaymentMethod.cash;
    final statusLabel = isCash
        ? (delivered
              ? l.requestDetailStubCashPaid
              : l.requestDetailStubCashPending)
        : (delivered
              ? l.requestDetailStubPaidToTraveler
              : l.requestDetailStubHeldByYadony);
    return Container(
      key: const Key('request-ticket-traveler-stub'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Row(
        children: [
          DonyAvatar(name: name, imageUrl: thread.travelerPhotoUrl),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
