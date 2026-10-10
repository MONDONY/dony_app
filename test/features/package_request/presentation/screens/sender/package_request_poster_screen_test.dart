import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_cubit.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/screens/sender/package_request_poster_screen.dart';
import 'package:dony/features/package_request/presentation/widgets/poster/package_request_poster_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockDetailCubit extends MockCubit<PackageRequestDetailState>
    implements PackageRequestDetailCubit {}

PackageRequest _request({double? gross = 45, bool negotiable = true}) =>
    PackageRequest(
      id: 'r1',
      senderId: 's1',
      departureCity: 'Lyon',
      arrivalCity: 'Abidjan',
      desiredDate: DateTime(2026, 10, 23),
      dateToleranceDays: 3,
      weightKg: 8,
      parcelSize: ParcelSize.medium,
      transportMode: TransportMode.plane,
      categories: const ['Vêtements', 'Chaussures'],
      grossPriceEur: gross,
      negotiable: negotiable,
      acceptedPaymentMethods: const {PaymentMethod.stripe},
      pickupNeighborhood: 'Guillotière',
      deliveryNeighborhood: 'Cocody',
      status: PackageRequestStatus.open,
      createdAt: DateTime(2026, 10),
    );

const _base = 'https://api.yadony.test/api/v1';

Future<void> _pumpScreen(WidgetTester tester, {PackageRequest? request}) =>
    tester.pumpWidget(
      MaterialApp(
        home: PackageRequestPosterScreen(
          request: request ?? _request(),
          shareBaseUrl: _base,
          captureOverride: () async => Uint8List.fromList([1, 2, 3]),
        ),
      ),
    );

Future<void> _tapAction(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(
  WidgetTester tester,
  PackageRequestDetailState state, {
  PackageRequest? initial,
}) async {
  final cubit = _MockDetailCubit();
  whenListen(
    cubit,
    const Stream<PackageRequestDetailState>.empty(),
    initialState: state,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<PackageRequestDetailCubit>.value(
        value: cubit,
        child: PackageRequestPosterRoute(initial: initial),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  late List<String> copied;
  late List<MethodCall> galCalls;
  late bool galAccess;

  setUp(() {
    // Même message d'erreur d'un test à l'autre : sans remise à zéro, la
    // déduplication de 400 ms des snackbars l'avale.
    DonySnackbar.clearDedup();
    copied = <String>[];
    galCalls = <MethodCall>[];
    galAccess = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('gal'), (
      call,
    ) async {
      galCalls.add(call);
      if (call.method == 'requestAccess') return galAccess;
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(const MethodChannel('gal'), null);
  });

  group('écran', () {
    testWidgets('montre l\'affiche et les quatre actions', (tester) async {
      await _pumpScreen(tester);

      expect(find.byType(PackageRequestPosterCard), findsOneWidget);
      expect(find.byKey(const Key('poster-qr')), findsOneWidget);
      expect(find.text('Partager l\'affiche'), findsOneWidget);
      expect(find.text('Copier la légende'), findsOneWidget);
      expect(find.text('Copier le lien'), findsOneWidget);
      expect(find.text('Enregistrer dans la galerie'), findsOneWidget);
    });

    testWidgets('copie le lien public de la demande, canal « lien »', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await _tapAction(tester, 'Copier le lien');

      expect(copied, ['$_base/demande/r1?c=lien']);
      expect(find.text('Lien copié'), findsOneWidget);
    });

    testWidgets('la légende reprend la demande et porte le lien', (
      tester,
    ) async {
      await _pumpScreen(tester);

      await _tapAction(tester, 'Copier la légende');

      final caption = copied.single;
      expect(caption, contains('📦 Colis Lyon → Abidjan'));
      expect(
        caption,
        contains('📅 Autour du vendredi 23 octobre, à 3 jours près'),
      );
      expect(caption, contains('⚖️ 8 kg, format moyen'));
      expect(caption, contains('Contenu : Vêtements, Chaussures'));
      expect(
        caption,
        contains('Budget ${formatPriceIn(45, 'EUR')}, négociable'),
      );
      expect(caption, contains('Départ : Lyon, Guillotière'));
      expect(caption, contains('Arrivée : Abidjan, Cocody'));
      expect(caption, contains('$_base/demande/r1?c=post'));
    });

    testWidgets('la légende omet le budget quand il n\'y en a pas', (
      tester,
    ) async {
      await _pumpScreen(tester, request: _request(gross: null));

      await _tapAction(tester, 'Copier la légende');

      expect(copied.single, isNot(contains('Budget')));
    });

    testWidgets('enregistre l\'affiche dans la galerie', (tester) async {
      await _pumpScreen(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      final put = galCalls.where((c) => c.method == 'putImageBytes');
      expect(put, hasLength(1));
      expect(
        find.text('Affiche enregistrée dans votre galerie'),
        findsOneWidget,
      );
    });

    testWidgets('galerie refusée : message d\'erreur', (tester) async {
      galAccess = false;
      await _pumpScreen(tester);

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(galCalls.map((c) => c.method), isNot(contains('putImageBytes')));
      expect(find.text('Impossible d\'enregistrer l\'affiche'), findsOneWidget);
    });

    testWidgets('capture impossible : message d\'erreur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PackageRequestPosterScreen(
            request: _request(),
            shareBaseUrl: _base,
            captureOverride: () async => null,
          ),
        ),
      );

      await _tapAction(tester, 'Enregistrer dans la galerie');

      expect(find.text('Impossible d\'enregistrer l\'affiche'), findsOneWidget);
    });
  });

  group('route', () {
    testWidgets('rend immédiatement quand la demande est fournie', (
      tester,
    ) async {
      await _pumpRoute(
        tester,
        const PackageRequestDetailLoading(),
        initial: _request(),
      );

      expect(find.byType(PackageRequestPosterCard), findsOneWidget);
    });

    testWidgets('résout la demande depuis le cubit sans extra', (tester) async {
      await _pumpRoute(
        tester,
        PackageRequestDetailLoaded(request: _request(), threads: const []),
      );

      expect(find.byType(PackageRequestPosterCard), findsOneWidget);
    });

    testWidgets('patiente pendant le chargement', (tester) async {
      await _pumpRoute(tester, const PackageRequestDetailLoading());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PackageRequestPosterCard), findsNothing);
    });

    testWidgets('montre un état d\'erreur exploitable', (tester) async {
      await _pumpRoute(tester, const PackageRequestDetailError(notFound: true));

      expect(find.text('Demande introuvable'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
