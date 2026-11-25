import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/button_first_name.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/contact_phone_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Barres collantes de la fiche colis, cases du tableau du spec §6.2
/// (rappels à chaque étape du colis) : un test par ligne, libellé FR et EN
/// sur une ligne, à taille normale, bouton de 52 dp à 360 dp, y compris avec
/// le prénom le plus long ; les autres statuts ne changent pas.
class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

/// Prénoms longs réalistes : coupés avant le libellé. Le deuxième est très
/// large, le troisième saisi en capitales (fréquent dans les formulaires).
const _longNames = [
  'Maximilienne-Aurore Dupont',
  'Mouhammadou-Moustapha Ba',
  'MOUHAMMADOU-MOUSTAPHA BA',
];

BidModel _bid({
  String status = 'HANDED_OVER',
  String? recipientName = 'Fatou Diallo',
  String? travelerName = 'Mamadou D.',
  String? senderName = 'Aminata K.',
  String? confirmationCode = '4729',
  String? trackingToken = 'tok-1',
  bool recipientIsSender = false,
  bool travelerPhoneAvailable = true,
  bool senderPhoneAvailable = true,
  bool pickupCodeRenewalNeeded = false,
  String? recipientAppStatus,
  BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  bool senderHasRated = false,
  DateTime? departureAt,
}) => BidModel(
  id: 'bid-na-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  travelerId: 'traveler-1',
  status: status,
  recipientName: recipientName,
  recipientPhone: '+221770000000',
  travelerName: travelerName,
  senderName: senderName,
  confirmationCode: confirmationCode,
  trackingToken: trackingToken,
  recipientIsSender: recipientIsSender,
  travelerPhoneAvailable: travelerPhoneAvailable,
  senderPhoneAvailable: senderPhoneAvailable,
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  recipientAppStatus: recipientAppStatus,
  paymentMethod: paymentMethod,
  senderHasRated: senderHasRated,
  departureAt: departureAt,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Polices de l'app : sans elles, chaque glyphe fait un cadratin et la mesure
/// des libellés ne veut rien dire.
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

/// Le libellé du [DonyButton] [button] tient sur une ligne, sans être réduit
/// par le `FittedBox(scaleDown)` du bouton, et le bouton garde 52 dp.
void _expectNominal(WidgetTester tester, Finder button, String label) {
  expect(button, findsOneWidget, reason: label);
  final fitted = find.descendant(
    of: button,
    matching: find.byWidgetPredicate(
      (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
    ),
  );
  final text = find.descendant(of: button, matching: find.text(label));
  expect(fitted, findsOneWidget, reason: label);
  expect(text, findsOneWidget, reason: label);
  final box = tester.renderObject<RenderFittedBox>(fitted);
  expect(
    box.child!.size.width,
    lessThanOrEqualTo(box.size.width + 0.01),
    reason: '« $label » réduit par le FittedBox',
  );
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final lines = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length),
      )
      .map((b) => b.top)
      .toSet()
      .length;
  expect(lines, 1, reason: '« $label » sur $lines lignes');
  expect(tester.getSize(button).height, 52, reason: label);
}

void main() {
  setUpAll(_loadAppFonts);

  late _MockBidBloc bidBloc;
  late _MockTrackingBloc trackingBloc;
  late _MockAnnouncementBloc announcementBloc;
  late _MockBidRepository repo;

  setUp(() async {
    bidBloc = _MockBidBloc();
    trackingBloc = _MockTrackingBloc();
    announcementBloc = _MockAnnouncementBloc();
    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    repo = _MockBidRepository();
    when(
      () => repo.getCounterpartyContact(any()),
    ).thenAnswer((_) async => const ContactPhoneModel(phoneNumber: '+33600'));
    await getIt.reset();
    getIt.registerFactory<ContactRevealBloc>(() => ContactRevealBloc(repo));
  });

  tearDown(() async => getIt.reset());

  final pushed = <String, Map<String, dynamic>>{};

  Future<void> pump(
    WidgetTester tester,
    Widget bar, {
    Locale locale = AppL10n.fr,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    pushed.clear();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<TrackingBloc>.value(value: trackingBloc),
              BlocProvider<AnnouncementBloc>.value(value: announcementBloc),
            ],
            child: Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: bar,
            ),
          ),
        ),
        GoRoute(
          path: '/tracking/scan/photo',
          builder: (_, state) {
            pushed['/tracking/scan/photo'] =
                state.extra! as Map<String, dynamic>;
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Widget sender(BidModel bid) =>
      SenderStickyBar(bid: bid, isLoading: false, paymentLoaded: true);

  Widget traveler(BidModel bid) =>
      TravelerStickyBar(bid: bid, isLoading: false);

  Finder button(String label) => find.widgetWithText(DonyButton, label);

  // ── Expéditeur, HANDED_OVER et IN_TRANSIT : « Envoyer le code à … » ──────
  group('expéditeur, colis remis ou en route', () {
    for (final status in ['HANDED_OVER', 'IN_TRANSIT']) {
      for (final locale in const [AppL10n.fr, AppL10n.en]) {
        final l = lookupAppLocalizations(locale);
        testWidgets('$status ${locale.languageCode} : '
            '« ${l.bidDetailSendCodeTo('Fatou')} », une ligne, 52 dp', (
          tester,
        ) async {
          await pump(tester, sender(_bid(status: status)), locale: locale);

          final label = l.bidDetailSendCodeTo('Fatou');
          _expectNominal(tester, button(label), label);
          expect(find.text(l.bidDetailTrackParcel), findsNothing);
          expect(tester.takeException(), isNull);
        });

        for (final name in _longNames) {
          testWidgets('$status ${locale.languageCode} : prénom long '
              '« $name » coupé, jamais la police', (tester) async {
            await pump(
              tester,
              sender(_bid(status: status, recipientName: name)),
              locale: locale,
            );

            final label = l.bidDetailSendCodeTo(buttonFirstName(name));
            _expectNominal(tester, button(label), label);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('le bouton ouvre la feuille « Prévenir » en mode code', (
      tester,
    ) async {
      await pump(tester, sender(_bid()));

      await tester.tap(button('Envoyer le code à Fatou'));
      await tester.pumpAndSettle();

      expect(find.text('Prévenir Fatou Diallo'), findsOneWidget);
      expect(
        find.widgetWithText(DonyButton, 'Envoyer le code sur WhatsApp'),
        findsOneWidget,
      );
    });

    testWidgets('nom du destinataire absent : « Envoyer le code »', (
      tester,
    ) async {
      await pump(tester, sender(_bid(recipientName: null)));
      _expectNominal(tester, button('Envoyer le code'), 'Envoyer le code');
    });

    for (final (name, bid) in [
      ('sans code', _bid(confirmationCode: null)),
      ('code bloqué', _bid(pickupCodeRenewalNeeded: true)),
      ('destinataire en refus', _bid(recipientAppStatus: 'DECLINED')),
      ('sans lien de suivi', _bid(trackingToken: null)),
    ]) {
      testWidgets('$name : « Suivi du colis » comme aujourd\'hui', (
        tester,
      ) async {
        await pump(tester, sender(bid));
        expect(button('Suivi du colis'), findsOneWidget);
        expect(find.textContaining('Envoyer le code'), findsNothing);
      });
    }
  });

  // ── Expéditeur, ARRIVED : « Renvoyer le code à … » ───────────────────────
  group('expéditeur, colis arrivé', () {
    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      final l = lookupAppLocalizations(locale);
      testWidgets('${locale.languageCode} : '
          '« ${l.bidDetailResendCodeTo('Fatou')} », une ligne, 52 dp', (
        tester,
      ) async {
        await pump(tester, sender(_bid(status: 'ARRIVED')), locale: locale);

        final label = l.bidDetailResendCodeTo('Fatou');
        _expectNominal(tester, button(label), label);
        expect(tester.takeException(), isNull);
      });

      for (final name in _longNames) {
        testWidgets('${locale.languageCode} : prénom long « $name »', (
          tester,
        ) async {
          await pump(
            tester,
            sender(_bid(status: 'ARRIVED', recipientName: name)),
            locale: locale,
          );

          final label = l.bidDetailResendCodeTo(buttonFirstName(name));
          _expectNominal(tester, button(label), label);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('${locale.languageCode} : nom absent, '
          '« ${l.bidDetailResendCode} »', (tester) async {
        await pump(
          tester,
          sender(_bid(status: 'ARRIVED', recipientName: '  ')),
          locale: locale,
        );
        _expectNominal(
          tester,
          button(l.bidDetailResendCode),
          l.bidDetailResendCode,
        );
      });
    }

    testWidgets('le bouton ouvre la feuille « Prévenir » en mode code', (
      tester,
    ) async {
      await pump(tester, sender(_bid(status: 'ARRIVED')));

      await tester.tap(button('Renvoyer le code à Fatou'));
      await tester.pumpAndSettle();

      expect(find.text('Prévenir Fatou Diallo'), findsOneWidget);
      expect(
        find.widgetWithText(DonyButton, 'Envoyer le code sur WhatsApp'),
        findsOneWidget,
      );
    });

    testWidgets('sans code : « Suivi du colis » comme aujourd\'hui', (
      tester,
    ) async {
      await pump(
        tester,
        sender(_bid(status: 'ARRIVED', confirmationCode: null)),
      );
      expect(button('Suivi du colis'), findsOneWidget);
    });
  });

  // ── Expéditeur = destinataire (spec §6.4) ───────────────────────────────
  group('expéditeur qui est son propre destinataire', () {
    for (final status in ['HANDED_OVER', 'IN_TRANSIT']) {
      for (final locale in const [AppL10n.fr, AppL10n.en]) {
        final l = lookupAppLocalizations(locale);
        testWidgets('$status ${locale.languageCode} : '
            '« ${l.bidDetailSeeMyCode} »', (tester) async {
          await pump(
            tester,
            sender(_bid(status: status, recipientIsSender: true)),
            locale: locale,
          );

          _expectNominal(
            tester,
            button(l.bidDetailSeeMyCode),
            l.bidDetailSeeMyCode,
          );
          expect(find.textContaining('code à'), findsNothing);
          expect(find.textContaining('code to'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('« Voir mon code » ouvre la feuille du code du talon', (
      tester,
    ) async {
      await pump(tester, sender(_bid(recipientIsSender: true)));

      await tester.tap(button('Voir mon code'));
      await tester.pumpAndSettle();

      expect(find.text('Code de retrait'), findsOneWidget);
    });

    testWidgets('sans code : « Suivi du colis »', (tester) async {
      await pump(
        tester,
        sender(_bid(recipientIsSender: true, confirmationCode: null)),
      );
      expect(button('Suivi du colis'), findsOneWidget);
      expect(find.text('Voir mon code'), findsNothing);
    });

    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      final l = lookupAppLocalizations(locale);
      testWidgets('ARRIVED ${locale.languageCode} : '
          '« ${l.parcelCallPerson('Mamadou')} »', (tester) async {
        await pump(
          tester,
          sender(_bid(status: 'ARRIVED', recipientIsSender: true)),
          locale: locale,
        );

        final label = l.parcelCallPerson('Mamadou');
        _expectNominal(tester, button(label), label);
        expect(tester.takeException(), isNull);
      });

      for (final name in _longNames) {
        testWidgets('ARRIVED ${locale.languageCode} : prénom long « $name »', (
          tester,
        ) async {
          await pump(
            tester,
            sender(
              _bid(
                status: 'ARRIVED',
                recipientIsSender: true,
                travelerName: name,
              ),
            ),
            locale: locale,
          );

          final label = l.parcelCallPerson(buttonFirstName(name));
          _expectNominal(tester, button(label), label);
        });
      }
    }

    testWidgets('ARRIVED : « Appeler » demande le numéro au serveur', (
      tester,
    ) async {
      await pump(
        tester,
        sender(_bid(status: 'ARRIVED', recipientIsSender: true)),
      );

      await tester.tap(button('Appeler Mamadou'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      verify(() => repo.getCounterpartyContact('bid-na-1')).called(1);
    });

    testWidgets('callButtonHiddenWhenPhoneMissing : sans numéro, « Suivi du '
        'colis »', (tester) async {
      await pump(
        tester,
        sender(
          _bid(
            status: 'ARRIVED',
            recipientIsSender: true,
            travelerPhoneAvailable: false,
          ),
        ),
      );

      expect(find.textContaining('Appeler'), findsNothing);
      expect(button('Suivi du colis'), findsOneWidget);
    });
  });

  // ── Les autres statuts ne changent pas ──────────────────────────────────
  group('inchangé hors des cases du tableau', () {
    testWidgets('senderAccepted_stickyUnchanged : « Afficher le QR de '
        'remise »', (tester) async {
      await pump(tester, sender(_bid(status: 'ACCEPTED')));
      expect(button('Afficher le QR de remise'), findsOneWidget);
      expect(find.byType(DonyButton), findsOneWidget);
    });

    testWidgets('expéditeur = destinataire, ACCEPTED : « Afficher le QR de '
        'remise »', (tester) async {
      await pump(
        tester,
        sender(_bid(status: 'ACCEPTED', recipientIsSender: true)),
      );
      expect(button('Afficher le QR de remise'), findsOneWidget);
    });

    for (final self in [false, true]) {
      testWidgets('COMPLETED (destinataire = expéditeur : $self) : « Noter le '
          'voyageur »', (tester) async {
        await pump(
          tester,
          sender(_bid(status: 'COMPLETED', recipientIsSender: self)),
        );
        expect(button('Noter le voyageur'), findsOneWidget);
        expect(find.byType(DonyButton), findsOneWidget);
      });
    }

    for (final status in ['HANDED_OVER', 'IN_TRANSIT']) {
      testWidgets('voyageur $status : « Valider la remise » inchangé', (
        tester,
      ) async {
        await pump(
          tester,
          traveler(
            _bid(
              status: status,
              departureAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ),
        );
        expect(button('Valider la remise'), findsOneWidget);
        expect(find.text('Valider avec le code'), findsNothing);
      });
    }

    testWidgets('voyageur ACCEPTED : rien de nouveau', (tester) async {
      await pump(tester, traveler(_bid(status: 'ACCEPTED')));
      expect(find.text('Valider avec le code'), findsNothing);
    });
  });

  // ── Voyageur, ARRIVED : « Valider avec le code » ────────────────────────
  group('voyageur, colis arrivé', () {
    final past = DateTime.now().subtract(const Duration(hours: 2));

    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      final l = lookupAppLocalizations(locale);
      testWidgets(
        '${locale.languageCode} : « ${l.bidDetailValidateWithCode} »',
        (tester) async {
          await pump(
            tester,
            traveler(_bid(status: 'ARRIVED', departureAt: past)),
            locale: locale,
          );

          _expectNominal(
            tester,
            find.byKey(const Key('traveler-deliver-btn')),
            l.bidDetailValidateWithCode,
          );
          expect(find.text(l.bidDetailConfirmHandover), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('même action que « Valider la remise » : remise par photo '
        'puis code, avec le nom et la joignabilité de l\'expéditeur', (
      tester,
    ) async {
      await pump(tester, traveler(_bid(status: 'ARRIVED', departureAt: past)));

      await tester.tap(find.byKey(const Key('traveler-deliver-btn')));
      await tester.pumpAndSettle();

      final extra = pushed['/tracking/scan/photo']!;
      expect(extra['bidId'], 'bid-na-1');
      expect(extra['etape'], 'ARRIVEE');
      expect(extra['senderName'], 'Aminata K.');
      expect(extra['senderPhoneAvailable'], isTrue);
    });

    testWidgets('verrou avant le départ : « Disponible au départ » reste', (
      tester,
    ) async {
      await pump(
        tester,
        traveler(
          _bid(
            status: 'ARRIVED',
            departureAt: DateTime.now().add(const Duration(days: 2)),
          ),
        ),
      );
      expect(button('Disponible au départ'), findsOneWidget);
      expect(find.text('Valider avec le code'), findsNothing);
    });
  });
}
