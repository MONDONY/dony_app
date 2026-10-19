import 'package:dony/features/matching/bloc/announcement_form_state.dart';
import 'package:dony/features/matching/data/models/grid_preview_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnnouncementFormState.isStep3Valid', () {
    test('mode KG — null pricePerKg → false', () {
      const s = AnnouncementFormState();
      expect(s.isStep3Valid, isFalse);
    });

    test('mode KG — pricePerKg > 0 → true', () {
      const s = AnnouncementFormState(pricePerKg: 8.0);
      expect(s.isStep3Valid, isTrue);
    });

    test('mode MIXED — pricePerKg null, gridPreviewItems vide → false', () {
      const s = AnnouncementFormState(pricingMode: PricingMode.mixed);
      expect(s.isStep3Valid, isFalse);
    });

    test('mode MIXED — pricePerKg null, gridPreviewItems non vide → true', () {
      const s = AnnouncementFormState(
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
          gridPreviewItems: const [
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
        );
        expect(s.isFormValid, isFalse);
      },
    );
  });

  // YADONY-FLUTTER-PROD-18 : le défaut et le kg envoyé suivent le compteur.
  group('capacité par défaut et normalisation', () {
    test('un formulaire vierge part d\'une valise de 23 kg', () {
      const s = AnnouncementFormState();
      expect(s.capacityUnit, defaultCapacityUnit);
      expect(defaultCapacityUnit.maxKg, defaultAvailableKg);
      expect(defaultAvailableKg, 23);
    });

    test('valise : ramené à un nombre entier de valises, au moins une', () {
      expect(CapacityUnit.suitcase23kg.normalizeKg(15), 23);
      expect(CapacityUnit.suitcase23kg.normalizeKg(23), 23);
      expect(CapacityUnit.suitcase23kg.normalizeKg(40), 46);
      expect(CapacityUnit.suitcase23kg.normalizeKg(1), 23);
      expect(CapacityUnit.suitcase32kg.normalizeKg(30), 32);
      expect(CapacityUnit.suitcase32kg.normalizeKg(64), 64);
    });

    test('kg libre et personnalisé : inchangés', () {
      expect(CapacityUnit.custom.normalizeKg(17), 17);
      expect(CapacityUnit.kgFree.normalizeKg(1), 1);
    });
  });
}
