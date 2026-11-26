import 'package:dony/features/matching/presentation/widgets/bid_detail/next_action.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:flutter_test/flutter_test.dart';

NextActionInput _in(
  String status,
  ParcelRole role, {
  bool self = false,
  String traveler = 'Moussa',
  String sender = 'Awa',
  String recipient = 'Mariam',
  String city = 'Dakar',
  bool callable = true,
}) => NextActionInput(
  status: status,
  role: role,
  recipientIsSender: self,
  travelerName: traveler,
  senderName: sender,
  recipientName: recipient,
  arrivalCity: city,
  senderCallable: callable,
);

void main() {
  group('expéditeur', () {
    test('ACCEPTED : info, préparer la remise', () {
      final a = nextActionFor(_in('ACCEPTED', ParcelRole.sender))!;
      expect(a.tone, NextActionTone.info);
      expect(a.titleKey, 'nextActionSenderAcceptedTitle');
      expect(a.bodyKey, 'nextActionSenderAcceptedBody');
      expect(a.args['traveler'], 'Moussa');
      expect(a.args['recipient'], 'Mariam');
    });

    for (final s in ['HANDED_OVER', 'IN_TRANSIT']) {
      test('$s : action, envoyer le code', () {
        final a = nextActionFor(_in(s, ParcelRole.sender))!;
        expect(a.tone, NextActionTone.action);
        expect(a.titleKey, 'nextActionSenderCodeTitle');
        expect(a.bodyKey, 'nextActionSenderCodeBody');
      });
    }

    test('ARRIVED : action, voyageur arrivé à la ville', () {
      final a = nextActionFor(_in('ARRIVED', ParcelRole.sender))!;
      expect(a.tone, NextActionTone.action);
      expect(a.titleKey, 'nextActionSenderArrivedTitle');
      expect(a.bodyKey, 'nextActionSenderArrivedBody');
      expect(a.args['city'], 'Dakar');
    });

    test('COMPLETED : aucune carte', () {
      expect(nextActionFor(_in('COMPLETED', ParcelRole.sender)), isNull);
    });

    test('selfRecipient_sender_handedOver_titleIsKeepYourCode', () {
      for (final s in ['HANDED_OVER', 'IN_TRANSIT']) {
        final a = nextActionFor(_in(s, ParcelRole.sender, self: true))!;
        expect(a.titleKey, 'nextActionSelfKeepCodeTitle');
        expect(a.bodyKey, 'nextActionSelfKeepCodeBody');
      }
    });

    test('selfRecipient_sender_arrived_titleIsWithdrawYourParcel', () {
      final a = nextActionFor(_in('ARRIVED', ParcelRole.sender, self: true))!;
      expect(a.tone, NextActionTone.action);
      expect(a.titleKey, 'nextActionSelfWithdrawTitle');
      expect(a.bodyKey, 'nextActionSelfWithdrawBody');
    });

    test('selfRecipient_sender_accepted : texte « vous », pas de nom', () {
      final a = nextActionFor(_in('ACCEPTED', ParcelRole.sender, self: true))!;
      expect(a.tone, NextActionTone.info);
      expect(a.titleKey, 'nextActionSenderAcceptedTitle');
      expect(a.bodyKey, 'nextActionSelfAcceptedBody');
    });
  });

  group('voyageur', () {
    test('ACCEPTED : info, scanner le QR', () {
      final a = nextActionFor(_in('ACCEPTED', ParcelRole.traveler))!;
      expect(a.tone, NextActionTone.info);
      expect(a.titleKey, 'nextActionTravelerAcceptedTitle');
      expect(a.bodyKey, 'nextActionTravelerAcceptedBody');
      expect(a.args['sender'], 'Awa');
    });

    for (final s in ['HANDED_OVER', 'IN_TRANSIT']) {
      test('$s : info, rappel pour l\'arrivée', () {
        final a = nextActionFor(_in(s, ParcelRole.traveler))!;
        expect(a.tone, NextActionTone.info);
        expect(a.titleKey, 'nextActionTravelerTransitTitle');
        expect(a.bodyKey, 'nextActionTravelerTransitBody');
      });
    }

    test('ARRIVED : action, rien sans le code', () {
      final a = nextActionFor(_in('ARRIVED', ParcelRole.traveler))!;
      expect(a.tone, NextActionTone.action);
      expect(a.titleKey, 'nextActionTravelerArrivedTitle');
      expect(a.bodyKey, 'nextActionTravelerArrivedBody');
      expect(a.args['recipient'], 'Mariam');
      expect(a.args['sender'], 'Awa');
    });

    test('COMPLETED : aucune carte', () {
      expect(nextActionFor(_in('COMPLETED', ParcelRole.traveler)), isNull);
    });

    test('ARRIVED : sans numéro de l\'expéditeur, « contactez »', () {
      final a = nextActionFor(
        _in('ARRIVED', ParcelRole.traveler, callable: false),
      )!;
      expect(a.bodyKey, 'nextActionTravelerArrivedBodyContact');
      final b = nextActionFor(
        _in('ARRIVED', ParcelRole.traveler, callable: false, recipient: ''),
      )!;
      expect(b.bodyKey, 'nextActionTravelerArrivedBodyContact');
    });

    test('senderCallable ne change rien hors ARRIVED', () {
      for (final s in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT']) {
        expect(
          nextActionFor(_in(s, ParcelRole.traveler, callable: false))!.bodyKey,
          nextActionFor(_in(s, ParcelRole.traveler))!.bodyKey,
        );
      }
    });

    test('traveler_ignoresRecipientIsSender', () {
      for (final s in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
        final a = nextActionFor(_in(s, ParcelRole.traveler));
        final b = nextActionFor(_in(s, ParcelRole.traveler, self: true));
        expect(b!.titleKey, a!.titleKey, reason: s);
        expect(b.bodyKey, a.bodyKey, reason: s);
        expect(b.args, a.args, reason: s);
      }
    });
  });

  group('destinataire', () {
    test('ARRIVED : action, retirez votre colis', () {
      final a = nextActionFor(_in('ARRIVED', ParcelRole.recipient))!;
      expect(a.tone, NextActionTone.action);
      expect(a.titleKey, 'nextActionRecipientArrivedTitle');
      expect(a.bodyKey, 'nextActionRecipientArrivedBody');
      expect(a.args['traveler'], 'Moussa');
    });

    test('recipientBeforeArrived_returnsNull', () {
      for (final s in ['ACCEPTED', 'HANDED_OVER', 'IN_TRANSIT', 'COMPLETED']) {
        expect(nextActionFor(_in(s, ParcelRole.recipient)), isNull, reason: s);
      }
    });
  });

  test('outOfRailsStatuses_returnNull', () {
    const statuses = [
      'CANCELLED',
      'NO_SHOW',
      'PARCEL_REFUSED',
      'EXPIRED',
      'NEGOTIATING',
      'NEGOTIATION_CLOSED',
      'AWAITING_PAYMENT',
      'PENDING',
      'PAYMENT_ESCROWED',
      'REJECTED',
      'INCONNU',
    ];
    for (final s in statuses) {
      for (final r in ParcelRole.values) {
        expect(nextActionFor(_in(s, r)), isNull, reason: '$s $r');
        expect(nextActionFor(_in(s, r, self: true)), isNull, reason: '$s $r');
      }
    }
  });

  test(
    'emptyNames_useFallbackArgs : noms vides transmis vides, jamais null',
    () {
      final a = nextActionFor(
        _in(
          'ARRIVED',
          ParcelRole.sender,
          traveler: '  ',
          recipient: '',
          city: '',
        ),
      )!;
      expect(a.args['traveler'], '');
      expect(a.args['recipient'], '');
      expect(a.args['city'], '');
    },
  );
}
