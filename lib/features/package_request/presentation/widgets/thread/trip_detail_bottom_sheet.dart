import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/refuse_trip_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Bottom sheet affichant le détail du trajet lié à une négociation, sous
/// forme de timeline départ → arrivée.
///
/// Côté expéditeur ([isSender] == true), un bouton destructif « Refuser le
/// trajet » est affiché : il ferme ce sheet et ouvre [RefuseTripBottomSheet].
class TripDetailBottomSheet {
  const TripDetailBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required LinkedTripSummary trip,
    required bool isSender,
    required NegotiationBloc bloc,
    required String threadId,
  }) {
    return DonyBottomSheet.show<void>(
      context,
      title: 'Trajet lié',
      child: _TripDetailContent(trip: trip),
      stickyBottom: isSender
          ? DonyButton(
              label: 'Refuser le trajet',
              variant: DonyButtonVariant.destructive,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                RefuseTripBottomSheet.show(
                  context,
                  bloc: bloc,
                  threadId: threadId,
                );
              },
            )
          : null,
    );
  }
}

class _TripDetailContent extends StatelessWidget {
  const _TripDetailContent({required this.trip});
  final LinkedTripSummary trip;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (trip.transportMode != null)
        _Chip(
          text: '${_transportIcon(trip.transportMode)} '
              '${_transportLabel(trip.transportMode)}',
          highlighted: true,
        ),
      if (trip.availableKg != null)
        _Chip(text: '⚖️ ${trip.availableKg} kg dispo'),
      if (trip.departureDate != null)
        _Chip(text: '📅 ${_formatDate(trip.departureDate!)}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (chips.isNotEmpty) ...[
          Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.sm,
            children: chips,
          ),
          const SizedBox(height: DonySpacing.lg),
        ],
        _Timeline(trip: trip),
        if (trip.description != null && trip.description!.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: DonyColors.sand100,
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE DU VOYAGEUR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kTextSecondary,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  trip.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DonyColors.textPrimary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _transportIcon(String? mode) => switch (mode) {
        'PLANE' => '✈️',
        'TRAIN' => '🚄',
        'CAR' => '🚗',
        'BUS' => '🚌',
        'BOAT' => '🚢',
        _ => '📦',
      };

  static String _transportLabel(String? mode) =>
      transportModeFromWire(mode)?.label ?? 'Transport';

  static String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        '', 'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
        'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.highlighted = false});
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? DonyColors.blue50 : DonyColors.sand100,
        borderRadius: BorderRadius.circular(DonyRadius.xl),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlighted ? DonyColors.primary : kTextSecondary,
            ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.trip});
  final LinkedTripSummary trip;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: DonyColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(width: 2, color: DonyColors.neutral200),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DonyColors.primary, width: 3),
                ),
              ),
            ],
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Endpoint(
                  label: trip.departureTime != null
                      ? 'DÉPART · ${trip.departureTime}'
                      : 'DÉPART',
                  city: trip.departureCity ?? '—',
                  address: trip.pickupAddressLabel,
                  addressIcon: '📍',
                ),
                const SizedBox(height: DonySpacing.lg),
                _Endpoint(
                  label: 'ARRIVÉE',
                  city: trip.arrivalCity ?? '—',
                  address: trip.deliveryAddressLabel,
                  addressIcon: '🏠',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.city,
    required this.addressIcon,
    this.address,
  });
  final String label;
  final String city;
  final String addressIcon;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: kTextSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          city,
          style: tt.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DonyColors.textPrimary,
          ),
        ),
        if (address != null && address!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '$addressIcon $address',
            style: tt.bodyMedium?.copyWith(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
