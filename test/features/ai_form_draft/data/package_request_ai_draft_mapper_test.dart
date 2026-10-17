import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/ai_form_draft/data/package_request_ai_draft_mapper.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 9);
  final catalog = [for (final c in fallbackCatalog) c.label];

  PackageRequestFormState map(
    Map<String, Object?> ai, {
    PackageRequestFormState base = const PackageRequestFormState(),
  }) => PackageRequestAiDraftMapper.toFormState(
    ai,
    base: base,
    catalogLabels: catalog,
    now: now,
  );

  test('chaque champ du schéma demande d’envoi', () {
    final s = map(const {
      'departureCity': 'Lyon',
      'arrivalCity': 'Dakar',
      'desiredDate': '2026-11-20',
      'dateToleranceDays': 3,
      'transportMode': 'PLANE',
      'weightKg': 5,
      'parcelSize': 'MEDIUM',
      'categories': ['vêtements'],
      'description': 'Pagnes et chemises',
      'pickupNeighborhood': 'Part-Dieu',
      'negotiable': false,
      'acceptedPaymentMethods': ['STRIPE', 'CASH'],
      'totalBudget': 60,
      'currency': 'EUR',
      'budgetDeclined': false,
    });
    expect(s.currentStep, 0);
    expect(s.departureCity, 'Lyon');
    expect(s.arrivalCity, 'Dakar');
    expect(s.desiredDate, DateTime(2026, 11, 20));
    expect(s.dateToleranceDays, 3);
    expect(s.weightKg, 5);
    expect(s.parcelSize, ParcelSize.medium);
    expect(s.categories, ['Vêtements & tissus']);
    expect(s.description, 'Pagnes et chemises');
    expect(s.negotiable, isFalse);
    expect(s.acceptedPaymentMethods, {
      PaymentMethod.stripe,
      PaymentMethod.cash,
    });
    expect(s.totalBudgetEur, 60);
    expect(s.currency, SupportedCurrency.eur);
    // Ignorés : fixés par le wizard ou plus saisis à la publication.
    expect(s.transportMode, isNull);
    expect(s.pickupNeighborhood, isNull);
  });

  test(
    'catégories : catalogue (partie, pluriel, accents) ou libellé libre',
    () {
      final s = map(const {
        'categories': [
          'Chaussures',
          'parfum',
          'TELEPHONE',
          'jouets en bois',
          'chaussures',
          '  ',
          'Livres',
          'Autre',
        ],
      });
      expect(s.categories, [
        'Chaussures',
        'Cosmétiques & parfums',
        'Téléphone & électronique',
        'jouets en bois',
        'Livres',
      ]);
      expect(
        s.categories,
        hasLength(PackageRequestAiDraftMapper.maxCategories),
      );
    },
  );

  test('taille calculée quand le serveur ne la donne pas', () {
    expect(map(const {'weightKg': 2}).parcelSize, ParcelSize.small);
    // Taille du serveur prioritaire (règle 5 / 15 kg) : 4 kg y est petit,
    // alors que la règle de l'étape 2 (3 / 10 kg) le classerait moyen.
    expect(
      map(const {'weightKg': 4, 'parcelSize': 'SMALL'}).parcelSize,
      ParcelSize.small,
    );
    expect(map(const {'weightKg': 4}).parcelSize, ParcelSize.medium);
    expect(map(const {'weightKg': 10}).parcelSize, ParcelSize.medium);
    expect(map(const {'weightKg': 12.5}).parcelSize, ParcelSize.large);
    expect(
      PackageRequestAiDraftMapper.parcelSizeForWeight(3),
      ParcelSize.small,
    );
  });

  test('valeurs hors bornes ignorées : date passée, tolérance, poids', () {
    final s = map(const {
      'desiredDate': '2026-10-01',
      'dateToleranceDays': 9,
      'weightKg': 40,
    });
    expect(s.desiredDate, isNull);
    expect(s.dateToleranceDays, isNull);
    expect(s.weightKg, isNull);
    expect(s.parcelSize, isNull);
  });

  test('valeurs nulles : l’état courant est gardé', () {
    final base = PackageRequestFormState(
      currentStep: 2,
      departureCity: 'Paris',
      desiredDate: DateTime(2026, 12),
      categories: const ['Livres'],
      acceptedPaymentMethods: const {PaymentMethod.cash},
      totalBudgetEur: 80,
      currency: SupportedCurrency.xof,
      draftRevision: 4,
    );
    final s = map(const {
      'departureCity': null,
      'categories': <String>[],
      'acceptedPaymentMethods': ['WAVE_INCONNU'],
    }, base: base);
    expect(s.currentStep, 0);
    expect(s.departureCity, 'Paris');
    expect(s.desiredDate, DateTime(2026, 12));
    expect(s.categories, ['Livres']);
    expect(s.acceptedPaymentMethods, {PaymentMethod.cash});
    expect(s.totalBudgetEur, 80);
    expect(s.currency, SupportedCurrency.xof);
    expect(s.draftRevision, 4);
  });
}
