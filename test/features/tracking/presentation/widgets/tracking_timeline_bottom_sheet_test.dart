import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_image.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends Mock implements TrackingBloc {}

class _FakeTrackingEvent extends Fake implements TrackingEvent {}

TrackingEventModel _event(
  String type, {
  DateTime? scannedAt,
  ScanMethod? scanMethod,
  String? gpsLabel,
  String? photoUrl,
  bool photoPurged = false,
}) => TrackingEventModel(
  id: 'evt-$type',
  bidId: 'bid-1',
  eventType: type,
  scannedAt: scannedAt ?? DateTime(2026, 9, 22, 9, 12),
  createdAt: scannedAt ?? DateTime(2026, 9, 22, 9, 12),
  scanMethod: scanMethod,
  gpsLabel: gpsLabel,
  photoUrl: photoUrl,
  photoPurged: photoPurged,
);

Finder _route(String from, String to) => find.byWidgetPredicate(
  (w) => w is RouteLabel && w.from == from && w.to == to,
);

/// Ouvre la feuille avec un TrackingBloc mocké injecté via GetIt (c'est
/// `showTrackingTimelineSheet` qui l'instancie), sous le vrai thème.
Future<void> _openSheet(
  WidgetTester tester,
  TrackingBloc bloc, {
  String? arrivalInstructions,
  String? from = 'Paris',
  String? to = 'Dakar',
  TransportMode? transportMode,
  String? trackingNumber = 'DON-4K7Q2M',
  VoidCallback? onShare,
  VoidCallback? onOpenParcel,
  ThemeMode themeMode = ThemeMode.light,
  bool settle = true,
  String? bidStatus,
}) async {
  if (getIt.isRegistered<TrackingBloc>()) {
    getIt.unregister<TrackingBloc>();
  }
  getIt.registerFactory<TrackingBloc>(() => bloc);
  addTearDown(() {
    if (getIt.isRegistered<TrackingBloc>()) {
      getIt.unregister<TrackingBloc>();
    }
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => showTrackingTimelineSheet(
              ctx,
              bidId: 'bid-1',
              departureCity: from,
              arrivalCity: to,
              transportMode: transportMode,
              trackingNumber: trackingNumber,
              arrivalInstructions: arrivalInstructions,
              onShareTracking: onShare,
              onOpenParcel: onOpenParcel,
              bidStatus: bidStatus,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Ouvrir'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // L'indicateur de chargement tourne en boucle : pumpAndSettle n'aboutirait pas.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(() async {
    registerFallbackValue(_FakeTrackingEvent());
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  late TrackingBloc bloc;

  setUp(() {
    bloc = _MockTrackingBloc();
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => bloc.add(any())).thenReturn(null);
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  Finder steps(String state) =>
      find.byKey(Key('tracking-step-$state'), skipOffstage: false);

  testWidgets('photo purgée : vignette explicative, ni image ni visionneuse', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(TrackingEventsLoaded([_event('DEPART', photoPurged: true)]));
    await _openSheet(tester, bloc);

    expect(find.byKey(const Key('tracking-step-photo-purged')), findsOneWidget);
    expect(find.text('Photo supprimée après livraison'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.byType(DonyImage), findsNothing);
    expect(find.byKey(const Key('tracking-step-photo')), findsNothing);

    await tester.tap(find.byKey(const Key('tracking-step-photo-purged')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('photo présente et non purgée : miniature habituelle', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      TrackingEventsLoaded([
        _event('DEPART', photoUrl: 'https://example.com/depart.jpg'),
      ]),
    );
    await _openSheet(tester, bloc);

    expect(find.byKey(const Key('tracking-step-photo')), findsOneWidget);
    expect(find.byKey(const Key('tracking-step-photo-purged')), findsNothing);
  });

  testWidgets('FLUTTER-82 : toucher la photo d\'une étape l\'ouvre en grand', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      TrackingEventsLoaded([
        _event('DEPART', photoUrl: 'https://example.com/depart.jpg'),
      ]),
    );
    await _openSheet(tester, bloc);
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.byKey(const Key('tracking-step-photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Visionneuse plein écran zoomable, au-dessus de la feuille.
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final close = find.byTooltip('Fermer').last;
    await tester.tap(close);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InteractiveViewer), findsNothing);
    // La feuille de suivi reste ouverte derrière.
    expect(find.text('Suivi en lecture seule'), findsOneWidget);
  });

  testWidgets('chargement : en-tête lecture seule et indicateur', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoading());
    await _openSheet(tester, bloc, settle: false);

    expect(find.text('Suivi en lecture seule'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => bloc.add(any(that: isA<TrackingEventsRequested>()))).called(1);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('colis en route : numéro, phrase d\'état, frise ($mode)', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        TrackingEventsLoaded([
          _event(
            'DEPART',
            scanMethod: ScanMethod.qr,
            gpsLabel: 'Paris 11e',
            photoUrl: 'https://example.com/depart.jpg',
          ),
        ]),
      );
      await _openSheet(tester, bloc, themeMode: mode, onShare: () {});

      expect(tester.takeException(), isNull);
      expect(find.text('DON-4K7Q2M'), findsOneWidget);
      expect(find.text('En route vers Dakar'), findsOneWidget);
      expect(_route('Paris', 'Dakar'), findsOneWidget);
      // Faite : remise au voyageur, heure, lieu, provenance, photo.
      expect(steps('done'), findsOneWidget);
      expect(find.text('Remis au voyageur'), findsOneWidget);
      expect(find.text('22 sept. 09:12'), findsOneWidget);
      expect(find.text('Paris 11e · Validé par scan du QR'), findsOneWidget);
      expect(find.bySemanticsLabel("Photo de l'étape"), findsOneWidget);
      // En cours puis à venir.
      expect(steps('current'), findsOneWidget);
      expect(find.text('En route'), findsOneWidget);
      expect(steps('upcoming'), findsOneWidget);
      expect(find.text('Remise au destinataire'), findsOneWidget);
      // Transit facultatif, jamais scanné : absent.
      expect(find.text('Transit'), findsNothing);
      // Anciens éléments refusés.
      expect(find.textContaining('4 chiffres'), findsNothing);
      expect(find.text('Pas besoin d\'app !'), findsNothing);
      expect(find.text('Partager le suivi'), findsOneWidget);
    });
  }

  // Sentry FLUTTER-5S : arrivée déclarée sans scan, la frise restait « En route ».
  testWidgets('arrivée déclarée (ARRIVED) : arrivé, remise en cours', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc, bidStatus: 'ARRIVED');

    expect(find.text('Arrivé à Dakar'), findsOneWidget);
    expect(find.text('Arrivé à destination'), findsOneWidget);
    expect(steps('done'), findsNWidgets(2));
    expect(steps('current'), findsOneWidget);
    expect(steps('upcoming'), findsNothing);
    expect(find.text('Remise au destinataire'), findsOneWidget);
    expect(find.text('En route'), findsNothing);
  });

  testWidgets('retour dans l\'app : le parcours est rechargé', (tester) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc);
    clearInteractions(bloc);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    verify(() => bloc.add(any(that: isA<TrackingEventsRequested>()))).called(1);
  });

  testWidgets('aucune étape : attente de la remise au voyageur', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded(const []));
    await _openSheet(tester, bloc, trackingNumber: null);

    expect(find.text('En attente de la remise au voyageur'), findsOneWidget);
    expect(find.byKey(const Key('tracking-number')), findsNothing);
    expect(steps('done'), findsNothing);
    expect(steps('current'), findsOneWidget);
    expect(find.text('Remise au voyageur'), findsOneWidget);
    expect(steps('upcoming'), findsNWidgets(2));
    expect(find.text('Récupération'), findsOneWidget);
    expect(find.text('Remise au destinataire'), findsOneWidget);
  });

  testWidgets('transit scanné et remise faite : colis remis, sans à venir', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(
      TrackingEventsLoaded([
        _event('ARRIVEE', scannedAt: DateTime(2026, 9, 24, 18)),
        _event(
          'TRANSIT',
          scannedAt: DateTime(2026, 9, 23, 7),
          scanMethod: ScanMethod.manual,
        ),
        _event('DEPART', scannedAt: DateTime(2026, 9, 22, 9)),
      ]),
    );
    await _openSheet(tester, bloc);

    expect(find.text('Colis remis au destinataire'), findsOneWidget);
    expect(steps('done'), findsNWidgets(3));
    expect(steps('current'), findsNothing);
    expect(steps('upcoming'), findsNothing);
    expect(find.text('Transit'), findsOneWidget);
    expect(find.text('Validé avec le numéro'), findsOneWidget);
    expect(find.byKey(const Key('tracking-step-method')), findsOneWidget);
    // Ordre chronologique, quel que soit l'ordre reçu.
    final y = [
      'Remis au voyageur',
      'Transit',
      'Remis au destinataire',
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(y, [...y]..sort());
  });

  testWidgets('trajet inconnu (colis lu par QR) : phrase sans ville', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc, from: null, to: null);

    expect(find.text('En route'), findsNWidgets(2));
    expect(find.byType(RouteLabel), findsNothing);
  });

  testWidgets('trajet en voiture : icône voiture sous le titre', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc, transportMode: TransportMode.car);

    expect(
      find.descendant(
        of: find.byKey(const Key('tracking-route')),
        matching: find.byIcon(Icons.directions_car_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sans partage : pas de bouton', (tester) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc);
    expect(find.byKey(const Key('tracking-share')), findsNothing);
  });

  testWidgets('Partager le suivi appelle le partage ; la croix ferme', (
    tester,
  ) async {
    var shared = 0;
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc, onShare: () => shared++);

    await tester.tap(find.byKey(const Key('tracking-share')));
    expect(shared, 1);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Suivi en lecture seule'), findsNothing);
  });

  group('Voir le colis (FLUTTER-7Z)', () {
    testWidgets('sans onOpenParcel : pas de bouton', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
      await _openSheet(tester, bloc);
      expect(find.byKey(const Key('tracking-open-parcel')), findsNothing);
      expect(find.text('Voir le colis'), findsNothing);
    });

    testWidgets('visible dès le chargement ; le tap ferme puis ouvre', (
      tester,
    ) async {
      var opened = 0;
      when(() => bloc.state).thenReturn(TrackingEventsLoading());
      await _openSheet(
        tester,
        bloc,
        settle: false,
        onOpenParcel: () => opened++,
      );
      expect(find.byKey(const Key('tracking-open-parcel')), findsOneWidget);
      expect(find.text('Voir le colis'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tracking-open-parcel')));
      expect(opened, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Suivi en lecture seule'), findsNothing);
    });

    testWidgets('avec partage : deux boutons empilés une fois chargé', (
      tester,
    ) async {
      var shared = 0;
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
      await _openSheet(
        tester,
        bloc,
        onShare: () => shared++,
        onOpenParcel: () {},
      );
      final open = find.byKey(const Key('tracking-open-parcel'));
      final share = find.byKey(const Key('tracking-share'));
      expect(open, findsOneWidget);
      expect(share, findsOneWidget);
      expect(tester.getTopLeft(open).dy, lessThan(tester.getTopLeft(share).dy));
      await tester.tap(share);
      expect(shared, 1);
    });

    testWidgets('avec partage pendant le chargement : seul Voir le colis', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(TrackingEventsLoading());
      await _openSheet(
        tester,
        bloc,
        settle: false,
        onShare: () {},
        onOpenParcel: () {},
      );
      expect(find.byKey(const Key('tracking-open-parcel')), findsOneWidget);
      expect(find.byKey(const Key('tracking-share')), findsNothing);
    });

    testWidgets('en anglais : View parcel', (tester) async {
      when(() => bloc.state).thenReturn(TrackingEventsLoading());
      useEnglish();
      await _openSheet(tester, bloc, settle: false, onOpenParcel: () {});
      expect(find.text('View parcel'), findsOneWidget);
    });
  });

  testWidgets('erreur : message et Réessayer relance le chargement', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(TrackingEventsError(const NetworkException('hors ligne')));
    await _openSheet(tester, bloc);

    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<TrackingEventsRequested>()))).called(2);
  });

  testWidgets('403 : colis non lié au compte, sans Réessayer', (tester) async {
    when(
      () => bloc.state,
    ).thenReturn(TrackingEventsError(const ForbiddenException()));
    await _openSheet(tester, bloc);

    expect(find.text('Réessayer'), findsNothing);
    expect(find.text("Ce colis n'est pas lié à votre compte"), findsOneWidget);
  });

  group('instructions de retrait', () {
    testWidgets('affichées avant la remise', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
      await _openSheet(
        tester,
        bloc,
        arrivalInstructions: 'Métro Châtelet, sortie 3',
      );

      expect(find.text('Instructions de retrait'), findsOneWidget);
      expect(find.text('Métro Châtelet, sortie 3'), findsOneWidget);
    });

    testWidgets('absentes quand vides', (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('ARRIVEE')]));
      await _openSheet(tester, bloc, arrivalInstructions: '   ');

      expect(find.text('Instructions de retrait'), findsNothing);
    });
  });

  testWidgets('en anglais', (tester) async {
    useEnglish();
    when(() => bloc.state).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
    await _openSheet(tester, bloc);

    expect(find.text('Read-only tracking'), findsOneWidget);
    expect(find.text('On the way to Dakar'), findsOneWidget);
    expect(find.text('Handed to the traveler'), findsOneWidget);
    expect(find.text('Handover to the recipient'), findsOneWidget);
  });
}
