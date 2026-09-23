import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_methods_chips.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/city_code.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_photo_viewer.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Billet blanc de « Ma demande » (option 2) : route, perforation, photo, prix,
/// quartiers et moyens de paiement. [footer] accueille le talon voyageur.
class RequestTicketCard extends StatelessWidget {
  const RequestTicketCard({
    required this.request,
    required this.statusPill,
    required this.metaLabel,
    this.dimmed = false,
    this.footer,
    super.key,
  });

  final PackageRequest request;
  final Widget statusPill;
  final String metaLabel;
  final bool dimmed;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = request;
    final hasFooterDetails =
        r.acceptedPaymentMethods.isNotEmpty ||
        r.pickupNeighborhood != null ||
        r.deliveryNeighborhood != null;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Opacity(
        opacity: dimmed ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.base,
                DonySpacing.base,
                0,
              ),
              child: Row(
                children: [
                  statusPill,
                  const Spacer(),
                  Flexible(
                    child: Text(
                      metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Route(request: r),
            const _Perforation(),
            _PhotoAndFacts(request: r),
            if (hasFooterDetails)
              _FooterDetails(
                key: const Key('request-ticket-footer-details'),
                request: r,
              ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat(
      'd MMM',
      AppL10n.localeName,
    ).format(request.desiredDate);
    final dateLabel = request.dateToleranceDays > 0
        ? '$date ± ${request.dateToleranceDays} j'
        : date;
    const codeStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    Widget end(String city, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(cityCode(city), style: codeStyle.copyWith(color: cs.onSurface)),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Semantics(
      label: '${request.departureCity} vers ${request.arrivalCity}, $dateLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Row(
          children: [
            Expanded(
              child: end(request.departureCity, CrossAxisAlignment.start),
            ),
            Column(
              children: [
                DonyIcon('plane', size: 20, color: cs.primary),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            Expanded(child: end(request.arrivalCity, CrossAxisAlignment.end)),
          ],
        ),
      ),
    );
  }
}

/// Pointillés + deux encoches aux bords, couleur du fond d'écran.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ground = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
            child: LayoutBuilder(
              builder: (_, constraints) {
                final dashes = (constraints.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    dashes,
                    (_) => Container(width: 5, height: 1.5, color: cs.outline),
                  ),
                );
              },
            ),
          ),
          for (final left in [true, false])
            Positioned(
              left: left ? -10 : null,
              right: left ? null : -10,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: ground,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoAndFacts extends StatelessWidget {
  const _PhotoAndFacts({required this.request});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = request;
    final price = r.grossPriceEur ?? r.targetPriceEur;
    final facts = [
      '${r.weightKg.toStringAsFixed(r.weightKg % 1 == 0 ? 0 : 1)} kg',
      if (r.categories.isNotEmpty) r.categories.first,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(urls: r.photoUrls),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facts,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (r.description != null &&
                    r.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: DonySpacing.sm),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6,
                  children: [
                    Text(
                      price == null
                          ? 'Prix à définir'
                          : formatPriceIn(price, r.currency),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      r.negotiable ? 'négociable' : 'prix ferme',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (r.convertedDisplayPrice != null &&
                    r.convertedCurrency != null)
                  Text(
                    '≈ ${formatPriceIn(r.convertedDisplayPrice!, r.convertedCurrency)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final cs = Theme.of(context).colorScheme;
    if (urls.isEmpty) {
      return Container(
        key: const Key('request-ticket-photo-placeholder'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
        child: Center(
          child: DonyIcon('package', size: 28, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Voir les photos du colis',
      child: GestureDetector(
        onTap: () => RequestPhotoViewer.show(context, urls: urls),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: urls.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(
                    key: const Key('request-ticket-photo-error'),
                    color: cs.surfaceContainerHighest,
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: DonyColors.scrimDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+${urls.length - 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterDetails extends StatelessWidget {
  const _FooterDetails({required this.request, super.key});
  final PackageRequest request;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = request;
    final zones = [r.pickupNeighborhood, r.deliveryNeighborhood];
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.md,
        DonySpacing.base,
        DonySpacing.base,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (zones.any((z) => z != null)) ...[
            Row(
              children: [
                DonyIcon('map-pin', size: 14, color: cs.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${zones[0] ?? r.departureCity} → ${zones[1] ?? r.arrivalCity}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DonySpacing.sm),
          ],
          if (r.acceptedPaymentMethods.isNotEmpty)
            PaymentMethodsChips(methods: r.acceptedPaymentMethods),
        ],
      ),
    );
  }
}
