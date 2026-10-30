// « Votre trajet » de l'écran du trajet (vue du voyageur propriétaire) :
// fonction pure des tuiles pour chaque statut du trajet, avec ou sans
// adresses, date limite, moyens de paiement, conditions, instructions de
// retrait et colis arrivés ; icônes, titres et résumés FR / EN.
import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_tiles.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _statuses = [
  'DRAFT',
  'ACTIVE',
  'FULL',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'REMOVED_BY_ADMIN',
  'SOMETHING_NEW',
];

const _pickup = AddressData(
  label: '12 rue de Paris, 75001',
  lat: 48.85,
  lng: 2.35,
  city: 'Paris',
);
const _delivery = AddressData(
  label: 'Marché de Treichville',
  lat: 5.3,
  lng: -4.0,
  city: 'Abidjan',
);

AnnouncementModel _trip({
  String status = 'ACTIVE',
  AddressData? pickup,
  AddressData? delivery,
  DateTime? deadline,
  Set<BidPaymentMethod> methods = const {},
  List<String>? accepted,
  List<String>? refused,
  String? description,
  String? instructions,
}) {
  final now = DateTime(2026, 10, 30);
  return AnnouncementModel(
    id: 'trip-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Abidjan',
    departureDate: now.add(const Duration(days: 3)),
    availableKg: 20,
    totalKg: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
    pickupAddress: pickup,
    deliveryAddress: delivery,
    handoverDeadline: deadline,
    departureTimezone: 'Europe/Paris',
    acceptedPaymentMethods: methods,
    acceptedContentTypes: accepted,
    refusedTypes: refused,
    description: description,
    arrivalInstructions: instructions,
  );
}

/// Trajet complet : chaque section a quelque chose à montrer.
AnnouncementModel _full({String status = 'ACTIVE', String? instructions}) =>
    _trip(
      status: status,
      pickup: _pickup,
      delivery: _delivery,
      deadline: DateTime.utc(2026, 11, 2, 17),
      methods: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
      accepted: const ['CLOTHING', 'DOCUMENTS', 'FOOD'],
      refused: const ['LIQUIDS', 'BATTERIES'],
      description: 'Pas de fragile',
      instructions: instructions,
    );

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Vraies polices de l'app, pour mesurer les résumés comme à l'écran.
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await _loadAppFonts();
  });

  test('noms de l\'enum figés (valeur `tile` des mesures)', () {
    expect(TripTile.values.map((t) => t.name), [
      'itinerary',
      'payments',
      'conditions',
      'poster',
      'arrival',
    ]);
  });

  group('tripTilesFor par statut', () {
    for (final status in _statuses) {
      test('$status, trajet complet, sans arrivée', () {
        expect(
          tripTilesFor(
            isOwner: true,
            trip: _full(status: status),
            bids: const [],
          ),
          [
            TripTile.itinerary,
            TripTile.payments,
            TripTile.conditions,
            if (status == 'ACTIVE') TripTile.poster,
          ],
        );
      });

      test(
        '$status, trajet vide : rien à montrer, aucune tuile hors affiche',
        () {
          expect(
            tripTilesFor(
              isOwner: true,
              trip: _trip(status: status),
              bids: null,
            ),
            [if (status == 'ACTIVE') TripTile.poster],
          );
        },
      );

      test('$status, instructions de retrait : tuile Arrivée', () {
        expect(
          tripTilesFor(
            isOwner: true,
            trip: _trip(status: status, instructions: 'Au marché, 18 h'),
            bids: null,
          ),
          [if (status == 'ACTIVE') TripTile.poster, TripTile.arrival],
        );
      });

      test('$status, colis ARRIVED sans instructions : tuile Arrivée', () {
        expect(
          tripTilesFor(
            isOwner: true,
            trip: _trip(status: status),
            bids: [_bid('b1', 'ARRIVED')],
          ),
          contains(TripTile.arrival),
        );
      });
    }
  });

  group('itinerary', () {
    test('dépôt seul, récupération seule, date limite seule', () {
      for (final trip in [
        _trip(pickup: _pickup),
        _trip(delivery: _delivery),
        _trip(deadline: DateTime.utc(2026, 11, 2, 17)),
      ]) {
        expect(
          tripTilesFor(isOwner: true, trip: trip, bids: null),
          contains(TripTile.itinerary),
        );
      }
    });

    test('adresses et date limite absentes : pas de tuile', () {
      expect(
        tripTilesFor(isOwner: true, trip: _trip(status: 'FULL'), bids: null),
        isNot(contains(TripTile.itinerary)),
      );
    });
  });

  group('payments', () {
    test('au moins un moyen : tuile ; aucun : pas de tuile', () {
      expect(
        tripTilesFor(
          isOwner: true,
          trip: _trip(methods: const {BidPaymentMethod.cash}),
          bids: null,
        ),
        contains(TripTile.payments),
      );
      expect(
        tripTilesFor(isOwner: true, trip: _trip(), bids: null),
        isNot(contains(TripTile.payments)),
      );
    });
  });

  group('conditions', () {
    test('accepté seul, refusé seul, note seule : tuile', () {
      for (final trip in [
        _trip(accepted: const ['CLOTHING']),
        _trip(refused: const ['LIQUIDS']),
        _trip(description: 'Merci'),
      ]) {
        expect(
          tripTilesFor(isOwner: true, trip: trip, bids: null),
          contains(TripTile.conditions),
        );
      }
    });

    test('listes vides et note vide : pas de tuile', () {
      expect(
        tripTilesFor(
          isOwner: true,
          trip: _trip(accepted: const [], refused: const [], description: ''),
          bids: null,
        ),
        isNot(contains(TripTile.conditions)),
      );
    });
  });

  test('note faite d\'espaces : ni tuile ni résumé « Note »', () {
    final blank = _trip(description: '  \n ');
    expect(
      tripTilesFor(isOwner: true, trip: blank, bids: null),
      isNot(contains(TripTile.conditions)),
    );
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(tripTileSubtitle(fr, TripTile.conditions, blank), isNull);
    // Avec des listes, la note blanche n'ajoute rien au résumé.
    expect(
      tripTileSubtitle(
        fr,
        TripTile.conditions,
        _trip(accepted: const ['CLOTHING'], description: '   '),
      ),
      '1 type accepté',
    );
  });

  group('non propriétaire', () {
    for (final status in _statuses) {
      test('$status : aucune tuile, même avec tout à montrer', () {
        expect(
          tripTilesFor(
            isOwner: false,
            trip: _full(status: status, instructions: 'Au marché'),
            bids: [_bid('b1', 'ARRIVED')],
          ),
          isEmpty,
        );
      });
    }
  });

  group('arrival', () {
    test('instructions blanches et aucun colis arrivé : pas de tuile', () {
      expect(
        tripTilesFor(
          isOwner: true,
          trip: _trip(instructions: '   '),
          bids: [_bid('b1', 'IN_TRANSIT'), _bid('b2', 'COMPLETED')],
        ),
        isNot(contains(TripTile.arrival)),
      );
    });

    test('colis pas encore chargés : seules les instructions comptent', () {
      expect(
        tripTilesFor(isOwner: true, trip: _trip(), bids: null),
        isNot(contains(TripTile.arrival)),
      );
    });

    test('tripHasArrivedParcel', () {
      expect(tripHasArrivedParcel(null), isFalse);
      expect(tripHasArrivedParcel(const []), isFalse);
      expect(tripHasArrivedParcel([_bid('b1', 'HANDED_OVER')]), isFalse);
      expect(
        tripHasArrivedParcel([
          _bid('b1', 'HANDED_OVER'),
          _bid('b2', 'ARRIVED'),
        ]),
        isTrue,
      );
    });
  });

  test('ordre de la grille', () {
    expect(
      tripTilesFor(
        isOwner: true,
        trip: _full(instructions: 'Au marché'),
        bids: [_bid('b1', 'ARRIVED')],
      ),
      TripTile.values,
    );
  });

  test('icônes', () {
    expect(TripTile.values.map(tripTileIcon), [
      'route',
      'credit-card',
      'clipboard-check',
      'share-2',
      'flag',
    ]);
  });

  group('titres et résumés', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('titres FR et EN', () {
      expect(TripTile.values.map((t) => tripTileTitle(fr, t)), [
        'Itinéraire et lieux',
        'Paiements',
        'Conditions',
        'Affiche',
        'Arrivée',
      ]);
      expect(TripTile.values.map((t) => tripTileTitle(en, t)), [
        'Route and places',
        'Payments',
        'Conditions',
        'Poster',
        'Arrival',
      ]);
    });

    test('itinerary : villes des lieux, à défaut le libellé', () {
      expect(
        tripTileSubtitle(fr, TripTile.itinerary, _full()),
        'Remise : Paris · Retrait : Abidjan',
      );
      expect(
        tripTileSubtitle(en, TripTile.itinerary, _full()),
        'Drop-off: Paris · Pickup: Abidjan',
      );
      const noCity = AddressData(label: 'Gare de Lyon', lat: 1, lng: 1);
      expect(
        tripTileSubtitle(fr, TripTile.itinerary, _trip(pickup: noCity)),
        'Remise : Gare de Lyon',
      );
      expect(
        tripTileSubtitle(fr, TripTile.itinerary, _trip(delivery: _delivery)),
        'Retrait : Abidjan',
      );
    });

    test(
      'itinerary : sans lieu, la date limite de dépôt (heure de départ)',
      () {
        final trip = _trip(deadline: DateTime.utc(2026, 11, 2, 17));
        final subtitle = tripTileSubtitle(fr, TripTile.itinerary, trip)!;
        expect(subtitle, startsWith("Jusqu'au"));
        expect(subtitle, contains('18:00'));
        expect(tripTileSubtitle(fr, TripTile.itinerary, _trip()), isNull);
      },
    );

    test('payments : moyens acceptés, marques en clair', () {
      expect(
        tripTileSubtitle(
          fr,
          TripTile.payments,
          _trip(
            methods: const {
              BidPaymentMethod.stripe,
              BidPaymentMethod.cash,
              BidPaymentMethod.mobileMoney,
            },
          ),
        ),
        'Carte, Espèces, Mobile money',
      );
      expect(
        tripTileSubtitle(
          en,
          TripTile.payments,
          _trip(
            methods: const {
              BidPaymentMethod.cash,
              BidPaymentMethod.wave,
              BidPaymentMethod.orangeMoney,
            },
          ),
        ),
        'Cash, Wave, Orange Money',
      );
      expect(tripTileSubtitle(fr, TripTile.payments, _trip()), isNull);
    });

    test('conditions : nombres, pluriel, ou la note seule', () {
      expect(
        tripTileSubtitle(fr, TripTile.conditions, _full()),
        '3 types acceptés · 2 types refusés',
      );
      expect(
        tripTileSubtitle(en, TripTile.conditions, _full()),
        '3 types accepted · 2 types refused',
      );
      expect(
        tripTileSubtitle(
          fr,
          TripTile.conditions,
          _trip(accepted: const ['CLOTHING']),
        ),
        '1 type accepté',
      );
      expect(
        tripTileSubtitle(
          fr,
          TripTile.conditions,
          _trip(refused: const ['LIQUIDS']),
        ),
        '1 type refusé',
      );
      expect(
        tripTileSubtitle(fr, TripTile.conditions, _trip(description: 'Merci')),
        'Note aux expéditeurs',
      );
      expect(tripTileSubtitle(fr, TripTile.conditions, _trip()), isNull);
    });

    test('poster et arrival', () {
      expect(
        tripTileSubtitle(fr, TripTile.poster, _trip()),
        'Partager le trajet',
      );
      expect(tripTileSubtitle(en, TripTile.poster, _trip()), 'Share the trip');
      expect(
        tripTileSubtitle(fr, TripTile.arrival, _trip()),
        'Instructions de retrait',
      );
      expect(
        tripTileSubtitle(en, TripTile.arrival, _trip()),
        'Pickup instructions',
      );
    });

    test('aucun tiret cadratin dans les textes', () {
      for (final l in [fr, en]) {
        final texts = [
          for (final t in TripTile.values) tripTileTitle(l, t),
          for (final t in TripTile.values)
            tripTileSubtitle(l, t, _full(instructions: 'x')) ?? '',
          l.tripTilePosterIntro,
          l.tripTileArrivalEmpty,
          l.tripTilePaymentsNetworksTitle,
          l.tripTilePaymentsCashOnlyNote(l.bidDetailSectionTodo),
        ];
        for (final text in texts) {
          expect(text, isNot(contains('—')), reason: text);
        }
      }
    });
  });

  // Résumés les plus longs (villes à rallonge, deux segments) dans la
  // demi-largeur d'une grille à 360 dp, texte × 1,3 : jamais de débordement
  // (deux lignes au plus, puis points de suspension).
  group('grille à 360 dp, texte × 1,3', () {
    const longPickup = AddressData(
      label: '128 boulevard de la Villette, 75019 Paris',
      lat: 48.88,
      lng: 2.37,
      city: 'Saint-Rémy-lès-Chevreuse',
    );
    const longDelivery = AddressData(
      label: 'Marché de Treichville',
      lat: 5.3,
      lng: -4.0,
      city: 'Yamoussoukro-Attiégouakro',
    );
    final trip = _trip(
      pickup: longPickup,
      delivery: longDelivery,
      methods: const {
        BidPaymentMethod.stripe,
        BidPaymentMethod.cash,
        BidPaymentMethod.mobileMoney,
      },
      accepted: const ['CLOTHING', 'DOCUMENTS', 'FOOD', 'COSMETICS'],
      refused: const ['LIQUIDS', 'BATTERIES', 'FRAGILE'],
      instructions: 'Au marché',
    );

    for (final locale in const [Locale('fr'), Locale('en')]) {
      testWidgets('${locale.languageCode} : aucun débordement', (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(DonySpacing.lg),
                child: Builder(
                  builder: (context) {
                    final l = context.l10n;
                    return DonyActionTileGrid(
                      tiles: [
                        for (final tile in tripTilesFor(
                          isOwner: true,
                          trip: trip,
                          bids: [_bid('b1', 'ARRIVED')],
                        ))
                          DonyActionTile(
                            iconName: tripTileIcon(tile),
                            label: tripTileTitle(l, tile),
                            subtitle: tripTileSubtitle(l, tile, trip),
                            color: Theme.of(context).colorScheme.primary,
                            onTap: () {},
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.byType(DonyActionTile), findsNWidgets(5));
      });
    }
  });
}
