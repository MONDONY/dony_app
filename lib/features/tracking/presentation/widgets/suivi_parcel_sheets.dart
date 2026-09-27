import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Colis lu sur un autre trajet du voyageur. Rend `true` si l'utilisateur
/// choisit de passer sur ce trajet, `false`/`null` pour scanner autre chose.
Future<bool?> showSuiviOtherTripSheet(
  BuildContext context, {
  required BidModel bid,
  required AnnouncementModel trip,
}) {
  final l = context.l10n;
  final corridor = suiviCorridor(trip);
  return DonyBottomSheet.show<bool>(
    context,
    stickyBottom: _SheetActions(
      primaryKey: const Key('suivi-switch-trip'),
      primaryLabel: l.suiviSwitchToTrip(corridor),
    ),
    child: _ParcelNotice(
      title: l.suiviOtherTripTitle,
      body: l.suiviOtherTripBody(
        suiviParcelLabel(bid),
        corridor,
        suiviShortDate(l, trip.departureDate),
      ),
    ),
  );
}

/// Colis absent des trajets du voyageur. Rend `true` pour suivre son
/// parcours, `false`/`null` pour scanner autre chose.
Future<bool?> showSuiviUnknownParcelSheet(BuildContext context) {
  final l = context.l10n;
  return DonyBottomSheet.show<bool>(
    context,
    stickyBottom: _SheetActions(
      primaryKey: const Key('suivi-follow-parcel'),
      primaryLabel: l.suiviFollowParcel,
    ),
    child: _ParcelNotice(
      title: l.suiviUnknownParcelTitle,
      body: l.suiviUnknownParcelBody,
    ),
  );
}

class _ParcelNotice extends StatelessWidget {
  const _ParcelNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: DonyColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const DonyIcon('package', size: 22, color: DonyColors.accent),
        ),
        const SizedBox(height: DonySpacing.base),
        Text(title, style: tt.headlineMedium),
        const SizedBox(height: DonySpacing.sm),
        Text(
          body,
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.primaryKey, required this.primaryLabel});

  final Key primaryKey;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: primaryKey,
          label: primaryLabel,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('suivi-scan-another'),
          label: context.l10n.suiviScanAnother,
          variant: DonyButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
