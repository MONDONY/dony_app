import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/button_first_name.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/data/models/contact_phone_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/pickup_code_request_cubit.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:dony/features/tracking/presentation/screens/scan_confirm_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Saisie du code du voyageur (spec §6.3, rappels à chaque étape du colis) :
/// encadré orange « Pas de code, pas de remise » à la place de l'encadré
/// bleu, et sous le champ « Le destinataire n'a pas le code ? » suivi du lien
/// « Appeler {expéditeur} », seulement quand le numéro de l'expéditeur est
/// communicable.
class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockBidRepository extends Mock implements BidRepository {}

class _MockTrackingRepository extends Mock implements TrackingRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

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
  setUpAll(_loadAppFonts);

  late _MockTrackingBloc tracking;
  late _MockRatingBloc rating;
  late _MockBidRepository repo;

  setUp(() async {
    tracking = _MockTrackingBloc();
    rating = _MockRatingBloc();
    when(() => tracking.state).thenReturn(TrackingInitial());
    when(() => rating.state).thenReturn(const RatingInitial());
    repo = _MockBidRepository();
    when(
      () => repo.getCounterpartyContact(any()),
    ).thenAnswer((_) async => const ContactPhoneModel(phoneNumber: '+33600'));
    await getIt.reset();
    getIt.registerFactory<ContactRevealBloc>(() => ContactRevealBloc(repo));
  });

  tearDown(() async => getIt.reset());

  Future<void> pump(
    WidgetTester tester, {
    String etape = 'ARRIVEE',
    String? senderName = 'Aminata K.',
    bool senderPhoneAvailable = true,
    Locale locale = AppL10n.fr,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<TrackingBloc>.value(value: tracking),
              BlocProvider<RatingBloc>.value(value: rating),
            ],
            child: ScanConfirmScreen(
              bidId: 'bid-123',
              etape: etape,
              packageLabel: 'DON-TEST01',
              senderName: senderName,
              senderPhoneAvailable: senderPhoneAvailable,
            ),
          ),
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
    await tester.pump();
  }

  final warning = find.byKey(const Key('scan-confirm-no-code-warning'));
  final callLink = find.byKey(const Key('scan-confirm-call-sender'));

  /// Nombre de lignes rendues par le texte [text].
  int lines(WidgetTester tester, Finder text, String data) => tester
      .renderObject<RenderParagraph>(text)
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: data.length),
      )
      .map((b) => b.top)
      .toSet()
      .length;

  for (final locale in const [AppL10n.fr, AppL10n.en]) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;

    testWidgets('scanConfirm_showsOrangeWarningAndCallLink ($tag, 360 dp)', (
      tester,
    ) async {
      await pump(tester, locale: locale);

      // Encadré orange : titre et phrase sur le numéro DON-…
      expect(warning, findsOneWidget);
      final cs = Theme.of(tester.element(warning)).colorScheme;
      final box = tester.widget<Container>(warning);
      expect((box.decoration! as BoxDecoration).color, cs.warningLight);
      expect(
        find.descendant(
          of: warning,
          matching: find.text(l.scanConfirmNoCodeTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: warning,
          matching: find.text(l.scanConfirmConfirmationCodeHint),
        ),
        findsOneWidget,
      );
      // L'ancien encadré bleu n'existe plus.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == cs.primaryContainer &&
              w.child is Row,
        ),
        findsNothing,
      );

      // Sous le champ : la question, puis le lien d'appel sur une ligne.
      expect(find.text(l.scanConfirmNoCodeQuestion), findsOneWidget);
      expect(callLink, findsOneWidget);
      final label = l.parcelCallPerson('Aminata');
      final text = find.descendant(of: callLink, matching: find.text(label));
      expect(text, findsOneWidget);
      expect(lines(tester, text, label), 1);
      expect(
        tester.getTopLeft(callLink).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(tester.takeException(), isNull);
    });

    for (final name in ['Mouhammadou-Moustapha Ba', 'MOUHAMMADOU-MOUSTAPHA']) {
      testWidgets('$tag : prénom très long « $name » coupé, le lien reste sur '
          'une ligne, sans points de suspension du texte', (tester) async {
        await pump(tester, locale: locale, senderName: name);

        final label = l.parcelCallPerson(buttonFirstName(name));
        final text = find.descendant(of: callLink, matching: find.text(label));
        expect(text, findsOneWidget);
        expect(lines(tester, text, label), 1);
        // Le texte entier est rendu : aucune coupure par la mise en page.
        expect(
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$tag : expéditeur sans nom, « ${l.parcelCallSender} »', (
      tester,
    ) async {
      await pump(tester, locale: locale, senderName: null);
      expect(
        find.descendant(of: callLink, matching: find.text(l.parcelCallSender)),
        findsOneWidget,
      );
    });
  }

  testWidgets('le lien demande le numéro de l\'expéditeur au serveur', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(callLink);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => repo.getCounterpartyContact('bid-123')).called(1);
  });

  testWidgets('callButtonHiddenWhenPhoneMissing : sans numéro communicable, '
      'ni question ni lien, l\'encadré reste', (tester) async {
    await pump(tester, senderPhoneAvailable: false);

    expect(warning, findsOneWidget);
    expect(callLink, findsNothing);
    expect(find.text("Le destinataire n'a pas le code ?"), findsNothing);
    expect(find.textContaining('Appeler'), findsNothing);
  });

  testWidgets('DEPART : ni encadré du code ni lien', (tester) async {
    await pump(tester, etape: 'DEPART');

    expect(warning, findsNothing);
    expect(callLink, findsNothing);
  });

  testWidgets('code bloqué : « Demander un nouveau code » ne change pas, le '
      'lien reste', (tester) async {
    getIt.registerFactory<PickupCodeRequestCubit>(
      () => PickupCodeRequestCubit(
        _MockTrackingRepository(),
        _MockAnalyticsService(),
      ),
    );
    when(() => tracking.state).thenReturn(
      DeliveryConfirmError(
        const ValidationException('x', code: 'code-blocked'),
      ),
    );
    await pump(tester);

    expect(find.byKey(const Key('scan-confirm-code-request')), findsOneWidget);
    expect(callLink, findsOneWidget);
  });

  test('aucun code à 6 chiffres dans les nouveaux textes', () {
    final sixDigits = RegExp(r'\d{6}');
    for (final locale in const [AppL10n.fr, AppL10n.en]) {
      final l = lookupAppLocalizations(locale);
      for (final text in [
        l.scanConfirmNoCodeTitle,
        l.scanConfirmNoCodeQuestion,
        l.parcelCallSender,
        l.parcelCallPerson('Aminata'),
      ]) {
        expect(sixDigits.hasMatch(text), isFalse, reason: text);
      }
    }
  });
}
