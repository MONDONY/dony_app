import 'dart:async';

import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Construit l'URL publique de suivi à partir du [token].
String trackingPublicUrl(String token) {
  const base = String.fromEnvironment(
    'TRACKING_PUBLIC_URL',
    defaultValue: 'https://yadony.com/tracking',
  );
  return '$base/$token';
}

/// Ouvre la frise du colis pour l'expéditeur, avec les villes approximatives
/// du voyageur et le partage du lien de suivi quand il existe.
void openSenderTrackingTimeline(BuildContext context, BidModel bid) {
  showTrackingTimelineSheet(
    context,
    bidId: bid.id,
    departureCity: bid.departureCity,
    arrivalCity: bid.arrivalCity,
    arrivalInstructions: bid.arrivalInstructions,
    trackingNumber: bid.trackingNumber,
    bidStatus: bid.status,
    travelerTracking: bid.travelerTracking,
    onShareTracking: bid.trackingToken != null
        ? () => shareTrackingLink(
            bid,
            sharePositionOrigin: sharePositionOriginFor(context),
          )
        : null,
  );
}

/// Partage le lien de suivi du colis via le système natif.
///
/// No-op si [bid.trackingToken] est null.
Future<void> shareTrackingLink(
  BidModel bid, {
  Rect? sharePositionOrigin,
}) async {
  final token = bid.trackingToken;
  if (token == null) {
    return;
  }

  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(AnalyticsEvents.trackingLinkShared),
  );

  final url = trackingPublicUrl(token);
  final l = AppL10n.current;
  await Share.share(
    l.bidDetailShareTrackingMessage(url),
    subject: l.bidDetailTrackingShareSubject(bid.trackingNumber ?? ''),
    sharePositionOrigin: sharePositionOrigin,
  );
}
