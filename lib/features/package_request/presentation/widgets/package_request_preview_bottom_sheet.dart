import 'package:dony/core/design/widgets/dony_bottom_sheet.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_rounded,
                      color: kGreenPrimary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Budget cible',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: kGreenDark)),
                        Text(
                          '${item.targetPriceEur!.toStringAsFixed(0)} €',
                          style: GoogleFonts.plusJakartaSans(
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
          const SizedBox(height: 16),
          _row(Icons.calendar_today_rounded, 'Date souhaitée',
              '${item.desiredDate.day}/${item.desiredDate.month}/${item.desiredDate.year}  (±${item.dateToleranceDays}j)'),
          const SizedBox(height: 8),
          _row(Icons.scale_rounded, 'Poids', '${item.weightKg} kg'),
          const SizedBox(height: 8),
          _row(Icons.archive_rounded, 'Taille',
              item.parcelSize.name.toUpperCase()),
          const SizedBox(height: 8),
          _row(Icons.label_rounded, 'Catégorie', item.contentCategory.label),
          if (item.pickupNeighborhood != null) ...[
            const SizedBox(height: 8),
            _row(Icons.location_on_rounded, 'Pickup', item.pickupNeighborhood!),
          ],
          if (item.deliveryNeighborhood != null) ...[
            const SizedBox(height: 8),
            _row(Icons.location_on_outlined, 'Livraison',
                item.deliveryNeighborhood!),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.sender.displayName,
                            style: GoogleFonts.plusJakartaSans(
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
                              style: GoogleFonts.plusJakartaSans(
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

  static Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: kTextSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
