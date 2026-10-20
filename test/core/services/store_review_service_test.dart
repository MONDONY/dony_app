import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/store_review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

class _MockInAppReview extends Mock implements InAppReview {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockBox box;
  late _MockInAppReview inAppReview;
  late _MockAnalytics analytics;
  final stored = <String, dynamic>{};
  var now = DateTime(2026, 10, 21, 12);

  setUp(() {
    stored.clear();
    now = DateTime(2026, 10, 21, 12);
    box = _MockBox();
    inAppReview = _MockInAppReview();
    analytics = _MockAnalytics();
    when(
      () => box.get(any()),
    ).thenAnswer((inv) => stored[inv.positionalArguments.first as String]);
    when(() => box.put(any(), any())).thenAnswer((inv) async {
      stored[inv.positionalArguments[0] as String] = inv.positionalArguments[1];
    });
    when(() => inAppReview.isAvailable()).thenAnswer((_) async => true);
    when(() => inAppReview.requestReview()).thenAnswer((_) async {});
    when(
      () => inAppReview.openStoreListing(appStoreId: any(named: 'appStoreId')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  StoreReviewService build() => StoreReviewService(
    box,
    analytics,
    inAppReview: inAppReview,
    now: () => now,
    delay: Duration.zero,
  );

  group('requestAfterRating', () {
    test('5 étoiles : demande la fenêtre, mémorise la date, trace', () async {
      final sent = await build().requestAfterRating(
        stars: 5,
        roleRated: 'traveler',
      );

      expect(sent, isTrue);
      verify(() => inAppReview.requestReview()).called(1);
      expect(stored[StoreReviewService.lastRequestKey], now.toIso8601String());
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.storeReviewRequested,
          properties: {'stars': 5, 'role_rated': 'traveler'},
        ),
      ).called(1);
    });

    test('4 étoiles suffisent', () async {
      expect(
        await build().requestAfterRating(stars: 4, roleRated: 'sender'),
        isTrue,
      );
    });

    test('moins de 4 étoiles : aucune fenêtre', () async {
      expect(
        await build().requestAfterRating(stars: 3, roleRated: 'traveler'),
        isFalse,
      );
      verifyNever(() => inAppReview.isAvailable());
      verifyNever(() => inAppReview.requestReview());
    });

    test('une seule demande pendant le délai de 120 jours', () async {
      final service = build();
      expect(
        await service.requestAfterRating(stars: 5, roleRated: 'traveler'),
        isTrue,
      );

      now = now.add(const Duration(days: 119));
      expect(
        await service.requestAfterRating(stars: 5, roleRated: 'sender'),
        isFalse,
      );

      now = now.add(const Duration(days: 1));
      expect(
        await service.requestAfterRating(stars: 5, roleRated: 'sender'),
        isTrue,
      );
      verify(() => inAppReview.requestReview()).called(2);
    });

    test('date mémorisée illisible : la demande repart', () async {
      stored[StoreReviewService.lastRequestKey] = 'pas une date';

      expect(
        await build().requestAfterRating(stars: 5, roleRated: 'traveler'),
        isTrue,
      );
    });

    test('Store indisponible : rien n\'est mémorisé ni demandé', () async {
      when(() => inAppReview.isAvailable()).thenAnswer((_) async => false);

      expect(
        await build().requestAfterRating(stars: 5, roleRated: 'traveler'),
        isFalse,
      );
      expect(stored, isEmpty);
      verifyNever(() => inAppReview.requestReview());
    });

    test('erreur du plugin : rend false sans lever', () async {
      when(() => inAppReview.requestReview()).thenThrow(Exception('plugin'));

      expect(
        await build().requestAfterRating(stars: 5, roleRated: 'traveler'),
        isFalse,
      );
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.storeReviewRequested,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('openStoreListing', () {
    test('ouvre la fiche avec l\'identifiant App Store et trace', () async {
      expect(await build().openStoreListing(source: 'profile'), isTrue);

      verify(
        () => inAppReview.openStoreListing(appStoreId: '6797821239'),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.storeListingOpened,
          properties: {'source': 'profile'},
        ),
      ).called(1);
    });

    test('échec d\'ouverture : rend false sans lever ni tracer', () async {
      when(
        () =>
            inAppReview.openStoreListing(appStoreId: any(named: 'appStoreId')),
      ).thenThrow(Exception('no store'));

      expect(await build().openStoreListing(source: 'profile'), isFalse);
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });
}
