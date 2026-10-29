// Bottom sheets des tuiles « Votre envoi » de la fiche colis (vue expéditeur) :
// titre, contenu, bouton du bas, BLoCs reposés, mesure d'ouverture et libellés
// des boutons à taille nominale en anglais, à 360 dp et grand texte.
import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockContactRevealBloc
    extends MockBloc<ContactRevealEvent, ContactRevealState>
    implements ContactRevealBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

class _FakeUri extends Fake implements Uri {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

const _handover = AddressData(
  label: '22 Rue du Séminaire, 94550 Chevilly-Larue, France',
  lat: 48.7667,
  lng: 2.3508,
);
const _delivery = AddressData(
  label: 'ACI 2000, Bamako, Mali',
  lat: 12.6362,
  lng: -8.0121,
);

TravelerTrackingModel _tracking({
  TravelerTrackingStatus status = TravelerTrackingStatus.enRoute,
}) => TravelerTrackingModel(
  status: status,
  lastUpdatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  progressPct: 40,
  nearestCity: 'Marseille',
);

BidModel _bid({
  String id = 'bid-001',
  String status = 'IN_TRANSIT',
  String? confirmationCode,
  bool pickupCodeRenewalNeeded = false,
  bool amendmentAllowed = false,
  TravelerTrackingModel? travelerTracking,
  String? recipientName = 'Awa',
  String? recipientPhone = '+221700000000',
}) => BidModel(
  id: id,
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  weightKg: 3,
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  trackingToken: 'tok-abc123',
  confirmationCode: confirmationCode,
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  amendmentAllowed: amendmentAllowed,
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  handoverAddress: _handover,
  deliveryAddress: _delivery,
  travelerTracking: travelerTracking,
);

/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et tout libellé paraît rétréci, ce qui
/// fausserait la mesure des boutons.
Future<void> _loadAppFonts() async {
  const families = {
    'HankenGrotesk': [
      'HankenGrotesk-SemiBold',
      'HankenGrotesk-Bold',
      'HankenGrotesk-ExtraBold',
    ],
    'PlusJakartaSans': [
      'PlusJakartaSans-Regular',
      'PlusJakartaSans-Medium',
      'PlusJakartaSans-SemiBold',
      'PlusJakartaSans-Bold',
    ],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void _resetGetIt() {
  if (getIt.isRegistered<AnalyticsService>()) {
    getIt.unregister<AnalyticsService>();
  }
  if (getIt.isRegistered<TravelerTrackingCardCubit>()) {
    getIt.unregister<TravelerTrackingCardCubit>();
  }
  if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
  if (getIt.isRegistered<ExternalUrlLauncher>()) {
    getIt.unregister<ExternalUrlLauncher>();
  }
}

void main() {
  late MockAnalyticsBackend backend;
  late _MockBidBloc bidBloc;
  late _MockTrackingBloc trackingBloc;
  late _MockLauncher launcher;

  setUpAll(() async {
    registerFallbackValue(_FakeUri());
    registerFallbackValue(_FakeTrackingEvent());
    registerFallbackValue(BidDetailRequested('fallback'));
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await _loadAppFonts();
  });

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    bidBloc = _MockBidBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => bidBloc.stream,
    ).thenAnswer((_) => const Stream<BidState>.empty());
    trackingBloc = _MockTrackingBloc();
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(
      () => trackingBloc.stream,
    ).thenAnswer((_) => const Stream<TrackingState>.empty());
    launcher = _MockLauncher();
    when(() => launcher.open(any())).thenAnswer((_) async => true);

    _resetGetIt();
    getIt.registerSingleton<AnalyticsService>(analytics);
    getIt.registerFactory<TravelerTrackingCardCubit>(
      () => TravelerTrackingCardCubit(analytics: analytics),
    );
    getIt.registerSingleton<ExternalUrlLauncher>(launcher);
  });

  tearDown(() {
    _resetGetIt();
  });

  /// Ouvre la tuile depuis un `Builder` posé sous les fournisseurs de
  /// `BidDetailScreen`, comme le fait l'écran.
  Future<void> openTile(
    WidgetTester tester,
    BidModel bid,
    SenderTile tile, {
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size? size,
    bool withBidBloc = true,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            if (withBidBloc) BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(
              value: _MockBidAcceptanceBloc(),
            ),
            BlocProvider<TrackingBloc>.value(value: trackingBloc),
            BlocProvider<ConversationOpenBloc>.value(
              value: _MockConversationOpenBloc(),
            ),
            BlocProvider<ContactRevealBloc>.value(
              value: _MockContactRevealBloc(),
            ),
            BlocProvider<RatingBloc>.value(value: _MockRatingBloc()),
            BlocProvider<CancellationBloc>.value(
              value: _MockCancellationBloc(),
            ),
          ],
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openSenderTileSheet(context, bid, tile),
                child: const Text('open-tile'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-tile'));
    await tester.pumpAndSettle();
  }

  Finder footerButton() => find.descendant(
    of: find.byKey(const Key('donyBottomSheetFooter')),
    matching: find.byType(DonyButton),
  );

  group('titre de chaque tuile', () {
    for (final (tile, bid, title) in [
      (SenderTile.prevenir, _bid(), 'Prévenir Awa'),
      (SenderTile.suivi, _bid(travelerTracking: _tracking()), 'Suivi'),
      (SenderTile.lieux, _bid(status: 'ACCEPTED'), 'Lieux'),
      (SenderTile.colis, _bid(), 'Colis et destinataire'),
      (SenderTile.details, _bid(), 'Plus de détails'),
    ]) {
      testWidgets('${tile.name} opens without exception and shows its title', (
        tester,
      ) async {
        await openTile(tester, bid, tile);

        expect(tester.takeException(), isNull);
        expect(find.text(title), findsOneWidget);
      });
    }

    testWidgets('prevenir title falls back when the recipient has no name', (
      tester,
    ) async {
      await openTile(tester, _bid(recipientName: ' '), SenderTile.prevenir);

      expect(
        find.text(
          lookupAppLocalizations(const Locale('fr')).recipientNotifyTitle(
            lookupAppLocalizations(
              const Locale('fr'),
            ).recipientNotifyFallbackName,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('prevenir', () {
    testWidgets('sticky button label is the code label when withCode', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(confirmationCode: '482913'),
        SenderTile.prevenir,
      );

      expect(footerButton(), findsOneWidget);
      expect(
        find.descendant(
          of: footerButton(),
          matching: find.text('Envoyer le code sur WhatsApp'),
        ),
        findsOneWidget,
      );
      // Aucun bouton dans le contenu défilant.
      expect(find.byType(DonyButton), findsOneWidget);
    });

    testWidgets('sticky button offers the link when the code has expired', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(confirmationCode: '482913', pickupCodeRenewalNeeded: true),
        SenderTile.prevenir,
      );

      expect(
        find.descendant(
          of: footerButton(),
          matching: find.text('Prévenir sur WhatsApp'),
        ),
        findsOneWidget,
      );
      expect(find.text('Envoyer le code sur WhatsApp'), findsNothing);
    });

    testWidgets('sticky button opens WhatsApp with the message', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.prevenir);

      await tester.tap(footerButton());
      await tester.pump();

      final uri =
          verify(() => launcher.open(captureAny())).captured.single as Uri;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/221700000000');
      expect(uri.queryParameters['text'], contains('tok-abc123'));
    });
  });

  group('suivi', () {
    testWidgets('shows the tracking and the places without frame', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(travelerTracking: _tracking()),
        SenderTile.suivi,
      );

      expect(find.byKey(const Key('traveler-tracking-badge')), findsOneWidget);
      expect(find.text('Près de Marseille'), findsOneWidget);
      expect(find.byKey(const Key('parcel-location-handover')), findsOneWidget);
      // La mini-carte a des coins arrondis posés par le sheet.
      expect(
        find.ancestor(
          of: find.byType(AddressPointMiniMap),
          matching: find.byWidgetPredicate(
            (w) =>
                w is ClipRRect &&
                w.borderRadius == BorderRadius.circular(DonyRadius.md),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sticky button closes the sheet and opens the timeline', (
      tester,
    ) async {
      getIt.registerFactory<TrackingBloc>(() => trackingBloc);
      await openTile(
        tester,
        _bid(travelerTracking: _tracking()),
        SenderTile.suivi,
      );
      clearInteractions(trackingBloc);

      expect(
        find.descendant(
          of: footerButton(),
          matching: find.text('Voir toutes les étapes et photos'),
        ),
        findsOneWidget,
      );
      await tester.tap(footerButton());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Le sheet du suivi est fermé (son titre « Suivi » a disparu) et la
      // frise a demandé les étapes du colis.
      expect(find.text('Suivi'), findsNothing);
      verify(
        () => trackingBloc.add(
          any(
            that: isA<TrackingEventsRequested>().having(
              (e) => e.bidId,
              'bidId',
              'bid-001',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('timeline button logs traveler_tracking_timeline_opened '
        'with the tracking status', (tester) async {
      getIt.registerFactory<TrackingBloc>(() => trackingBloc);
      await openTile(
        tester,
        _bid(travelerTracking: _tracking(status: TravelerTrackingStatus.stale)),
        SenderTile.suivi,
      );
      clearInteractions(backend);

      await tester.tap(footerButton());
      await tester.pumpAndSettle();

      verify(
        () => backend.capture(AnalyticsEvents.travelerTrackingTimelineOpened, {
          'status': 'stale',
        }),
      ).called(1);
    });

    testWidgets('timeline button still opens the timeline without the '
        'tracking card, with no tracking event', (tester) async {
      getIt.registerFactory<TrackingBloc>(() => trackingBloc);
      await openTile(tester, _bid(status: 'HANDED_OVER'), SenderTile.suivi);
      clearInteractions(backend);
      clearInteractions(trackingBloc);

      expect(find.byKey(const Key('traveler-tracking-badge')), findsNothing);
      await tester.tap(footerButton());
      await tester.pumpAndSettle();

      expect(find.text('Suivi'), findsNothing);
      verify(
        () => trackingBloc.add(any(that: isA<TrackingEventsRequested>())),
      ).called(1);
      verifyNever(
        () => backend.capture(
          AnalyticsEvents.travelerTrackingTimelineOpened,
          any(),
        ),
      );
    });
  });

  group('lieux', () {
    testWidgets('shows the places and no sticky button', (tester) async {
      await openTile(tester, _bid(status: 'ACCEPTED'), SenderTile.lieux);

      expect(find.byKey(const Key('parcel-location-handover')), findsOneWidget);
      expect(find.byKey(const Key('parcel-location-delivery')), findsOneWidget);
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
    });
  });

  group('colis', () {
    testWidgets('colis shows add-items button only when amendmentAllowed', (
      tester,
    ) async {
      await openTile(tester, _bid(amendmentAllowed: true), SenderTile.colis);

      expect(
        find.descendant(
          of: footerButton(),
          matching: find.text('Ajouter des kilos ou des articles'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ColisDestinataireCard), findsOneWidget);
    });

    testWidgets('colis has no sticky button when the amendment is refused', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.colis);

      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
      expect(find.text('Ajouter des kilos ou des articles'), findsNothing);
    });

    testWidgets('sheet content reads the BidBloc of the screen', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.colis);

      final inSheet = tester.element(find.byType(ColisDestinataireCard));
      expect(inSheet.read<BidBloc>(), same(bidBloc));
    });
  });

  group('colis courant', () {
    late StreamController<BidState> states;

    setUp(() {
      states = StreamController<BidState>.broadcast();
      addTearDown(states.close);
      whenListen(bidBloc, states.stream, initialState: BidInitial());
    });

    testWidgets('colis sheet shows the new recipient after a BidDetailLoaded', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.colis);
      expect(find.text('Awa'), findsOneWidget);

      states.add(BidDetailLoaded(_bid(recipientName: 'Fatou')));
      await tester.pumpAndSettle();

      expect(find.text('Fatou'), findsOneWidget);
      expect(find.text('Awa'), findsNothing);
    });

    testWidgets('a BidDetailLoaded of another bid changes nothing', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.colis);

      states.add(
        BidDetailLoaded(_bid(recipientName: 'Fatou', id: 'bid-other')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('Fatou'), findsNothing);
    });

    testWidgets('without BidBloc the sheet shows the opening bid', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.colis, withBidBloc: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Awa'), findsOneWidget);
    });

    testWidgets('amendment button follows the current bid', (tester) async {
      await openTile(tester, _bid(amendmentAllowed: true), SenderTile.colis);
      expect(find.text('Ajouter des kilos ou des articles'), findsOneWidget);

      states.add(BidDetailLoaded(_bid()));
      await tester.pumpAndSettle();

      expect(find.text('Ajouter des kilos ou des articles'), findsNothing);
    });

    testWidgets('prevenir button label follows the current bid', (
      tester,
    ) async {
      await openTile(tester, _bid(), SenderTile.prevenir);
      expect(find.text('Prévenir sur WhatsApp'), findsOneWidget);

      states.add(BidDetailLoaded(_bid(confirmationCode: '482913')));
      await tester.pumpAndSettle();

      expect(find.text('Envoyer le code sur WhatsApp'), findsOneWidget);
    });
  });

  group('details', () {
    testWidgets('shows the details without sticky button', (tester) async {
      await openTile(tester, _bid(), SenderTile.details);

      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
      expect(find.byType(BidDetailsContent), findsOneWidget);
      expect(find.text('BID-001'), findsOneWidget);
    });
  });

  group('mesure', () {
    for (final tile in SenderTile.values) {
      testWidgets('logs bid_detail_tile_opened with tile name (${tile.name})', (
        tester,
      ) async {
        await openTile(tester, _bid(travelerTracking: _tracking()), tile);

        verify(
          () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': tile.name,
          }),
        ).called(1);
      });
    }

    test('event name', () {
      expect(AnalyticsEvents.bidDetailTileOpened, 'bid_detail_tile_opened');
    });
  });

  group('boutons à taille nominale', () {
    /// Rapport entre la largeur rendue du libellé dans le `FittedBox` du
    /// `DonyButton` et sa largeur naturelle : 1 = aucune réduction.
    double labelScale(WidgetTester tester, String label) {
      final fitted = find.descendant(
        of: footerButton(),
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(
        of: footerButton(),
        matching: find.text(label),
      );
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    const size = Size(360, 800);

    // Anglais à 1,3 (cas du brief) ; français à taille normale : à 1,3 les
    // libellés « Envoyer le code sur WhatsApp » et « Ajouter des kilos ou des
    // articles » rétrécissent de 2 à 4 % (signalé dans le rapport).
    for (final (locale, scale) in const [
      (Locale('en'), 1.3),
      (Locale('fr'), 1.0),
    ]) {
      final l = lookupAppLocalizations(locale);
      for (final (name, bid, tile, label) in [
        (
          'prevenir with code',
          _bid(confirmationCode: '482913'),
          SenderTile.prevenir,
          l.recipientNotifyButtonCode,
        ),
        (
          'prevenir with link',
          _bid(),
          SenderTile.prevenir,
          l.recipientNotifyButtonLink,
        ),
        (
          'suivi timeline',
          _bid(travelerTracking: _tracking()),
          SenderTile.suivi,
          l.travelerTrackingOpenTimeline,
        ),
        (
          'colis amendment',
          _bid(amendmentAllowed: true),
          SenderTile.colis,
          l.amendmentEntryButton,
        ),
      ]) {
        testWidgets('sticky buttons keep nominal font in '
            '${locale.languageCode} at 360 dp, TextScaler $scale ($name)', (
          tester,
        ) async {
          await openTile(
            tester,
            bid,
            tile,
            locale: locale,
            textScale: scale,
            size: size,
          );

          expect(tester.takeException(), isNull);
          expect(tester.getSize(footerButton()).height, 52);
          expect(labelScale(tester, label), closeTo(1, 0.001));
        });
      }
    }
  });
}
