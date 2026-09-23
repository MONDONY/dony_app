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

    final meta = [
      if (s.insights != null && s.insights!.viewCount > 0)
        '${s.insights!.viewCount} vue${s.insights!.viewCount > 1 ? 's' : ''}',
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
      ..._banner(c, focus),
      ..._zones(c, s, active, focus, trips),
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

  List<Widget> _banner(RequestScreenCase c, NegotiationThread? focus) {
    final name = focus?.travelerName ?? 'Le voyageur';
    final banner = switch (c) {
      RequestScreenCase.draft => const RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'eye-off',
        title: 'Pas encore visible',
        message:
            'Publie ta demande pour que les voyageurs puissent te proposer un prix.',
      ),
      RequestScreenCase.cashCommissionPending => RequestStateBanner(
        tone: RequestBannerTone.warning,
        icon: 'clock',
        title: '$name règle sa commission Yadony',
        message:
            'Accord en espèces trouvé. Tant que ce n\'est pas fait, tu peux encore choisir quelqu\'un d\'autre.',
      ),
      RequestScreenCase.toFinalize => const RequestStateBanner(
        tone: RequestBannerTone.info,
        icon: 'credit-card',
        title: 'Finalise pour réserver sa place',
        message:
            'Ton argent reste bloqué chez Yadony jusqu\'à la remise du colis.',
      ),
      RequestScreenCase.expired => const RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'clock',
        title: 'Date dépassée sans accord',
        message:
            'Aucun voyageur n\'a été retenu à temps. Tes infos sont gardées, il suffit de choisir de nouvelles dates.',
      ),
      RequestScreenCase.cancelled => const RequestStateBanner(
        tone: RequestBannerTone.neutral,
        icon: 'circle-x',
        title: 'Tu as annulé cette demande',
        message: 'Les voyageurs ne peuvent plus y répondre.',
      ),
      _ => null,
    };
    return [?banner];
  }

  List<Widget> _zones(
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
    final plural = trips.length > 1 ? 's' : '';

    switch (c) {
      case RequestScreenCase.draft:
        return [
          ?fold(
            '${trips.length} voyageur$plural la verr${trips.length > 1 ? 'ont' : 'a'}',
          ),
        ];
      case RequestScreenCase.noOffers:
        // `trips` fusionne `null` (recherche en échec) et `[]` (aucun
        // voyageur) : distinguer explicitement via `s.compatibleTrips` pour
        // ne pas afficher un silence identique à une vraie absence.
        if (s.compatibleTrips == null) {
          return const [
            RequestStateBanner(
              tone: RequestBannerTone.neutral,
              icon: 'wifi-off',
              title: 'Impossible de charger les voyageurs pour le moment',
              message:
                  'Réessaie plus tard, ou partage directement ta demande en attendant.',
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
          RequestSectionTitle('Offres reçues', count: sorted.length),
          for (final t in sorted) offer(t, highlighted: t.isMyTurn),
          ?fold('${trips.length} voyageur$plural sur ton axe'),
        ];
      case RequestScreenCase.firmCandidates:
        return [
          RequestSectionTitle('Voyageurs intéressés', count: active.length),
          for (final t in active) offer(t),
          const RequestStateBanner(
            tone: RequestBannerTone.warning,
            icon: 'info',
            title: 'Un seul choix',
            message: 'Les autres candidats seront déclinés automatiquement.',
          ),
          ?fold('${trips.length} voyageur$plural sur ton axe'),
        ];
      case RequestScreenCase.cashCommissionPending:
        final others = active.where((t) => t.id != focus?.id);
        return [
          RequestSectionTitle('Offres', count: active.length),
          if (focus != null) offer(focus, highlighted: true),
          for (final t in others) offer(t),
        ];
      case RequestScreenCase.toFinalize:
        return [
          const RequestSectionTitle('Offre retenue'),
          if (focus != null) offer(focus, highlighted: true),
        ];
      case RequestScreenCase.accepted:
        final bidStatus = s.materializedBid?.status;
        // Bid null (pas encore chargé/échec) : comportement inchangé, on
        // affiche la frise par défaut. Bid connu mais hors des statuts « sur
        // les rails » (CANCELLED, NO_SHOW, PARCEL_REFUSED…) : le trajet n'a
        // pas abouti, la frise de progression n'a plus de sens.
        if (bidStatus != null && !isBidOnTrack(bidStatus)) {
          return const [
            RequestStateBanner(
              tone: RequestBannerTone.neutral,
              icon: 'circle-x',
              title: 'Ce trajet n\'a pas abouti',
              message:
                  'Le voyageur n\'a pas pu assurer la livraison. Publie une demande similaire pour retrouver quelqu\'un.',
            ),
          ];
        }
        return [
          RequestProgressTimeline(
            travelerName: focus?.travelerName ?? 'ton voyageur',
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
    final name = thread.travelerName ?? 'Voyageur';
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
              ? 'réglé en main propre'
              : 'à régler en main propre à la remise')
        : (delivered ? 'versé au voyageur' : 'payé, bloqué chez Yadony');
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
