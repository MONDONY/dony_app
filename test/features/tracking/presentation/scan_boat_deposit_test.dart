// Scan du dépôt d'un colis bateau (payé au dépôt) : étape « Dépôt à
// l'entrepôt » (icône colis), photo obligatoire (appareil photo ouvert
// d'office, jamais « Passer »), confirmation, refus 422
// `boat-deposit-photo-required` traduit. Sans `payoutTrigger` (back sans la
// PR B) : livraison, comportement d'avant. Jamais d'avion.
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:dony/features/tracking/presentation/screens/scan_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/plane_icon_expectations.dart';

class _MockMedia extends Mock implements DonyMediaService {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

/// Extras reçus par la confirmation au dernier passage.
Map<String, dynamic>? _confirmExtra;

void main() {
  late _MockMedia media;
  late _MockLocator locator;
  late Directory tmp;

  setUp(() {
    media = _MockMedia();
    locator = _MockLocator();
    tmp = Directory.systemTemp.createTempSync('scan_deposit');
    _confirmExtra = null;
    when(() => locator.captureCoordinates()).thenAnswer((_) async => null);
    when(
      () => media.pick(source: ImageSource.camera),
    ).thenAnswer((_) async => null);
    if (getIt.isRegistered<DonyMediaService>()) {
      getIt.unregister<DonyMediaService>();
    }
    getIt.registerSingleton<DonyMediaService>(media);
  });

  tearDown(() {
    getIt.unregister<DonyMediaService>();
    tmp.deleteSync(recursive: true);
  });

  GoRouter photoRouter({
    PayoutTrigger trigger = PayoutTrigger.deposit,
    TransportMode? mode = TransportMode.boat,
    String etape = 'DEPART',
    bool returnResult = false,
  }) => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => ScanPhotoScreen(
          bidId: 'bid-1',
          etape: etape,
          packageLabel: 'DON-7KQ2',
          returnResult: returnResult,
          locator: locator,
          transportMode: mode,
          payoutTrigger: trigger,
        ),
      ),
      GoRoute(
        path: '/tracking/scan/confirm',
        builder: (_, state) {
          _confirmExtra = state.extra as Map<String, dynamic>?;
          return const Scaffold(body: Text('confirm'));
        },
      ),
    ],
  );

  Future<void> openPhoto(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();
    await tester.pump();
  }

  group('écran photo', () {
    testWidgets('scanDeposit_label : « Dépôt à l’entrepôt », icône colis', (
      tester,
    ) async {
      await openPhoto(tester, photoRouter());
      expect(find.text("Étape : Dépôt à l'entrepôt"), findsOneWidget);
      expect(findDonyIcon('package'), findsWidgets);
      expect(find.text('Photo obligatoire'), findsOneWidget);
      expectNoPlaneIcon(tester);
    });

    testWidgets('scanDeposit_photoMandatory : appareil photo ouvert d’office, '
        'pas de « Passer »', (tester) async {
      await openPhoto(tester, photoRouter());
      verify(() => media.pick(source: ImageSource.camera)).called(1);
      // Prise de vue annulée : l'écran reste, sans autre issue que la photo.
      expect(find.text('Prendre la photo'), findsOneWidget);
      expect(find.text('Passer : continuer sans photo'), findsNothing);
      expect(find.text('confirm'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      verifyNever(() => media.pick(source: ImageSource.camera));
    });

    testWidgets('photo prise : la confirmation reçoit le mode et le dépôt', (
      tester,
    ) async {
      final file = File('${tmp.path}/colis.jpg')..writeAsBytesSync([1, 2, 3]);
      when(
        () => media.pick(source: ImageSource.camera),
      ).thenAnswer((_) async => XFile(file.path));
      await openPhoto(tester, photoRouter());
      for (var i = 0; i < 40 && _confirmExtra == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('confirm'), findsOneWidget);
      expect(_confirmExtra?['photoPath'], file.path);
      expect(_confirmExtra?['payoutTrigger'], PayoutTrigger.deposit);
      expect(_confirmExtra?['transportMode'], TransportMode.boat);
    });

    testWidgets('bateau payé à la livraison : libellé du dépôt, pas '
        'd’ouverture d’office', (tester) async {
      await openPhoto(tester, photoRouter(trigger: PayoutTrigger.delivery));
      expect(find.text("Étape : Dépôt à l'entrepôt"), findsOneWidget);
      verifyNever(() => media.pick(source: ImageSource.camera));
      expect(find.text('Passer : continuer sans photo'), findsNothing);
    });

    testWidgets('sans payoutTrigger (back sans la PR B) : comme avant', (
      tester,
    ) async {
      await openPhoto(
        tester,
        photoRouter(trigger: PayoutTrigger.delivery, mode: null),
      );
      expect(find.text('Étape : Récupération'), findsOneWidget);
      verifyNever(() => media.pick(source: ImageSource.camera));
    });

    testWidgets('route : jamais « dépôt à l’entrepôt »', (tester) async {
      await openPhoto(
        tester,
        photoRouter(trigger: PayoutTrigger.delivery, mode: TransportMode.car),
      );
      expect(find.text('Étape : Récupération'), findsOneWidget);
      expect(find.textContaining('entrepôt'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('transit d’un colis payé au dépôt : rien d’ouvert d’office', (
      tester,
    ) async {
      await openPhoto(tester, photoRouter(etape: 'TRANSIT'));
      verifyNever(() => media.pick(source: ImageSource.camera));
      expect(find.text('Étape : Transit'), findsOneWidget);
    });

    testWidgets('onglet Suivi : obligatoire pour valider le dépôt', (
      tester,
    ) async {
      await openPhoto(tester, photoRouter(returnResult: true));
      expect(
        find.text("Obligatoire pour valider le dépôt à l'entrepôt"),
        findsOneWidget,
      );
      verify(() => media.pick(source: ImageSource.camera)).called(1);
      expectNoPlaneIcon(tester);
    });

    testWidgets('anglais', (tester) async {
      useEnglish();
      await openPhoto(tester, photoRouter());
      expect(find.text('Step: Drop-off at the warehouse'), findsOneWidget);
      expect(find.text('Photo required'), findsOneWidget);
    });
  });

  group('confirmation', () {
    setUpAll(() {
      registerFallbackValue(QrScanSubmitRequested(bidId: '', eventType: ''));
    });

    Widget confirm(
      _MockTrackingBloc bloc, {
      PayoutTrigger trigger = PayoutTrigger.deposit,
      TransportMode? mode = TransportMode.boat,
    }) {
      final rating = _MockRatingBloc();
      whenListen(
        rating,
        const Stream<RatingState>.empty(),
        initialState: const RatingInitial(),
      );
      final auth = _MockAuthBloc();
      when(() => auth.state).thenReturn(const AuthInitial());
      final router = GoRouter(
        initialLocation: '/tracking/scan/confirm',
        routes: [
          GoRoute(
            path: '/tracking/scan/confirm',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider<TrackingBloc>.value(value: bloc),
                BlocProvider<RatingBloc>.value(value: rating),
                BlocProvider<AuthBloc>.value(value: auth),
              ],
              child: ScanConfirmScreen(
                bidId: 'bid-1',
                etape: 'DEPART',
                packageLabel: 'DON-7KQ2',
                photoPath: '${tmp.path}/colis.jpg',
                transportMode: mode,
                payoutTrigger: trigger,
              ),
            ),
          ),
        ],
      );
      return MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
    }

    testWidgets('dépôt : pastille et étape du dépôt', (tester) async {
      final bloc = _MockTrackingBloc();
      whenListen(
        bloc,
        const Stream<TrackingState>.empty(),
        initialState: TrackingInitial(),
      );
      await tester.pumpWidget(confirm(bloc));
      await tester.pump();
      expect(find.text('Dépôt enregistré'), findsOneWidget);
      expect(find.text("Dépôt à l'entrepôt"), findsOneWidget);
      expect(find.text('Départ enregistrée'), findsNothing);
      expectNoPlaneIcon(tester);
    });

    testWidgets('422 boat-deposit-photo-required : message traduit', (
      tester,
    ) async {
      final bloc = _MockTrackingBloc();
      whenListen(
        bloc,
        const Stream<TrackingState>.empty(),
        initialState: QrScanError(
          const ValidationException('raw', code: 'boat-deposit-photo-required'),
        ),
      );
      await tester.pumpWidget(confirm(bloc));
      await tester.pump();
      expect(
        find.text(
          'Ajoutez une photo du colis au dépôt pour valider cette étape.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('livraison sans mode : étape « Départ », comme avant', (
      tester,
    ) async {
      final bloc = _MockTrackingBloc();
      whenListen(
        bloc,
        const Stream<TrackingState>.empty(),
        initialState: TrackingInitial(),
      );
      await tester.pumpWidget(
        confirm(bloc, trigger: PayoutTrigger.delivery, mode: null),
      );
      await tester.pump();
      expect(find.text('Départ enregistrée'), findsOneWidget);
      expect(find.text('Dépôt enregistré'), findsNothing);
    });

    testWidgets('anglais', (tester) async {
      useEnglish();
      final bloc = _MockTrackingBloc();
      whenListen(
        bloc,
        const Stream<TrackingState>.empty(),
        initialState: TrackingInitial(),
      );
      await tester.pumpWidget(confirm(bloc));
      await tester.pump();
      expect(find.text('Drop-off recorded'), findsOneWidget);
      expect(find.text('Drop-off at the warehouse'), findsOneWidget);
    });
  });
}
