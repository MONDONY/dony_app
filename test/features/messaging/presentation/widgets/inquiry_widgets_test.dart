import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/inquiry_booking_card.dart';
import 'package:dony/features/messaging/presentation/widgets/inquiry_locked_bar.dart';
import 'package:dony/features/messaging/presentation/widgets/inquiry_note.dart';
import 'package:dony/features/messaging/presentation/widgets/inquiry_quota_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppL10n.fr,
  Size size = const Size(360, 800),
}) async {
  final previous = Intl.defaultLocale;
  Intl.defaultLocale = locale.languageCode;
  addTearDown(() => Intl.defaultLocale = previous);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    ),
  );
}

Color? _barColor(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.byKey(const Key('inquiry-quota-bar')),
  );
  return (box.decoration! as BoxDecoration).color;
}

void main() {
  final cs = AppTheme.light().colorScheme;

  group('InquiryQuotaBar', () {
    testWidgets('10 restants : 10 pastilles pleines, fond neutre', (
      tester,
    ) async {
      await _pump(tester, const InquiryQuotaBar(remaining: 10, limit: 10));
      expect(find.text('10 messages restants'), findsOneWidget);
      expect(find.byKey(const Key('inquiry-dot-filled')), findsNWidgets(10));
      expect(find.byKey(const Key('inquiry-dot-used')), findsNothing);
      expect(_barColor(tester), cs.surface);
    });

    testWidgets('4 restants : toujours neutre', (tester) async {
      await _pump(tester, const InquiryQuotaBar(remaining: 4, limit: 10));
      expect(find.text('4 messages restants'), findsOneWidget);
      expect(find.byKey(const Key('inquiry-dot-filled')), findsNWidgets(4));
      expect(find.byKey(const Key('inquiry-dot-used')), findsNWidgets(6));
      expect(_barColor(tester), cs.surface);
    });

    testWidgets('3 restants : terracotta', (tester) async {
      await _pump(tester, const InquiryQuotaBar(remaining: 3, limit: 10));
      expect(find.text('3 messages restants'), findsOneWidget);
      expect(_barColor(tester), cs.secondaryContainer);
    });

    testWidgets('0 restant : terracotta, aucune pastille pleine', (
      tester,
    ) async {
      await _pump(tester, const InquiryQuotaBar(remaining: 0, limit: 10));
      expect(find.text('Plus de message avant réservation'), findsOneWidget);
      expect(find.byKey(const Key('inquiry-dot-filled')), findsNothing);
      expect(find.byKey(const Key('inquiry-dot-used')), findsNWidgets(10));
      expect(_barColor(tester), cs.secondaryContainer);
    });

    testWidgets('1 restant : singulier', (tester) async {
      await _pump(tester, const InquiryQuotaBar(remaining: 1, limit: 10));
      expect(find.text('1 message restant'), findsOneWidget);
    });

    for (final limit in [10, 30, 100]) {
      testWidgets('plafond $limit à 360 dp, texte x1.3 : pas de débordement', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          InquiryQuotaBar(remaining: limit - 1, limit: limit),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('${limit - 1} messages restants'), findsOneWidget);
        final dots =
            find.byKey(const Key('inquiry-dot-filled')).evaluate().length +
            find.byKey(const Key('inquiry-dot-used')).evaluate().length;
        expect(dots, lessThanOrEqualTo(10));
      });
    }

    testWidgets('anglais à 360 dp : pas d\'exception', (tester) async {
      await _pump(
        tester,
        const InquiryQuotaBar(remaining: 2, limit: 10),
        locale: AppL10n.en,
      );
      expect(find.text('2 messages left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('InquiryBookingCard', () {
    testWidgets('affiche le trajet, le bouton, et appelle onBook', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        InquiryBookingCard(
          routeLabel: 'Paris → Dakar',
          detailLine: '9,00 €/kg',
          onBook: () => taps++,
        ),
      );
      expect(find.text('Prêt à réserver ?'), findsOneWidget);
      expect(find.text('Paris → Dakar · 9,00 €/kg'), findsOneWidget);
      expect(find.text('Faire une demande'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inquiry-booking-button')));
      expect(taps, 1);
    });

    testWidgets('sans détail : le trajet seul', (tester) async {
      await _pump(
        tester,
        InquiryBookingCard(
          routeLabel: 'Paris → Dakar',
          detailLine: '',
          onBook: () {},
        ),
      );
      expect(find.text('Paris → Dakar'), findsOneWidget);
    });

    testWidgets(
      'FR et EN à 360 dp : aucune exception, même hauteur de bouton',
      (tester) async {
        final heights = <double>[];
        for (final locale in [AppL10n.fr, AppL10n.en]) {
          await _pump(
            tester,
            InquiryBookingCard(
              routeLabel: 'Paris → Ouagadougou-Bobo-Dioulasso',
              detailLine: '12,50 €/kg',
              onBook: () {},
            ),
            locale: locale,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          heights.add(
            tester
                .getSize(find.byKey(const Key('inquiry-booking-button')))
                .height,
          );
        }
        expect(heights[0], heights[1]);
        expect(find.text('Make a request'), findsOneWidget);
      },
    );
  });

  group('note d\'accueil', () {
    ConversationModel conv(String name, {int? limit}) => ConversationModel(
      id: 'c',
      firestoreConversationId: 'f',
      otherParticipant: ParticipantModel(id: 'o', name: name),
      kind: ConversationModel.kindInquiry,
      inquiryMessageLimit: limit,
    );

    test('prénom du voyageur, repli « Voyageur » sans nom', () {
      final fr = lookupAppLocalizations(AppL10n.fr);
      expect(inquiryCounterpartFirstName(fr, conv('Moussa Diallo')), 'Moussa');
      expect(inquiryCounterpartFirstName(fr, conv('  ')), 'Voyageur');
    });

    test('quota servi, sinon 10, en français et en anglais', () {
      final fr = lookupAppLocalizations(AppL10n.fr);
      final en = lookupAppLocalizations(AppL10n.en);
      expect(
        inquiryIntroText(fr, conv('Awa', limit: 5)),
        'Vous pouvez envoyer 5 messages avant de réserver. '
        'Awa peut répondre sans limite. Texte seul, sans photo.',
      );
      expect(
        inquiryIntroText(en, conv('Awa')),
        'You can send 10 messages before booking. '
        'Awa can reply without limits. Text only, no photos.',
      );
    });
  });

  group('InquiryLockedBar', () {
    testWidgets('explication + bouton, appelle onBook', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        InquiryLockedBar(limit: 10, name: 'Moussa', onBook: () => taps++),
      );
      expect(
        find.text(
          'Vous avez utilisé vos 10 messages. Faites une demande à Moussa '
          'pour continuer à discuter sans limite.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('inquiry-booking-button')));
      expect(taps, 1);
    });

    testWidgets('même hauteur de bouton en FR et EN à 360 dp', (tester) async {
      final heights = <double>[];
      for (final locale in [AppL10n.fr, AppL10n.en]) {
        await _pump(
          tester,
          InquiryLockedBar(limit: 10, name: 'Moussa', onBook: () {}),
          locale: locale,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        heights.add(
          tester
              .getSize(find.byKey(const Key('inquiry-booking-button')))
              .height,
        );
      }
      expect(heights[0], heights[1]);
    });
  });
}
