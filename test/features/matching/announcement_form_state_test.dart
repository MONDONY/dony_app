import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnouncementFormState.isStep3Valid', () {
    test('mode KG — null pricePerKg → false', () {
      const s = AnnouncementFormState(pricingMode: PricingMode.kg);
      expect(s.isStep3Valid, isFalse);
    });

    test('mode KG — pricePerKg > 0 → true', () {
      const s = AnnouncementFormState(
        pricingMode: PricingMode.kg,
        pricePerKg: 8.0,
      );
      expect(s.isStep3Valid, isTrue);
    });

    test('mode MIXED — pricePerKg null, gridPreviewItems vide → false', () {
      const s = AnnouncementFormState(pricingMode: PricingMode.mixed);
      expect(s.isStep3Valid, isFalse);
    });

    test('mode MIXED — pricePerKg null, gridPreviewItems non vide → true', () {
      final s = AnnouncementFormState(
        pricingMode: PricingMode.mixed,
        gridPreviewItems: [
          GridPreviewItem(id: 'i1', label: 'Téléphone', unitPriceDisplay: 11.2),
        ],
      );
      expect(s.isStep3Valid, isTrue);
    });

    test('mode MIXED — pricePerKg > 0, gridPreviewItems vide → true', () {
      const s = AnnouncementFormState(
        pricingMode: PricingMode.mixed,
        pricePerKg: 8.0,
      );
      expect(s.isStep3Valid, isTrue);
    });
  });

  group('AnnouncementFormState.isFormValid', () {
    test(
      'délègue à isStep3Valid — mode MIXED avec grille → formulaire valide',
      () {
        final s = AnnouncementFormState(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 5)),
          availableKg: 10.0,
          pricingMode: PricingMode.mixed,
          gridPreviewItems: [
            GridPreviewItem(
              id: 'i1',
              label: 'Valise cabine',
              unitPriceDisplay: 22.4,
            ),
          ],
        );
        expect(s.isFormValid, isTrue);
      },
    );

    test(
      'délègue à isStep3Valid — mode KG sans pricePerKg → formulaire invalide',
      () {
        final s = AnnouncementFormState(
          departureCity: 'Paris',
          arrivalCity: 'Dakar',
          departureDate: DateTime.now().add(const Duration(days: 5)),
          availableKg: 10.0,
          pricingMode: PricingMode.kg,
        );
        expect(s.isFormValid, isFalse);
      },
    );
  });
}
