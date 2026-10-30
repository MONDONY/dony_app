import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/trip_local_time.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/mobile_money_network.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// Sections de lecture du trajet vu par son voyageur, reprises telles quelles
// du corps de détail du trajet : elles y sont rendues aujourd'hui et vont
// dans les bottom sheets des tuiles « Votre trajet » (`openTripTileSheet`).
// Chacune ne rend rien quand le trajet n'a rien à montrer pour elle (voir
// `hasContent`), règle reprise par `tripTilesFor`.

/// Lieux de remise (dépôt et récupération, libellés seuls, sans carte) puis
/// date limite de dépôt des colis, à l'heure de la ville de départ (PROD-1R).
class TripPlacesSection extends StatelessWidget {
  const TripPlacesSection({super.key, required this.trip});

  final AnnouncementModel trip;

  /// Au moins un lieu de remise ou une date limite de dépôt.
  static bool hasContent(AnnouncementModel trip) =>
      trip.pickupAddress != null ||
      trip.deliveryAddress != null ||
      trip.handoverDeadline != null;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Lieux de remise (orange) ─────────────────────────────────────────
        if (a.pickupAddress != null || a.deliveryAddress != null) ...[
          _BSectionTitle(
            label: l.listingPickupLocationsTitle,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: DonySpacing.xs),
          if (a.pickupAddress != null)
            _BSectionRow(
              iconAsset: 'upload',
              label: l.listingPickupParcelTitleShort,
              value: a.pickupAddress!.label,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
            ).animate().fadeIn(delay: 80.ms),
          if (a.deliveryAddress != null) ...[
            const SizedBox(height: DonySpacing.xs),
            _BSectionRow(
              iconAsset: 'download',
              label: l.listingDeliveryPickupTitle,
              value: a.deliveryAddress!.label,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
            ).animate().fadeIn(delay: 100.ms),
          ],
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Dépôt des colis (sky) — date limite ──────────────────────────────
        if (a.handoverDeadline != null) ...[
          _BSectionTitle(
            label: l.listingHandoverDeadlineTitle,
            color: const Color(0xFF0284C7),
          ),
          const SizedBox(height: DonySpacing.xs),
          _BSectionRow(
            iconAsset: 'calendar',
            label: l.listingDeadlineLabel,
            value: tripHandoverDeadlineLabel(l, a),
            iconBg: const Color(0xFFFEF9C3),
            iconColor: const Color(0xFFB45309),
          ).animate().fadeIn(delay: 110.ms),
          const SizedBox(height: DonySpacing.md),
        ],
      ],
    );
  }
}

/// Puces des moyens de paiement acceptés par le voyageur.
class TripPaymentsSection extends StatelessWidget {
  const TripPaymentsSection({super.key, required this.trip});

  final AnnouncementModel trip;

  /// Au moins un moyen de paiement accepté.
  static bool hasContent(AnnouncementModel trip) =>
      trip.acceptedPaymentMethods.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = trip;
    if (a.acceptedPaymentMethods.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Paiements (violet) ───────────────────────────────────────────────
        _BSectionTitle(
          label: l.listingPaymentsAcceptedTitle,
          color: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: DonySpacing.xs),
        Wrap(
          spacing: DonySpacing.xs,
          runSpacing: DonySpacing.xs,
          children: a.acceptedPaymentMethods.map((m) {
            final label = switch (m.apiValue) {
              'CASH' => '💵 ${l.paymentMethodCash}',
              'STRIPE' => '💳 ${l.paymentMethodCard}',
              'MOBILE_MONEY' => '📱 ${l.paymentMethodMobileMoney}',
              'WAVE' => '🌊 Wave', // i18n-ignore — nom de marque
              'ORANGE_MONEY' =>
                '🟠 Orange Money', // i18n-ignore — nom de marque
              _ => m.apiValue,
            };
            return _BChip(
              label: label,
              bg: const Color(0xFFEDE9FE),
              fg: const Color(0xFF6D28D9),
            );
          }).toList(),
        ),
        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

/// Réseaux mobile money acceptés (comptes actifs du voyageur dans la devise
/// du trajet, servis par le seul détail), une pastille par réseau, avec le
/// pays quand une même marque apparaît dans deux pays. Rien si le trajet
/// n'accepte pas le mobile money ou si le back ne sert aucun réseau.
class TripMobileMoneyNetworksSection extends StatelessWidget {
  const TripMobileMoneyNetworksSection({super.key, required this.trip});

  final AnnouncementModel trip;

  /// Mobile money accepté et au moins un réseau servi.
  static bool hasContent(AnnouncementModel trip) =>
      trip.acceptedPaymentMethods.contains(BidPaymentMethod.mobileMoney) &&
      trip.acceptedMobileMoneyNetworks.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!hasContent(trip)) return const SizedBox.shrink();
    final networks = trip.acceptedMobileMoneyNetworks;
    return Column(
      key: const Key('trip-mobile-money-networks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BSectionTitle(
          label: context.l10n.tripTilePaymentsNetworksTitle,
          color: const Color(0xFF7C3AED),
        ),
        const SizedBox(height: DonySpacing.xs),
        Wrap(
          spacing: DonySpacing.xs,
          runSpacing: DonySpacing.xs,
          children: [
            for (final n in networks)
              _BChip(
                label: mobileMoneyNetworkChipLabel(n, networks),
                bg: const Color(0xFFEDE9FE),
                fg: const Color(0xFF6D28D9),
              ),
          ],
        ),
        const SizedBox(height: DonySpacing.md),
      ],
    );
  }
}

/// « Ce que j'accepte », « Ce que je refuse » et « Note aux expéditeurs ».
class TripConditionsSection extends StatelessWidget {
  const TripConditionsSection({super.key, required this.trip});

  final AnnouncementModel trip;

  /// Au moins un type accepté, un type refusé ou une note aux expéditeurs.
  static bool hasContent(AnnouncementModel trip) =>
      (trip.acceptedContentTypes?.isNotEmpty ?? false) ||
      (trip.refusedTypes?.isNotEmpty ?? false) ||
      (trip.description?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final a = trip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Ce que j'accepte (vert) ──────────────────────────────────────────
        if (a.acceptedContentTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(
            label: l.listingAcceptedContentTitle,
            color: cs.success,
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.acceptedContentTypes ?? [])
                .map(
                  (t) => _BChip(
                    label: contentCategoryDisplayName(l, t),
                    bg: cs.successLight,
                    fg: cs.success,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Ce que je refuse (rouge) ─────────────────────────────────────────
        if (a.refusedTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(label: l.listingRefusedContentTitle, color: cs.error),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.refusedTypes ?? [])
                .map(
                  (t) => _BChip(
                    label: contentCategoryDisplayName(l, t),
                    bg: cs.errorContainer,
                    fg: cs.error,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Note expéditeurs ─────────────────────────────────────────────────
        if (a.description != null && a.description!.isNotEmpty) ...[
          _BSectionTitle(
            label: l.listingSenderNoteTitle,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(height: DonySpacing.xs),
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              a.description!,
              style: tt.bodySmall?.copyWith(
                color: const Color(0xFF78350F),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
        ],
      ],
    );
  }
}

/// Formate la plage de remise — toujours dates complètes début et fin.
/// Jour ET heure : le jour du départ, la limite est l'heure de départ et non
/// la fin de journée (Sentry FLUTTER-MY).
/// Heure de la ville de départ, comme le départ ; la ville est nommée quand
/// son fuseau diffère de celui du téléphone (PROD-1R).
String tripHandoverDeadlineLabel(AppLocalizations l, AnnouncementModel a) {
  final t = tripWallTime(a.handoverDeadline!, a.departureTimezone);
  return l.listingHandoverUntil(
    l.commonDateAtTime(
      DateFormat.MMMEd(l.localeName).format(t.wallClock),
      formatTripTime(l, t, city: a.departureCity),
    ),
  );
}

class _BSectionTitle extends StatelessWidget {
  final String label;
  final Color color;
  const _BSectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _BSectionRow extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;

  const _BSectionRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Center(child: DonyIcon(iconAsset, size: 16, color: iconColor)),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: tt.bodySmall?.copyWith(color: cs.onSurface)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _BChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
