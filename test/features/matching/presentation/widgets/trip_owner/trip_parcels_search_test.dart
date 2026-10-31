// Recherche d'un colis du sheet « Colis » de l'écran du trajet (fonction
// pure) : casse, accents, espaces, tirets du numéro de suivi, sous-chaîne,
// expéditeur, destinataire, numéro visible seulement à partir de la remise
// (aucune fuite par la recherche), destinataire masqué en refus.
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_parcels_search.dart';
import 'package:dony/l10n/generated/app_localizations_en.dart';
import 'package:dony/l10n/generated/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

final _fr = AppLocalizationsFr();
final _en = AppLocalizationsEn();

BidModel _bid(
  String id, {
  String status = 'IN_TRANSIT',
  String? sender = 'Aminata Traoré',
  String? recipient = 'Moussa Diallo',
  String? tracking = 'DON-BGA8WV2R',
  bool declined = false,
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: sender,
  recipientName: recipient,
  recipientDeclined: declined,
  trackingNumber: tracking,
  status: status,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

bool _m(BidModel b, String q) => tripParcelMatches(_fr, b, q);

/// Statuts où le voyageur voit le numéro (à partir de la remise).
const _visible = ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED', 'COMPLETED'];

/// Statuts de colis embarqués où le numéro est masqué au voyageur.
const _hidden = [
  'ACCEPTED',
  'AWAITING_PAYMENT',
  'NO_SHOW',
  'PARCEL_REFUSED',
  'CANCELLED',
];

void main() {
  group('tripParcelsSearchKey', () {
    test('espaces de bord retirés, intérieurs réduits, minuscules, sans '
        'accents', () {
      expect(tripParcelsSearchKey('  Éloïse   Traoré  '), 'eloise traore');
      expect(tripParcelsSearchKey('   '), '');
      expect(tripParcelsSearchKey(''), '');
      expect(tripParcelsSearchKey('\tA\nB '), 'a b');
    });
  });

  group('recherche vide', () {
    test('vide ou espaces seuls : tout colis répond', () {
      final b = _bid('a', status: 'ACCEPTED', sender: null, recipient: null);
      for (final q in ['', ' ', '   \t ']) {
        expect(_m(b, q), isTrue, reason: '« $q »');
      }
      expect(tripParcelsMatching(_fr, [b, _bid('b')], '  '), hasLength(2));
    });
  });

  group('expéditeur', () {
    final b = _bid('a', status: 'ACCEPTED');

    test('casse, accents, sous-chaîne, espaces de bord', () {
      for (final q in [
        'Aminata',
        'aminata',
        'AMINATA',
        'traoré',
        'traore',
        'TRAORE',
        'nata tra',
        '  amin  ',
        'aminata   traore',
      ]) {
        expect(_m(b, q), isTrue, reason: q);
      }
      expect(_m(b, 'diakite'), isFalse);
    });

    test('accent saisi, nom sans accent', () {
      expect(_m(_bid('a', sender: 'Helene Kone'), 'Hélène Koné'), isTrue);
    });

    test('nom absent : le repli affiché (« Expéditeur » / « Sender »)', () {
      final anon = _bid('a', sender: null, recipient: null, tracking: null);
      expect(_m(anon, 'expediteur'), isTrue);
      expect(tripParcelMatches(_en, anon, 'sender'), isTrue);
      expect(_m(anon, 'aminata'), isFalse);
    });
  });

  group('destinataire', () {
    test('trouvé par son nom, sans casse ni accents, sous-chaîne', () {
      final b = _bid('a', status: 'ACCEPTED', recipient: 'Fatoumata Bâ');
      for (final q in ['fatou', 'FATOUMATA BA', 'bâ', ' toumata ']) {
        expect(_m(b, q), isTrue, reason: q);
      }
    });

    test('destinataire en refus : jamais trouvé par son nom (masqué au '
        'voyageur)', () {
      final b = _bid('a', declined: true);
      expect(_m(b, 'moussa'), isFalse);
      expect(_m(b, 'aminata'), isTrue);
    });

    test('sans destinataire : rien ne casse', () {
      expect(_m(_bid('a', recipient: null), 'moussa'), isFalse);
    });
  });

  group('numéro de suivi', () {
    test('colis remis : trouvé sans casse, avec ou sans tirets ni espaces, '
        'en partie', () {
      for (final status in _visible) {
        final b = _bid('a', status: status, sender: 'X', recipient: 'Y');
        for (final q in [
          'DON-BGA8WV2R',
          'don-bga8wv2r',
          'donbga8wv2r',
          'bga8',
          'BGA8WV',
          'don bga8',
          ' don-bga8wv2r ',
          'bga8-wv2r',
          'n-b',
        ]) {
          expect(_m(b, q), isTrue, reason: '$status « $q »');
        }
        expect(_m(b, 'zzz9'), isFalse, reason: status);
      }
    });

    test('numéro tapé avec un tiret typographique', () {
      final b = _bid('a', sender: 'X', recipient: 'Y');
      expect(_m(b, 'DON–BGA8'), isTrue);
    });

    test(
      'colis non remis : le numéro ne trouve jamais rien (pas de fuite)',
      () {
        for (final status in _hidden) {
          final b = _bid('a', status: status, sender: 'X', recipient: 'Y');
          for (final q in ['DON-BGA8WV2R', 'bga8', 'donbga8wv2r', 'wv2r']) {
            expect(_m(b, q), isFalse, reason: '$status « $q »');
          }
          // Le nom reste cherchable.
          expect(_m(b, 'y'), isTrue, reason: status);
        }
      },
    );

    test('tirets ou espaces seuls : ne trouvent pas tous les numéros', () {
      final b = _bid('a', sender: 'X', recipient: 'Y');
      expect(_m(b, '-'), isFalse);
      expect(_m(b, ' - '), isFalse);
    });

    test('sans numéro servi : rien ne casse', () {
      expect(_m(_bid('a', tracking: null, sender: 'X'), 'don'), isFalse);
      expect(_m(_bid('a', tracking: '  ', sender: 'X'), 'don'), isFalse);
    });
  });

  group('tripParcelsMatching', () {
    test('garde l\'ordre reçu, trouve par chacun des trois champs', () {
      final parcels = [
        _bid('s', sender: 'Awa Ndiaye', recipient: 'R1', tracking: 'DON-AAA1'),
        _bid('r', sender: 'S2', recipient: 'Awa Sow', tracking: 'DON-BBB2'),
        _bid('t', sender: 'S3', recipient: 'R3', tracking: 'DON-AWA3'),
        _bid('n', sender: 'S4', recipient: 'R4', tracking: 'DON-CCC4'),
        _bid(
          'h',
          status: 'ACCEPTED',
          sender: 'S5',
          recipient: 'R5',
          tracking: 'DON-AWA5',
        ),
      ];
      expect(tripParcelsMatching(_fr, parcels, 'awa').map((b) => b.id), [
        's',
        'r',
        't',
      ]);
      expect(tripParcelsMatching(_fr, parcels, 'zz'), isEmpty);
      expect(tripParcelsMatching(_fr, parcels, ''), same(parcels));
    });
  });
}
