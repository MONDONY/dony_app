import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';

class PackageRequestPreviewBottomSheet {
  const PackageRequestPreviewBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required PackageRequestSearchItem item,
  }) async {
    await DonyBottomSheet.show<void>(
      context,
      title: '${item.departureCity} → ${item.arrivalCity}',
      stickyBottom: DonyButton(
        label: 'Faire une offre',
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          MakeOfferBottomSheet.show(
            context,
            packageRequestId: item.id,
            targetPriceEur: item.targetPriceEur,
            weightKg: item.weightKg,
            departureCity: item.departureCity,
            arrivalCity: item.arrivalCity,
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.targetPriceEur != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kGreenLight,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: kGreenPrimary, size: 22),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget cible',
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                fontSize: 12, color: kGreenDark)),
                        Text(
                          '${item.targetPriceEur!.toStringAsFixed(0)} €',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kGreenPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: DonySpacing.base),
          _row(Icons.calendar_today_rounded, 'Date souhaitée',
              '${item.desiredDate.day}/${item.desiredDate.month}/${item.desiredDate.year}  (±${item.dateToleranceDays}j)', context),
          const SizedBox(height: DonySpacing.sm),
          _row(Icons.scale_rounded, 'Poids', '${item.weightKg} kg', context),
          const SizedBox(height: DonySpacing.sm),
          _row(Icons.archive_rounded, 'Taille',
              item.parcelSize.name.toUpperCase(), context),
          const SizedBox(height: DonySpacing.sm),
          _row(Icons.label_rounded, 'Catégorie', item.contentCategory.label, context),
          if (item.pickupNeighborhood != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _row(Icons.location_on_rounded, 'Pickup', item.pickupNeighborhood!, context),
          ],
          if (item.deliveryNeighborhood != null) ...[
            const SizedBox(height: DonySpacing.sm),
            _row(Icons.location_on_outlined, 'Livraison',
                item.deliveryNeighborhood!, context),
          ],
          const SizedBox(height: DonySpacing.base),
          Container(
            padding: const EdgeInsets.all(DonySpacing.md),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(DonyRadius.md),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: kGreenLight,
                  child: const Icon(Icons.person_rounded,
                      color: kGreenPrimary, size: 18),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.sender.displayName,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          if (item.sender.kycVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded,
                                color: kGreenPrimary, size: 14),
                          ],
                        ],
                      ),
                      if (item.sender.totalRatings > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: kWarning, size: 13),
                            const SizedBox(width: 2),
                            Text(
                              '${item.sender.averageRating.toStringAsFixed(1)} (${item.sender.totalRatings})',
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                  fontSize: 12, color: kTextSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _row(IconData icon, String label, String value, BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: DonySpacing.md),
        SizedBox(
          width: 110,
          child: Text(label,
              style: tt.bodyMedium!.copyWith(
                  fontSize: 13, color: kTextSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: tt.bodyMedium!.copyWith(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
