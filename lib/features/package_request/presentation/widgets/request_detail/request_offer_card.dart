import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum OfferTagTone { neutral, info, success, warning }

({String label, OfferTagTone tone, String? cta}) offerTagFor(
  AppLocalizations l,
  NegotiationThread t, {
  required bool firmPrice,
}) {
  final name = t.travelerName ?? l.requestTravelerFallbackName;
  return switch (t.status) {
    NegotiationThreadStatus.awaitingTrip => (
      label: l.requestTravelerAddingTrip(name),
      tone: OfferTagTone.info,
      cta: null,
    ),
    NegotiationThreadStatus.awaitingPayment ||
    NegotiationThreadStatus.awaitingDeposit => (
      label: l.requestOfferDealFound,
      tone: OfferTagTone.success,
      cta: null,
    ),
    NegotiationThreadStatus.awaitingCommission => (
      label: l.requestOfferCashDealCommissionPending,
      tone: OfferTagTone.warning,
      cta: null,
    ),
    _ when firmPrice => (
      label: l.requestOfferAvailableForParcel,
      tone: OfferTagTone.success,
      cta: l.requestOfferChooseCta,
    ),
    _ when t.isMyTurn => (
      label: l.requestOfferYourTurn,
      tone: OfferTagTone.info,
      cta: l.requestOfferRespondCta,
    ),
    _ => (
      label: l.requestOfferWaitingFor(name),
      tone: OfferTagTone.neutral,
      cta: null,
    ),
  };
}

class RequestOfferCard extends StatelessWidget {
  const RequestOfferCard({
    required this.thread,
    required this.firmPrice,
    this.highlighted = false,
    this.onTap,
    super.key,
  });

  final NegotiationThread thread;
  final bool firmPrice;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final t = thread;
    final name = t.travelerName ?? l.tripTravelerFallbackName;
    final tag = offerTagFor(l, t, firmPrice: firmPrice);
    final price = PriceDisplay.money(
      t.grossPriceEur ?? PriceDisplay.grossFromNet(t.currentPriceEur),
      t.currency,
    );
    // Même table de tons que RequestPillTone/RequestBannerTone : couleurs
    // lues dans le ColorScheme, jamais de primitive DonyColors figée.
    final (tagBg, tagFg) = switch (tag.tone) {
      OfferTagTone.neutral => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      OfferTagTone.info => (cs.primaryContainer, cs.primary),
      OfferTagTone.success => (cs.successLight, cs.success),
      OfferTagTone.warning => (cs.warningLight, cs.warning),
    };

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DonyRadius.card),
            // Bordure surlignée : même formule que _CandidateCard
            // (my_negotiations_screen.dart) — cs.primary teinté, pas de
            // primitive DonyColors.blue200 figée en light-only.
            border: Border.all(
              color: highlighted
                  ? cs.primary.withValues(alpha: 0.30)
                  : cs.outline,
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DonyAvatar(
                    name: name,
                    imageUrl: t.travelerPhotoUrl,
                    verified: (t.travelerTripsCount ?? 0) > 0,
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (t.travelerRating != null) ...[
                              const SizedBox(width: 4),
                              DonyIcon('star', size: 13, color: cs.warning),
                              Text(
                                NumberFormat(
                                  '0.0',
                                  l.localeName,
                                ).format(t.travelerRating),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${DateFormat.MMMd(l.localeName).format(t.travelerTravelDate)} · '
                          '${l.requestAvailableKg(t.travelerAvailableKg.toStringAsFixed(0))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        l.requestOfferYouPayCaption,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tag.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tagFg,
                        ),
                      ),
                    ),
                    if (tag.cta != null)
                      Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          tag.cta!,
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
