// Recette du 14/11 : un colis d'un trajet au m³ affichait « POIDS - » sur le
// billet et ni volume ni dimensions dans « Colis et destinataire ». Partout où
// un colis au kilo montre son poids, un colis au m³ montre son volume, jamais
// « 0 kg » ni un tiret.
import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/utils/bid_parcel_size.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_direct_request_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_parcel_rows.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({
  double? volumeM3 = 0.096,
  int? lengthCm,
  int? widthCm,
  int? heightCm,
  double? weightKg,
  String status = 'PENDING',
  String? contentCategory,
}) => BidModel(
  contentCategory: contentCategory,
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  status: status,
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
  transportMode: TransportMode.boat,
  volumeM3: volumeM3,
  lengthCm: lengthCm,
  widthCm: widthCm,
  heightCm: heightCm,
  weightKg: weightKg,
  paymentMethod: BidPaymentMethod.cash,
);

Future<void> _at360(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('bidParcelSizeLabel', () {
    test('colis au m³ : son volume, jamais « 0 kg »', () {
      final bid = _bid(weightKg: 0);
      expect(bid.hasParcelVolume, isTrue);
      expect(bidParcelSizeLabel(fr, bid), '0,096 m³');
      expect(bidParcelSizeLabel(en, bid), '0.096 m³');
      expect(bidParcelSizeLabel(fr, bid), isNot(contains('kg')));
    });

    test('dimensions connues : volume puis L × l × h', () {
      final bid = _bid(lengthCm: 60, widthCm: 40, heightCm: 40);
      expect(
        bidParcelSizeLabel(fr, bid, withDimensions: true),
        '0,096 m³ (60 × 40 × 40 cm)',
      );
      // Résumé court : le volume seul.
      expect(bidParcelSizeLabel(fr, bid), '0,096 m³');
    });

    test('une dimension manquante : le volume seul', () {
      expect(
        bidVolumeLabel(
          fr,
          _bid(lengthCm: 60, widthCm: 40),
          withDimensions: true,
        ),
        '0,096 m³',
      );
    });

    test('colis au kilo : son poids, inchangé', () {
      final bid = _bid(volumeM3: null, weightKg: 5);
      expect(bid.hasParcelVolume, isFalse);
      expect(bidVolumeLabel(fr, bid), isNull);
      expect(bidParcelSizeLabel(fr, bid), '5 kg');
      expect(bidParcelSizeLabel(fr, _bid(volumeM3: 0, weightKg: 5)), '5 kg');
    });

    test('ni volume ni poids : rien', () {
      expect(bidParcelSizeLabel(fr, _bid(volumeM3: null)), isNull);
    });

    test('demande à traiter : « contenu · volume »', () {
      expect(
        tripRequestDetails(fr, _bid(weightKg: 0)),
        endsWith(' · 0,096 m³'),
      );
      expect(
        tripRequestDetails(en, _bid(weightKg: 0)),
        endsWith(' · 0.096 m³'),
      );
    });
  });

  test('BidModel lit les dimensions servies avec le volume', () {
    final bid = BidModel.fromJson({
      'id': 'bid-1',
      'announcementId': 'a-1',
      'senderId': 's-1',
      'status': 'PENDING',
      'createdAt': '2026-11-14T00:00:00.000Z',
      'updatedAt': '2026-11-14T00:00:00.000Z',
      'volumeM3': 0.096,
      'lengthCm': 60,
      'widthCm': 40,
      'heightCm': 40,
    });
    expect((bid.lengthCm, bid.widthCm, bid.heightCm), (60, 40, 40));
    final json = bid.toJson();
    expect(json['lengthCm'], 60);
    expect(json['heightCm'], 40);
    // Back qui ne les sert pas : nulles, le volume seul s'affiche.
    final legacy = BidModel.fromJson({...json}..remove('lengthCm'));
    expect(legacy.lengthCm, isNull);
  });

  for (final locale in const [AppL10n.fr, AppL10n.en]) {
    final l = lookupAppLocalizations(locale);

    testWidgets('billet voyageur à décider ${locale.languageCode} 360 dp : '
        'VOLUME et 0,096 m³, jamais POIDS ni tiret', (tester) async {
      if (locale == AppL10n.en) useEnglish();
      await _at360(tester);
      final tracking = _MockTrackingBloc();
      final bids = _MockBidBloc();
      when(() => tracking.state).thenReturn(TrackingInitial());
      when(() => bids.state).thenReturn(BidInitial());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<TrackingBloc>.value(value: tracking),
                BlocProvider<BidBloc>.value(value: bids),
              ],
              child: BilletTalon(
                bid: _bid(weightKg: 0, contentCategory: 'Vêtements & tissus'),
                isSender: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l.ticketMiniStatVolumeLabel), findsOneWidget);
      expect(
        find.text(locale == AppL10n.fr ? '0,096 m³' : '0.096 m³'),
        findsOneWidget,
      );
      expect(find.text(l.ticketMiniStatWeightLabel), findsNothing);
      expect(find.text('-'), findsNothing);
      expect(find.textContaining('kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Colis et destinataire » ${locale.languageCode} 360 dp : '
        'volume et dimensions', (tester) async {
      await _at360(tester);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: ColisDestinataireCard(
              bid: _bid(lengthCm: 60, widthCm: 40, heightCm: 40, weightKg: 0),
              isSender: false,
              framed: false,
            ),
          ),
          locale: locale,
        ),
      );

      expect(
        find.text(
          locale == AppL10n.fr
              ? '0,096 m³ (60 × 40 × 40 cm)'
              : '0.096 m³ (60 × 40 × 40 cm)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ligne d\'un colis du trajet ${locale.languageCode} 360 dp : '
        'le volume', (tester) async {
      await _at360(tester);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: TripParcelRow(bid: _bid(weightKg: 0), onTap: () {}),
          ),
          locale: locale,
        ),
      );

      expect(
        find.textContaining(locale == AppL10n.fr ? '0,096 m³' : '0.096 m³'),
        findsOneWidget,
      );
      expect(find.textContaining('kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
