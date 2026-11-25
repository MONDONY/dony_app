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
}
