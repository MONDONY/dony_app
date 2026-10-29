// Bottom sheets des tuiles « Votre transport » de la fiche colis (vue
// voyageur) : titre, contenu, colis rechargé par le BidBloc de l'écran, mesure
// d'ouverture, absence de bouton hors `stickyBottom`, FR/EN, 360 dp et grand
// texte.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/recipient_replacement/recipient_replacement_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/address_location_row.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockLauncher extends Mock implements ExternalUrlLauncher {}

class _FakeUri extends Fake implements Uri {}

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

BidModel _bid({
  String id = 'bid-001',
  String status = 'IN_TRANSIT',
  String? recipientName = 'Awa',
  String? recipientPhone = '+221700000000',
  bool recipientPhoneHidden = false,
  bool recipientDeclined = false,
  String? recipientAppStatus,
  AddressData? handoverAddress = _handover,
  AddressData? deliveryAddress = _delivery,
  String? handoverLocation,
  String? arrivalInstructions,
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
  recipientPhoneHidden: recipientPhoneHidden,
  recipientDeclined: recipientDeclined,
  recipientAppStatus: recipientAppStatus,
  trackingToken: 'tok-abc123',
  departureCity: 'Paris',
  arrivalCity: 'Bamako',
  handoverAddress: handoverAddress,
  deliveryAddress: deliveryAddress,
  handoverLocation: handoverLocation,
  arrivalInstructions: arrivalInstructions,
);

void main() {
  late MockAnalyticsBackend backend;
  late _MockBidBloc bidBloc;

  setUpAll(() async {
    registerFallbackValue(_FakeUri());
    registerFallbackValue(BidDetailRequested('fallback'));
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
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
    final launcher = _MockLauncher();
    when(() => launcher.open(any())).thenAnswer((_) async => true);
    final conversation = _MockConversationOpenBloc();
    when(() => conversation.state).thenReturn(const ConversationOpenInitial());
    when(
      () => conversation.stream,
    ).thenAnswer((_) => const Stream<ConversationOpenState>.empty());

    await getIt.reset();
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<ExternalUrlLauncher>(launcher)
      ..registerFactory<ConversationOpenBloc>(() => conversation)
      ..registerFactory<RecipientReplacementCubit>(
        () => RecipientReplacementCubit(_MockBidRepository(), analytics),
      );
  });

  tearDown(() async => getIt.reset());

  Future<void> openTile(
    WidgetTester tester,
    BidModel bid,
    TravelerTile tile, {
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
        home: Builder(
          builder: (context) {
            final screen = Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openTravelerTileSheet(context, bid, tile),
                  child: const Text('open-tile'),
                ),
              ),
            );
            return withBidBloc
                ? BlocProvider<BidBloc>.value(value: bidBloc, child: screen)
                : screen;
          },
        ),
      ),
    );
    await tester.tap(find.text('open-tile'));
    await tester.pumpAndSettle();
  }

  group('titre de chaque tuile', () {
    for (final (locale, tile, title) in [
      (const Locale('fr'), TravelerTile.lieux, 'Lieux'),
      (const Locale('fr'), TravelerTile.colis, 'Colis et destinataire'),
      (const Locale('fr'), TravelerTile.details, 'Plus de détails'),
      (const Locale('en'), TravelerTile.lieux, 'Places'),
      (const Locale('en'), TravelerTile.colis, 'Parcel and recipient'),
      (const Locale('en'), TravelerTile.details, 'More details'),
    ]) {
      testWidgets('${tile.name} (${locale.languageCode}) : "$title"', (
        tester,
      ) async {
        await openTile(tester, _bid(), tile, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.text(title), findsOneWidget);
      });
    }
  });

  group('aucun bouton hors stickyBottom', () {
    for (final tile in TravelerTile.values) {
      testWidgets('${tile.name} : ni DonyButton ni pied de feuille', (
        tester,
      ) async {
        await openTile(tester, _bid(), tile);

        expect(find.byType(DonyButton), findsNothing);
        expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
      });
    }
  });

  group('lieux', () {
    testWidgets('montre les deux adresses, sans carte Google Maps', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.lieux);

      expect(find.byKey(const Key('traveler-place-handover')), findsOneWidget);
      expect(find.byKey(const Key('traveler-place-delivery')), findsOneWidget);
      expect(find.text(_handover.label), findsOneWidget);
      expect(find.text(_delivery.label), findsOneWidget);
      expect(find.text('Remise du colis'), findsOneWidget);
      expect(find.text('Récupération'), findsOneWidget);
      expect(find.byType(AddressPointMiniMap), findsNothing);
      expect(find.byType(ParcelLocationsCard), findsNothing);
    });

    testWidgets('une adresse ouvre l\'app Cartes au tap', (tester) async {
      await openTile(tester, _bid(), TravelerTile.lieux);

      await tester.tap(find.byKey(const Key('traveler-place-delivery')));
      await tester.pump();

      final uri =
          verify(
                () => getIt<ExternalUrlLauncher>().open(captureAny()),
              ).captured.single
              as Uri;
      expect(uri.toString(), isNotEmpty);
    });

    testWidgets('consignes de retrait : affichées quand elles existent', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(arrivalInstructions: 'Sonner deux fois'),
        TravelerTile.lieux,
      );

      expect(find.byType(ArrivalInstructionsCard), findsOneWidget);
      expect(find.text('Sonner deux fois'), findsOneWidget);
    });

    testWidgets('sans consigne : pas de carte de consignes', (tester) async {
      await openTile(tester, _bid(), TravelerTile.lieux);

      expect(find.byType(ArrivalInstructionsCard), findsNothing);
    });

    testWidgets('dépôt en simple texte (ancien colis sans adresse)', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(
          handoverAddress: null,
          deliveryAddress: null,
          handoverLocation: 'Gare de Lyon, hall 2',
        ),
        TravelerTile.lieux,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Gare de Lyon, hall 2'), findsOneWidget);
      expect(find.byKey(const Key('traveler-place-delivery')), findsNothing);
    });

    testWidgets('seule la récupération est connue', (tester) async {
      await openTile(tester, _bid(handoverAddress: null), TravelerTile.lieux);

      expect(find.byKey(const Key('traveler-place-handover')), findsNothing);
      expect(find.byKey(const Key('traveler-place-delivery')), findsOneWidget);
    });
  });

  group('colis', () {
    testWidgets('contenu : ColisDestinataireCard sans cadre', (tester) async {
      await openTile(tester, _bid(), TravelerTile.colis);

      final card = tester.widget<ColisDestinataireCard>(
        find.byType(ColisDestinataireCard),
      );
      expect(card.isSender, isFalse);
      expect(card.framed, isFalse);
      expect(find.text('Awa'), findsOneWidget);
    });

    testWidgets('IN_TRANSIT avec numéro : le contact du destinataire suit', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.colis);

      expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
      expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
      expect(find.text('+221700000000'), findsOneWidget);
    });

    testWidgets('ACCEPTED : note d\'attente, ni numéro ni carte de contact', (
      tester,
    ) async {
      await openTile(tester, _bid(status: 'ACCEPTED'), TravelerTile.colis);

      expect(find.byType(TravelerRecipientContactCard), findsNothing);
      expect(find.byType(TravelerRecipientContactPendingNote), findsOneWidget);
      expect(find.text('+221700000000'), findsNothing);
    });

    for (final status in ['PENDING', 'PAYMENT_ESCROWED', 'AWAITING_PAYMENT']) {
      testWidgets('$status (avant acceptation) : aucun contact destinataire', (
        tester,
      ) async {
        await openTile(tester, _bid(status: status), TravelerTile.colis);

        expect(find.byType(TravelerRecipientContactCard), findsNothing);
        expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
        expect(find.text('+221700000000'), findsNothing);
      });
    }

    for (final status in ['HANDED_OVER', 'ARRIVED', 'COMPLETED']) {
      testWidgets('$status : le contact du destinataire est visible', (
        tester,
      ) async {
        await openTile(tester, _bid(status: status), TravelerTile.colis);

        expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
      });
    }

    testWidgets('numéro masqué sans compte Yadony : « masqué », pas de canal', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(recipientPhone: null, recipientPhoneHidden: true),
        TravelerTile.colis,
      );

      expect(find.byType(TravelerRecipientContactCard), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('fr')).recipientPhoneHiddenLabel,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'numéro masqué mais destinataire dans l\'app : carte de contact '
      'sans canal téléphonique',
      (tester) async {
        await openTile(
          tester,
          _bid(
            recipientPhone: null,
            recipientPhoneHidden: true,
            recipientAppStatus: 'CONFIRMED',
          ),
          TravelerTile.colis,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
        expect(
          find.byKey(const Key('recipient-contact-whatsapp-bid-001')),
          findsNothing,
        );
      },
    );

    testWidgets('destinataire refusé : panneau « à redésigner », ni nom ni '
        'contact', (tester) async {
      await openTile(
        tester,
        _bid(
          recipientName: null,
          recipientPhone: null,
          recipientDeclined: true,
        ),
        TravelerTile.colis,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Destinataire à redésigner'), findsOneWidget);
      expect(find.text('Demander un autre destinataire'), findsOneWidget);
      expect(find.byType(TravelerRecipientContactCard), findsNothing);
      expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
    });

    testWidgets('destinataire refusé en ACCEPTED : pas de note d\'attente', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(
          status: 'ACCEPTED',
          recipientName: null,
          recipientPhone: null,
          recipientDeclined: true,
        ),
        TravelerTile.colis,
      );

      expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
      expect(find.text('Destinataire à redésigner'), findsOneWidget);
    });

    testWidgets('le panneau lit le BidBloc de l\'écran', (tester) async {
      await openTile(
        tester,
        _bid(
          recipientName: null,
          recipientPhone: null,
          recipientDeclined: true,
        ),
        TravelerTile.colis,
      );

      final inSheet = tester.element(find.byType(ColisDestinataireCard));
      expect(inSheet.read<BidBloc>(), same(bidBloc));
    });
  });

  group('details', () {
    testWidgets('contenu : BidDetailsContent sans lien de suivi', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.details);

      final content = tester.widget<BidDetailsContent>(
        find.byType(BidDetailsContent),
      );
      expect(content.showTrackingLink, isFalse);
      // Même avec un `trackingToken`, le voyageur ne voit jamais le lien.
      expect(find.text('LIEN DE SUIVI'), findsNothing);
      // Sans numéro de suivi servi : « Référence », début de l'identifiant.
      expect(find.text('Référence'), findsOneWidget);
      expect(find.text('BID-001'), findsOneWidget);
    });
  });

  group('colis courant', () {
    late StreamController<BidState> states;

    setUp(() {
      states = StreamController<BidState>.broadcast();
      addTearDown(states.close);
      whenListen(bidBloc, states.stream, initialState: BidInitial());
    });

    testWidgets('Colis : le nouveau destinataire après un BidDetailLoaded', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.colis);
      expect(find.text('Awa'), findsOneWidget);

      states.add(BidDetailLoaded(_bid(recipientName: 'Fatou')));
      await tester.pumpAndSettle();

      expect(find.text('Fatou'), findsOneWidget);
      expect(find.text('Awa'), findsNothing);
    });

    testWidgets('Colis : ACCEPTED → HANDED_OVER fait apparaître le contact', (
      tester,
    ) async {
      await openTile(tester, _bid(status: 'ACCEPTED'), TravelerTile.colis);
      expect(find.byType(TravelerRecipientContactPendingNote), findsOneWidget);

      states.add(BidDetailLoaded(_bid(status: 'HANDED_OVER')));
      await tester.pumpAndSettle();

      expect(find.byType(TravelerRecipientContactCard), findsOneWidget);
      expect(find.byType(TravelerRecipientContactPendingNote), findsNothing);
    });

    testWidgets('Colis : le destinataire passe en refus', (tester) async {
      await openTile(tester, _bid(), TravelerTile.colis);

      states.add(
        BidDetailLoaded(
          _bid(
            recipientName: null,
            recipientPhone: null,
            recipientDeclined: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Destinataire à redésigner'), findsOneWidget);
      expect(find.byType(TravelerRecipientContactCard), findsNothing);
    });

    testWidgets('Lieux : la nouvelle adresse de récupération', (tester) async {
      await openTile(tester, _bid(), TravelerTile.lieux);

      states.add(
        BidDetailLoaded(
          _bid(
            deliveryAddress: const AddressData(
              label: 'Marché de Médine, Bamako',
              lat: 12.65,
              lng: -8,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marché de Médine, Bamako'), findsOneWidget);
      expect(find.text(_delivery.label), findsNothing);
    });

    testWidgets('Plus de détails : suit le colis rechargé', (tester) async {
      await openTile(tester, _bid(), TravelerTile.details);
      expect(find.text('Référence'), findsOneWidget);

      states.add(BidDetailLoaded(_bid(arrivalInstructions: 'Appeler Awa')));
      await tester.pumpAndSettle();

      expect(find.text('Appeler Awa'), findsOneWidget);
    });

    testWidgets('un BidDetailLoaded d\'un autre colis ne change rien', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.colis);

      states.add(
        BidDetailLoaded(_bid(recipientName: 'Fatou', id: 'bid-other')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awa'), findsOneWidget);
      expect(find.text('Fatou'), findsNothing);
    });

    testWidgets('sans BidBloc : rendu statique du colis d\'ouverture', (
      tester,
    ) async {
      await openTile(tester, _bid(), TravelerTile.colis, withBidBloc: false);

      expect(tester.takeException(), isNull);
      expect(find.text('Awa'), findsOneWidget);
    });

    testWidgets('sans BidBloc : le panneau de refus s\'affiche aussi', (
      tester,
    ) async {
      await openTile(
        tester,
        _bid(
          recipientName: null,
          recipientPhone: null,
          recipientDeclined: true,
        ),
        TravelerTile.colis,
        withBidBloc: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Destinataire à redésigner'), findsOneWidget);
    });
  });

  group('mesure', () {
    for (final tile in TravelerTile.values) {
      testWidgets('bid_detail_tile_opened avec tile et role (${tile.name})', (
        tester,
      ) async {
        await openTile(tester, _bid(), tile);

        verify(
          () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
            'tile': tile.name,
            'role': 'traveler',
          }),
        ).called(1);
      });
    }
  });

  group('rendu FR / EN, 360 dp, grand texte', () {
    final bids = {
      'colis accepté': _bid(status: 'ACCEPTED'),
      'colis en transit': _bid(),
      'destinataire refusé': _bid(
        recipientName: null,
        recipientPhone: null,
        recipientDeclined: true,
      ),
      'consignes longues': _bid(
        arrivalInstructions:
            'Sonner deux fois au portail bleu, demander Madame Diallo au '
            'deuxième étage, ne pas laisser le colis au gardien.',
      ),
    };
    for (final locale in const [Locale('fr'), Locale('en')]) {
      for (final scale in const [1.0, 1.3]) {
        for (final tile in TravelerTile.values) {
          for (final MapEntry(key: name, value: bid) in bids.entries) {
            testWidgets('${tile.name} / $name (${locale.languageCode}, '
                '×$scale)', (tester) async {
              await openTile(
                tester,
                bid,
                tile,
                locale: locale,
                textScale: scale,
                size: const Size(360, 800),
              );

              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}
