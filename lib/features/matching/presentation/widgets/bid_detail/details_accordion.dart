import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Accordéon « Plus de détails » — tout ce que l'app sait de la demande :
///   1. DEMANDE (référence, dates d'envoi et de mise à jour, paiement, promo)
///   2. DÉPÔT DU COLIS (lieu ouvrable dans la carte, date limite, remise)
///   3. RÉCUPÉRATION À L'ARRIVÉE (lieu ouvrable dans la carte, instructions)
///   4. TRAJET (itinéraire, départ, arrivée, tarif)
///   5. LIEN DE SUIVI (si autorisé et trackingToken != null)
///   6. RESPONSABILITÉ LÉGALE
///
/// NOTE : ce widget est un [StatefulWidget] pour gérer l'état UI `_open`
/// (pattern AnimatedSize standard). Ce setState local ne gère que l'ouverture/
/// fermeture de l'accordéon — aucun état métier.
class DetailsAccordion extends StatefulWidget {
  final BidModel bid;
  final bool showTrackingLink;

  const DetailsAccordion({
    super.key,
    required this.bid,
    this.showTrackingLink = true,
  });

  @override
  State<DetailsAccordion> createState() => _DetailsAccordionState();
}

class _DetailsAccordionState extends State<DetailsAccordion> {
  bool _open = false;

  BidModel get bid => widget.bid;

  String _formatHandoverDate(BuildContext context, DateTime? d) {
    if (d == null) {
      return '-';
    }
    return DateFormat.yMd(context.l10n.localeName).format(d.toLocal());
  }

  // fr : garde le motif fixe d'origine ('EEE dd MMM yyyy') — le squelette
  // yMMMEd rend « mar. 6 oct. 2026 » (sans le zéro de tête du jour) au lieu de
  // « mar. 06 oct. 2026 ». en : squelette yMMMEd, seule langue concernée par
  // ce motif jusqu'ici.
  String _formatDepartureDate(BuildContext context, DateTime? d) {
    if (d == null) {
      return '-';
    }
    final locale = context.l10n.localeName;
    if (locale == 'fr') {
      return DateFormat('EEE dd MMM yyyy', locale).format(d.toLocal());
    }
    return DateFormat.yMMMEd(locale).format(d.toLocal());
  }

  String _formatDateTime(BuildContext context, DateTime d) {
    final locale = context.l10n.localeName;
    return '${DateFormat.yMd(locale).format(d.toLocal())} '
        '${DateFormat.Hm(locale).format(d.toLocal())}';
  }

  /// Numéro de suivi quand il est servi (expéditeur, ou voyageur après la
  /// remise), sinon le début de l'identifiant de la demande.
  String get _reference =>
      bid.trackingNumber ??
      bid.id.substring(0, bid.id.length < 8 ? bid.id.length : 8).toUpperCase();

  String get _route {
    final from = bid.departureCity;
    final to = bid.arrivalCity;
    if (from == null && to == null) return '-';
    return '${from ?? '-'} → ${to ?? '-'}';
  }

  /// Heure d'arrivée, précédée de sa date quand le trajet arrive un autre
  /// jour que le départ (FLUTTER-4E).
  String _arrivalValue(BuildContext context) {
    final time = _hhmm(bid.arrivalTime!);
    final date = bid.arrivalDate;
    if (date == null ||
        (bid.departureDate != null &&
            DateUtils.isSameDay(date, bid.departureDate))) {
      return time;
    }
    return context.l10n.tripArrivalOnDateAtTime(
      DateFormat.MMMEd(context.l10n.localeName).format(date),
      time,
    );
  }

  bool get _hasInstructions =>
      bid.arrivalInstructions != null &&
      bid.arrivalInstructions!.trim().isNotEmpty;

  /// « 14:30:00 » (LocalTime du back) → « 14:30 ».
  static String _hhmm(String time) =>
      time.length >= 5 ? time.substring(0, 5) : time;

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: _open
                ? const BorderRadius.vertical(
                    top: Radius.circular(DonyRadius.card),
                  )
                : BorderRadius.circular(DonyRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.bidDetailMoreDetails,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: DonyIcon('chevron-down', color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.base,
                      0,
                      DonySpacing.base,
                      DonySpacing.base,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section — DEMANDE
                        _SectionLabel(label: l.bidDetailSectionRequest),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          // Numéro de suivi quand il est servi, jamais
                          // « Référence » : vu des deux côtés, il passait pour
                          // un code (FLUTTER-J2).
                          label: bid.trackingNumber != null
                              ? l.bidDetailTrackingNumberLabel
                              : l.bidDetailReferenceLabel,
                          value: _reference,
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: l.bidDetailSentAtLabel,
                          value: _formatDateTime(context, bid.createdAt),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: l.bidDetailUpdatedAtLabel,
                          value: _formatDateTime(context, bid.updatedAt),
                        ),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: l.bidDetailPaymentMethodLabel,
                          value: l.bidDetailPaymentMethodValue(
                            bid.paymentMethod.name,
                          ),
                        ),
                        if (bid.promoCode != null &&
                            bid.promoCode!.isNotEmpty) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: l.bidDetailPromoCodeLabel,
                            value: bid.promoCode!,
                          ),
                        ],
                        const SizedBox(height: DonySpacing.md),
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section — DÉPÔT DU COLIS
                        _SectionLabel(label: l.bidDetailSectionDropoff),
                        const SizedBox(height: DonySpacing.sm),
                        if (bid.handoverAddress != null)
                          _AddressInfoRow(
                            key: const Key('details-handover-address'),
                            label: l.bidDetailLocationLabel,
                            address: bid.handoverAddress!,
                          )
                        else
                          InfoRow(
                            label: l.bidDetailLocationLabel,
                            value: bid.handoverLocation ?? '-',
                          ),
                        if (bid.handoverDeadline != null) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: l.listingDeadlineLabel,
                            value: _formatHandoverDate(
                              context,
                              bid.handoverDeadline,
                            ),
                          ),
                        ],
                        const SizedBox(height: DonySpacing.sm),
                        // « Présence confirmée » n'est pertinent qu'avant la
                        // remise (phase ACCEPTED). Une fois le colis remis, on
                        // affiche l'état réel plutôt qu'un trompeur « Non encore ».
                        InfoRow(
                          label: kParcelHandedOverStatuses.contains(bid.status)
                              ? l.bidDetailHandoverStatusLabel
                              : l.bidDetailPresenceConfirmedLabel,
                          value: kParcelHandedOverStatuses.contains(bid.status)
                              ? l.bidDetailParcelHandedOverValue
                              : (bid.voyageurConfirmed
                                    ? l.bidDetailYesValue
                                    : l.bidDetailNotYetValue),
                        ),
                        if (bid.deliveryAddress != null ||
                            _hasInstructions) ...[
                          const SizedBox(height: DonySpacing.md),
                          Divider(color: cs.outline, height: 1),
                          const SizedBox(height: DonySpacing.md),
                          // Section — RÉCUPÉRATION À L'ARRIVÉE
                          _SectionLabel(label: l.bidDetailSectionPickup),
                          if (bid.deliveryAddress != null) ...[
                            const SizedBox(height: DonySpacing.sm),
                            _AddressInfoRow(
                              key: const Key('details-delivery-address'),
                              label: l.bidDetailLocationLabel,
                              address: bid.deliveryAddress!,
                            ),
                          ],
                          if (_hasInstructions) ...[
                            const SizedBox(height: DonySpacing.sm),
                            InfoRow(
                              label: l.bidDetailPickupInstructionsLabel,
                              value: bid.arrivalInstructions!.trim(),
                            ),
                          ],
                        ],
                        const SizedBox(height: DonySpacing.md),
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section — TRAJET
                        _SectionLabel(label: l.listingHeroTripLabelCaps),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(label: l.bidDetailRouteLabel, value: _route),
                        const SizedBox(height: DonySpacing.sm),
                        InfoRow(
                          label: l.tripPublishDepartureDateLabel,
                          value: _formatDepartureDate(
                            context,
                            bid.departureDate,
                          ),
                        ),
                        if (bid.departureTime != null &&
                            bid.departureTime!.isNotEmpty) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: l.tripPublishDepartureTimeLabel,
                            value: _hhmm(bid.departureTime!),
                          ),
                        ],
                        if (bid.arrivalTime != null &&
                            bid.arrivalTime!.isNotEmpty) ...[
                          const SizedBox(height: DonySpacing.sm),
                          InfoRow(
                            label: l.bidDetailArrivalTimeLabel,
                            value: _arrivalValue(context),
                          ),
                        ],
                        if (bid.senderPricePerKg != null &&
                            bid.senderPricePerKg! > 0) ...[
                          const SizedBox(height: DonySpacing.sm),
                          // Tarif BRUT affiché à l'expéditeur (jamais le net).
                          InfoRow(
                            label: l.bidDetailPricePerKgLabel,
                            value: formatPriceIn(
                              bid.senderPricePerKg!,
                              bid.currency,
                            ),
                          ),
                        ],
                        // Section — LIEN DE SUIVI (conditionnel)
                        if (widget.showTrackingLink &&
                            bid.trackingToken != null) ...[
                          const SizedBox(height: DonySpacing.md),
                          Divider(color: cs.outline, height: 1),
                          const SizedBox(height: DonySpacing.md),
                          _SectionLabel(label: l.bidDetailSectionTrackingLink),
                          const SizedBox(height: DonySpacing.sm),
                          _TrackingUrlRow(bid: bid),
                        ],
                        const SizedBox(height: DonySpacing.md),
                        Divider(color: cs.outline, height: 1),
                        const SizedBox(height: DonySpacing.md),
                        // Section — RESPONSABILITÉ LÉGALE
                        _SectionLabel(label: l.bidDetailSectionLegal),
                        const SizedBox(height: DonySpacing.sm),
                        _DisclaimerRow(bid: bid),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Adresse ouvrable dans la carte ───────────────────────────────────────────

/// [InfoRow] dont la valeur est une adresse : tap = ouvre l'app de carte
/// native, appui long = copie.
class _AddressInfoRow extends StatelessWidget {
  final String label;
  final AddressData address;
  const _AddressInfoRow({
    super.key,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => openAddressInMaps(address),
      onLongPress: () => copyAddress(context, address),
      borderRadius: BorderRadius.circular(DonyRadius.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              address.label,
              style: tt.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: DonySpacing.xs),
          DonyIcon('map-pin', size: 14, color: cs.primary),
        ],
      ),
    );
  }
}

// ── Tracking URL row ──────────────────────────────────────────────────────────

class _TrackingUrlRow extends StatelessWidget {
  final BidModel bid;
  const _TrackingUrlRow({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final url = trackingPublicUrl(bid.trackingToken!);

    return Row(
      children: [
        DonyIcon('link', color: cs.primary, size: 16),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            url,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: DonyIcon('copy', size: 16, color: cs.primary),
          tooltip: context.l10n.bidDetailCopyTrackingLinkButton,
          color: cs.primary,
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: url)));
            DonySnackbar.show(
              context,
              message: context.l10n.bidDetailTrackingLinkCopiedMessage,
              type: DonySnackbarType.success,
            );
          },
        ),
      ],
    );
  }
}

// ── Disclaimer row ────────────────────────────────────────────────────────────

class _DisclaimerRow extends StatelessWidget {
  final BidModel bid;
  const _DisclaimerRow({required this.bid});

  String _disclaimerLabel(BuildContext context) {
    final l = context.l10n;
    final signed = bid.disclaimerSignedAt;
    if (signed == null) {
      return l.bidDetailDisclaimerSignedNoDate;
    }
    final locale = l.localeName;
    try {
      final local = signed.toLocal();
      final dateTime = l.commonDateAtTime(
        DateFormat.yMd(locale).format(local),
        DateFormat.jm(locale).format(local),
      );
      return l.bidCreateDisclaimerSigned(dateTime);
    } catch (_) {
      final local = signed.toLocal();
      return l.bidDetailDisclaimerSignedCompact(
        DateFormat.yMd(locale).format(local),
        DateFormat.jm(locale).format(local),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        DonyIcon('badge-check', color: cs.success, size: 20),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Text(
            _disclaimerLabel(context),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
