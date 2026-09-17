import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/presentation/request_screen_case.dart';
import 'package:flutter/material.dart';

enum RequestPillTone { live, neutral, info, warning, success, danger }

({String label, RequestPillTone tone}) requestPillFor(
  RequestScreenCase c, {
  int count = 0,
}) => switch (c) {
  RequestScreenCase.draft => (
    label: 'Brouillon',
    tone: RequestPillTone.neutral,
  ),
  RequestScreenCase.noOffers || RequestScreenCase.noTravelers => (
    label: 'En ligne',
    tone: RequestPillTone.live,
  ),
  RequestScreenCase.offersReceived => (
    label: '$count offre${count > 1 ? 's' : ''}',
    tone: RequestPillTone.info,
  ),
  RequestScreenCase.firmCandidates => (
    label: '$count candidat${count > 1 ? 's' : ''}',
    tone: RequestPillTone.info,
  ),
  RequestScreenCase.cashCommissionPending => (
    label: 'En attente',
    tone: RequestPillTone.warning,
  ),
  RequestScreenCase.toFinalize => (
    label: 'À finaliser',
    tone: RequestPillTone.info,
  ),
  RequestScreenCase.accepted => (
    label: 'Confirmée',
    tone: RequestPillTone.success,
  ),
  RequestScreenCase.delivered => (
    label: 'Livrée',
    tone: RequestPillTone.success,
  ),
  RequestScreenCase.expired => (
    label: 'Expirée',
    tone: RequestPillTone.neutral,
  ),
  RequestScreenCase.cancelled => (
    label: 'Annulée',
    tone: RequestPillTone.danger,
  ),
};

class RequestStatusPill extends StatelessWidget {
  const RequestStatusPill({
    required this.screenCase,
    this.count = 0,
    super.key,
  });

  final RequestScreenCase screenCase;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pill = requestPillFor(screenCase, count: count);
    final (fg, bg) = switch (pill.tone) {
      RequestPillTone.live ||
      RequestPillTone.success => (cs.success, cs.successLight),
      RequestPillTone.neutral => (
        cs.onSurfaceVariant,
        cs.surfaceContainerHighest,
      ),
      RequestPillTone.info => (cs.primary, cs.primaryContainer),
      RequestPillTone.warning => (cs.warning, cs.warningLight),
      RequestPillTone.danger => (cs.error, cs.errorLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pill.tone == RequestPillTone.live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            pill.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
