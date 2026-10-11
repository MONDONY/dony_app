import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_camera_view.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockMediaService extends Mock implements DonyMediaService {}

class _MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

/// Géocodage inverse factice : rend [places] ou lève si [fail].
class _FakeGeocoding extends GeocodingPlatform {
  List<Placemark> places = const [];
  bool fail = false;

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    if (fail) throw Exception('géocodage indisponible');
    return places;
  }
}

const _bidId = '3f2b6c1e-8a4d-4f6b-9c2e-1d7a5b3c9e0f';

TrackingEventModel _event(String type) => TrackingEventModel(
  id: 'ev-1',
  bidId: _bidId,
  eventType: type,
  scannedAt: DateTime(2026, 10, 11),
  createdAt: DateTime(2026, 10, 11),
);

Position _position({double lat = 14.69, double lon = -17.44}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026, 10, 11),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late StreamController<TrackingState> states;
  late _MockTrackingBloc bloc;
  late _MockRatingBloc ratingBloc;
  late _MockTrackingRepository repo;
  late _MockMediaService media;
  late _MockGeolocatorPlatform geolocator;
  late _FakeGeocoding geocoding;
  late List<MethodCall> exifCalls;

  setUpAll(() {
    registerFallbackValue(QrScanSubmitRequested(bidId: '', eventType: ''));
    registerFallbackValue(const LocationSettings());
    registerFallbackValue(ImageSource.camera);
  });

  setUp(() {
    useEnglish();
    DonySnackbar.clearDedup();
    states = StreamController<TrackingState>.broadcast();
    bloc = _MockTrackingBloc();
    when(() => bloc.state).thenReturn(TrackingInitial());
    whenListen(bloc, states.stream);
    ratingBloc = _MockRatingBloc();
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    whenListen(ratingBloc, const Stream<RatingState>.empty());

    repo = _MockTrackingRepository();
    media = _MockMediaService();
    getIt.registerSingleton<TrackingRepository>(repo);
    getIt.registerSingleton<DonyMediaService>(media);

    // Sans plugin : la permission échoue, la photo part sans position.
    geolocator = _MockGeolocatorPlatform();
    when(
      () => geolocator.requestPermission(),
    ).thenThrow(MissingPluginException());
    GeolocatorPlatform.instance = geolocator;
    geocoding = _FakeGeocoding();
    GeocodingPlatform.instance = geocoding;

    exifCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('native_exif'), (
          call,
        ) async {
          exifCalls.add(call);
          return call.method == 'initPath' ? 1 : null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('native_exif'), null);
    await states.close();
    await getIt.reset();
  });

  /// L'écran du scanner, posé sur deux routes pour que ses `context.pop()`
  /// (feuille, écran, dialogue) aient toujours une route sous eux.
  Future<GoRouter> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/hub/scan',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('racine')),
          routes: [
            GoRoute(
              path: 'hub',
              builder: (_, _) => const Scaffold(body: Text('accueil')),
              routes: [
                GoRoute(
                  path: 'scan',
                  builder: (_, _) => MultiBlocProvider(
                    providers: [
                      BlocProvider<TrackingBloc>.value(value: bloc),
                      BlocProvider<RatingBloc>.value(value: ratingBloc),
                    ],
                    child: const QrScannerScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    return router;
  }

  /// Un QR Yadony détecté par la caméra ouvre la feuille de confirmation.
  Future<void> detectQr(WidgetTester tester) async {
    tester.widget<QrCameraView>(find.byType(QrCameraView)).onBidId(_bidId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('QR scanned'), findsOneWidget);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  group('QR détecté par la caméra', () {
    testWidgets('l\'étape choisie part avec la méthode QR', (tester) async {
      await pumpScreen(tester);
      await detectQr(tester);

      // Une seconde lecture pendant que la feuille est ouverte est ignorée.
      tester.widget<QrCameraView>(find.byType(QrCameraView)).onBidId(_bidId);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('QR scanned'), findsOneWidget);

      await tapVisible(tester, find.text('Transit'));
      await tester.pump(const Duration(milliseconds: 300));
      await tapVisible(tester, find.text('Confirm scan'));

      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as QrScanSubmitRequested;
      expect(event.bidId, _bidId);
      expect(event.eventType, 'TRANSIT');
      expect(event.scanMethod, ScanMethod.qr);
      // Le numéro de suivi n'accompagne que la remise (DEPART).
      expect(event.trackingNumber, isNull);
      await settle(tester);
    });

    testWidgets('arrivée : code à 6 chiffres exigé avant la confirmation', (
      tester,
    ) async {
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Arrival'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Recipient\'s pickup code'), findsOneWidget);
      expect(find.text('Take a photo'), findsNothing);

      await tester.enterText(find.byType(TextField), '123');
      await tapVisible(tester, find.text('Confirm delivery'));
      verifyNever(() => bloc.add(any()));

      await tester.enterText(find.byType(TextField), '123456');
      await tapVisible(tester, find.text('Confirm delivery'));
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as ConfirmDeliveryRequested;
      expect(event.bidId, _bidId);
      expect(event.code, '123456');
      expect(event.scanMethod, ScanMethod.qr);
      expect(event.photo, isNull);
      await settle(tester);
    });

    testWidgets('fermer la feuille relance la lecture', (tester) async {
      await pumpScreen(tester);
      await detectQr(tester);

      await tester.tap(find.byTooltip('Close').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('QR scanned'), findsNothing);

      // La détection est réarmée : un nouveau QR rouvre la feuille.
      await detectQr(tester);
      await settle(tester);
    });

    testWidgets('envoi en cours : bouton en chargement, fermeture masquée', (
      tester,
    ) async {
      await pumpScreen(tester);
      await detectQr(tester);
      expect(find.byTooltip('Close'), findsNWidgets(2));

      states.add(QrScanSubmitting());
      await tester.pump();
      expect(find.byTooltip('Close'), findsOneWidget);

      // Pendant l'envoi, les étapes ne se choisissent plus.
      await tester.tap(find.text('Arrival'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Recipient\'s pickup code'), findsNothing);
      await settle(tester);
    });

    testWidgets('erreur d\'envoi affichée sous le bouton', (tester) async {
      await pumpScreen(tester);
      await detectQr(tester);

      final en = lookupAppLocalizations(const Locale('en'));
      const network = NetworkException('réseau');
      states.add(QrScanError(network));
      await tester.pump();
      expect(
        find.text(ErrorPresenter.resolve(network, l10n: en).message),
        findsOneWidget,
      );

      const server = ServerException();
      states.add(DeliveryConfirmError(server));
      await tester.pump();
      expect(
        find.text(ErrorPresenter.resolve(server, l10n: en).message),
        findsOneWidget,
      );
      expect(find.text('QR scanned'), findsOneWidget);
      await settle(tester);
    });
  });

  // Les dialogues de résultat sont ouverts par l'écran. Feuille ouverte, la
  // feuille se referme elle aussi sur le même état et son `context.pop()`
  // retire le dialogue à peine poussé : on les teste donc sans feuille.
  group('résultat du scan', () {
    Future<void> emit(WidgetTester tester, TrackingState state) async {
      states.add(state);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('hors ligne : la file d\'attente est annoncée', (tester) async {
      await pumpScreen(tester);
      await emit(tester, QrScanQueued());

      expect(find.text('Scan pending'), findsOneWidget);
      expect(
        find.text(
          'No internet connection. The scan will sync automatically once '
          'you\'re back online.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Scan pending'), findsNothing);
      await settle(tester);
    });

    testWidgets('étape intermédiaire : « Scan recorded! »', (tester) async {
      await pumpScreen(tester);
      await emit(tester, QrScanSuccess(_event('TRANSIT')));

      expect(find.text('Scan recorded!'), findsOneWidget);
      expect(find.text('In transit'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Scan recorded!'), findsNothing);
      await settle(tester);
    });

    testWidgets('arrivée : « Parcel delivered! »', (tester) async {
      await pumpScreen(tester);
      await emit(tester, QrScanSuccess(_event('ARRIVEE')));
      expect(find.text('Parcel delivered!'), findsOneWidget);
      expect(find.text('Scan recorded!'), findsNothing);
      await settle(tester);
    });
  });

  group('photo du colis', () {
    testWidgets('photo prise sans position puis retirée', (tester) async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/inexistante.jpg'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Take a photo'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('GPS location recorded'), findsNothing);
      verify(() => media.pick(source: ImageSource.camera)).called(1);

      await tapVisible(tester, find.bySemanticsLabel('Remove the photo'));
      await tester.pump();
      expect(find.text('Take a photo'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('position relevée : EXIF écrit et lieu affiché', (
      tester,
    ) async {
      when(
        () => geolocator.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => geolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => _position(lat: -14.5, lon: 17.25));
      geocoding.places = const [
        Placemark(
          street: ' Rue 10 ',
          locality: 'Dakar',
          administrativeArea: 'Dakar',
          country: 'Sénégal',
        ),
      ];
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/inexistante.jpg'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('Rue 10, Dakar, Sénégal'), findsOneWidget);

      final write = exifCalls.firstWhere((c) => c.method == 'setAttributes');
      final attrs =
          (write.arguments as Map)['values'] as Map? ?? write.arguments;
      expect(attrs.toString(), contains('GPSLatitudeRef'));
      expect(attrs.toString(), contains('14/1,30/1,0/100'));
      expect(exifCalls.any((c) => c.method == 'close'), isTrue);

      await tapVisible(tester, find.text('Confirm scan'));
      final event =
          verify(() => bloc.add(captureAny())).captured.single
              as QrScanSubmitRequested;
      expect(event.gpsLat, -14.5);
      expect(event.gpsLon, 17.25);
      expect(event.gpsLabel, 'Rue 10, Dakar, Sénégal');
      expect(event.photo, isNotNull);
      await settle(tester);
    });

    testWidgets('position sans lieu connu : mention générique', (tester) async {
      when(
        () => geolocator.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.always);
      when(
        () => geolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => _position());
      geocoding.places = const [Placemark(street: '  ')];
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/inexistante.jpg'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('GPS location recorded'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('géocodage en échec : mention générique', (tester) async {
      when(
        () => geolocator.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => geolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => _position());
      geocoding.fail = true;
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/inexistante.jpg'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('GPS location recorded'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('géocodage vide : mention générique', (tester) async {
      when(
        () => geolocator.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);
      when(
        () => geolocator.getCurrentPosition(
          locationSettings: any(named: 'locationSettings'),
        ),
      ).thenAnswer((_) async => _position());
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => XFile('/tmp/inexistante.jpg'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(find.text('GPS location recorded'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('prise annulée : rien ne change', (tester) async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenAnswer((_) async => null);
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      await tester.pump();
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await settle(tester);
    });

    testWidgets('photo trop lourde : avis et message persistant', (
      tester,
    ) async {
      when(() => media.pick(source: any(named: 'source'))).thenThrow(
        const MediaFileTooLargeException(60 * 1024 * 1024, 10 * 1024 * 1024),
      );
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Même texte dans l'avis et sous la vignette.
      expect(
        find.text('Photo too large (max 10 MB). Try again.'),
        findsNWidgets(2),
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('erreur inattendue : retour au bouton de prise', (
      tester,
    ) async {
      when(
        () => media.pick(source: any(named: 'source')),
      ).thenThrow(StateError('caméra'));
      await pumpScreen(tester);
      await detectQr(tester);

      await tapVisible(tester, find.text('Take a photo'));
      await tester.pump();
      expect(find.text('Take a photo'), findsOneWidget);
      await settle(tester);
    });
  });

  group('saisie manuelle du numéro', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Photo'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tracking number'), findsOneWidget);
    }

    testWidgets('annuler referme la boîte', (tester) async {
      await pumpScreen(tester);
      await openDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tracking number'), findsNothing);
      await settle(tester);
    });

    testWidgets('numéro vide : aucune recherche', (tester) async {
      await pumpScreen(tester);
      await openDialog(tester);
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tracking number'), findsOneWidget);
      verifyNever(() => repo.searchByTrackingNumber(any()));
      await settle(tester);
    });

    testWidgets('numéro inconnu : avis d\'erreur, boîte gardée', (
      tester,
    ) async {
      final pending = Completer<Never>();
      when(
        () => repo.searchByTrackingNumber(any()),
      ).thenAnswer((_) => pending.future);
      await pumpScreen(tester);
      await openDialog(tester);
      await tester.enterText(find.byType(TextField), ' don-zzz ');
      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // Recherche en cours : indicateur, boutons coupés.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verify(() => repo.searchByTrackingNumber('DON-ZZZ')).called(1);

      pending.completeError(const NotFoundException());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Number not found. Check and try again.'),
        findsOneWidget,
      );
      expect(find.text('Tracking number'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });

  testWidgets('la croix ferme le scanner', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('accueil'), findsOneWidget);
    await settle(tester);
  });
}
