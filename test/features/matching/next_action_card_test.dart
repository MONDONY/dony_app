import 'package:dony/features/matching/presentation/widgets/bid_detail/next_action.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/next_action_card.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NextAction _action(
  String status,
  ParcelRole role, {
  bool self = false,
  String traveler = 'Moussa',
  String sender = 'Awa',
  String recipient = 'Mariam',
  String city = 'Dakar',
}) => nextActionFor(
  NextActionInput(
    status: status,
    role: role,
    recipientIsSender: self,
    travelerName: traveler,
    senderName: sender,
    recipientName: recipient,
    arrivalCity: city,
  ),
)!;

Widget _app(NextAction a, Locale locale, Brightness b) => MaterialApp(
  locale: locale,
  theme: b == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: NextActionCard(action: a)),
  ),
);

const _combos = <(String, ParcelRole, bool)>[
  ('ACCEPTED', ParcelRole.sender, false),
  ('HANDED_OVER', ParcelRole.sender, false),
  ('ARRIVED', ParcelRole.sender, false),
  ('HANDED_OVER', ParcelRole.sender, true),
  ('ARRIVED', ParcelRole.sender, true),
  ('ACCEPTED', ParcelRole.traveler, false),
  ('IN_TRANSIT', ParcelRole.traveler, false),
  ('ARRIVED', ParcelRole.traveler, false),
  ('ARRIVED', ParcelRole.recipient, false),
];

void main() {
  Future<void> pump(
    WidgetTester t,
    NextAction a,
    Locale l,
    Brightness b,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(a, l, b));
    await t.pumpAndSettle();
  }

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    for (final b in Brightness.values) {
      testWidgets('toutes les cartes sans débordement ($locale, $b)', (
        t,
      ) async {
        for (final c in _combos) {
          await pump(t, _action(c.$1, c.$2, self: c.$3), locale, b);
          expect(t.takeException(), isNull, reason: '$c');
          expect(find.byType(NextActionCard), findsOneWidget);
          final texts = t.widgetList<Text>(
            find.descendant(
              of: find.byType(NextActionCard),
              matching: find.byType(Text),
            ),
          );
          expect(texts.length, 2, reason: '$c');
          for (final x in texts) {
            expect(x.data, isNotEmpty);
            expect(x.data, isNot(contains('{')), reason: '$c');
          }
        }
      });

      testWidgets('noms très longs et vides ($locale, $b)', (t) async {
        final long = 'A' * 40;
        for (final c in _combos) {
          await pump(
            t,
            _action(
              c.$1,
              c.$2,
              self: c.$3,
              traveler: long,
              sender: long,
              recipient: long,
              city: long,
            ),
            locale,
            b,
          );
          expect(t.takeException(), isNull, reason: '$c long');
          await pump(
            t,
            _action(
              c.$1,
              c.$2,
              self: c.$3,
              traveler: '',
              sender: '',
              recipient: '',
              city: '',
            ),
            locale,
            b,
          );
          expect(t.takeException(), isNull, reason: '$c vide');
        }
      });
    }
  }

  testWidgets('FR : texte exact expéditeur HANDED_OVER', (t) async {
    await pump(
      t,
      _action('HANDED_OVER', ParcelRole.sender),
      AppL10n.fr,
      Brightness.light,
    );
    expect(find.text('Envoyez le code à Mariam'), findsOneWidget);
    expect(
      find.text('Sans ce code, Moussa ne lui remettra pas le colis.'),
      findsOneWidget,
    );
  });

  testWidgets('FR : destinataire vide, repli', (t) async {
    await pump(
      t,
      _action('HANDED_OVER', ParcelRole.sender, recipient: ' '),
      AppL10n.fr,
      Brightness.light,
    );
    expect(find.text('Envoyez le code à votre destinataire'), findsOneWidget);
  });

  testWidgets('FR : voyageur ARRIVED sans noms', (t) async {
    await pump(
      t,
      _action('ARRIVED', ParcelRole.traveler, recipient: '', sender: ''),
      AppL10n.fr,
      Brightness.light,
    );
    expect(
      find.text(
        "Demandez au destinataire son code à 6 chiffres. Sans code, appelez l'expéditeur.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('aucun bouton dans la carte', (t) async {
    await pump(
      t,
      _action('ARRIVED', ParcelRole.sender),
      AppL10n.fr,
      Brightness.light,
    );
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('FR : textes neutres (expéditeur ARRIVED, voyageur, repli)', (
    t,
  ) async {
    await pump(
      t,
      _action('ARRIVED', ParcelRole.sender, recipient: ''),
      AppL10n.fr,
      Brightness.light,
    );
    expect(find.text('Votre colis est arrivé à Dakar'), findsOneWidget);
    expect(
      find.text(
        'Votre destinataire doit présenter son code pour prendre le colis. '
        'Rappelez-le-lui au besoin.',
      ),
      findsOneWidget,
    );
    await pump(
      t,
      _action('ARRIVED', ParcelRole.recipient, traveler: ''),
      AppL10n.fr,
      Brightness.light,
    );
    expect(
      find.text('Donnez votre code au voyageur pour récupérer le colis.'),
      findsOneWidget,
    );
    await pump(
      t,
      _action('ARRIVED', ParcelRole.sender, self: true),
      AppL10n.fr,
      Brightness.light,
    );
    expect(
      find.text('Donnez votre code à Moussa pour récupérer le colis.'),
      findsOneWidget,
    );
    await pump(
      t,
      _action('ACCEPTED', ParcelRole.sender),
      AppL10n.fr,
      Brightness.light,
    );
    expect(
      find.text(
        'Ouvrez le QR avant la rencontre. Après son scan, vous recevrez le '
        'code de retrait à donner à Mariam.',
      ),
      findsOneWidget,
    );
  });

  // Repli en milieu de phrase : jamais de majuscule ; en début de phrase :
  // majuscule. Noms vides, FR puis EN.
  testWidgets('replis : casse correcte, FR et EN', (t) async {
    final cases = <(Locale, String, ParcelRole, bool, List<String>)>[
      (
        AppL10n.fr,
        'HANDED_OVER',
        ParcelRole.sender,
        false,
        [
          'Envoyez le code à votre destinataire',
          'Sans ce code, votre voyageur ne lui remettra pas le colis.',
        ],
      ),
      (
        AppL10n.fr,
        'IN_TRANSIT',
        ParcelRole.sender,
        true,
        [
          'Gardez votre code de retrait',
          'Sans ce code, votre voyageur ne vous remettra pas le colis.',
        ],
      ),
      (
        AppL10n.fr,
        'ACCEPTED',
        ParcelRole.sender,
        false,
        [
          'Préparez la remise avec votre voyageur',
          'Ouvrez le QR avant la rencontre. Après son scan, vous recevrez le '
              'code de retrait à donner à votre destinataire.',
        ],
      ),
      (
        AppL10n.fr,
        'ARRIVED',
        ParcelRole.sender,
        false,
        [
          "Votre colis est arrivé à la ville d'arrivée",
          'Votre destinataire doit présenter son code pour prendre le colis. '
              'Rappelez-le-lui au besoin.',
        ],
      ),
      (
        AppL10n.fr,
        'ACCEPTED',
        ParcelRole.traveler,
        false,
        ["À la remise, scannez le QR de l'expéditeur"],
      ),
      (
        AppL10n.en,
        'HANDED_OVER',
        ParcelRole.sender,
        false,
        [
          'Send the code to your recipient',
          'Without this code, your traveler will not hand the parcel over to '
              'them.',
        ],
      ),
      (
        AppL10n.en,
        'IN_TRANSIT',
        ParcelRole.sender,
        true,
        [
          'Without this code, your traveler will not hand the parcel over to '
              'you.',
        ],
      ),
      (
        AppL10n.en,
        'ACCEPTED',
        ParcelRole.sender,
        false,
        [
          'Get ready to hand over to your traveler',
          'Have the QR open before you see them. Once they scan it, you will '
              'get the pickup code to give to your recipient.',
        ],
      ),
      (
        AppL10n.en,
        'ARRIVED',
        ParcelRole.sender,
        false,
        [
          'Your parcel has arrived in the arrival city',
          'Your recipient must show their code to collect the parcel. Remind '
              'them if needed.',
        ],
      ),
      (
        AppL10n.en,
        'ARRIVED',
        ParcelRole.traveler,
        false,
        [
          'Ask the recipient for their 6-digit code. Without a code, call the '
              'sender.',
        ],
      ),
      (
        AppL10n.en,
        'ACCEPTED',
        ParcelRole.traveler,
        false,
        ["At handover, scan the sender's QR"],
      ),
    ];
    for (final c in cases) {
      await pump(
        t,
        _action(
          c.$2,
          c.$3,
          self: c.$4,
          traveler: '',
          sender: '',
          recipient: '',
          city: '',
        ),
        c.$1,
        Brightness.light,
      );
      for (final text in c.$5) {
        expect(
          find.text(text),
          findsOneWidget,
          reason: '${c.$1} ${c.$2} $text',
        );
      }
    }
  });
}
