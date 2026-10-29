import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart'
    show BidAcceptanceEvent;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

/// Footer de la fiche colis (voyageur) : un seul bouton, ou deux boutons sur la
/// même ligne (secondaire à gauche = 1/3, principal à droite = 2/3), sans
/// badge ni phrase d'aide. Complète `traveler_sticky_bar_test.dart`.
class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptBloc extends MockBloc<BidAcceptanceEvent, BidAcceptanceState>
    implements BidAcceptanceBloc {}

BidModel _bid({
  String status = 'PENDING',
  bool voyageurConfirmed = false,
  DateTime? departureAt,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-tf-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: status,
  paymentMethod: paymentMethod,
  weightKg: 5,
  voyageurConfirmed: voyageurConfirmed,
  departureAt: departureAt,
  supplement: supplement,
  amendments: amendments,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _blockingSupplement = BidSupplement(
  id: 'sup-1',
  status: BidSupplementStatus.proposed,
  grossAmount: 16.8,
  blocksHandover: true,
);

const _blockingAmendment = BidAmendment(
  id: 'am-1',
  status: BidAmendmentStatus.proposed,
  rail: 'CASH',
  grossAmount: 26.8,
  blocksHandover: true,
);

/// Charge les vraies polices de l'app : avec la police de repli des tests,
/// chaque glyphe fait un cadratin et tout libellé paraît rétréci.
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
  late _MockBidBloc bidBloc;
  late _MockAcceptBloc acceptBloc;

  setUpAll(() {
    registerFallbackValue(BidRejectRequested('fallback'));
    return _loadAppFonts();
  });

  setUp(() {
    bidBloc = _MockBidBloc();
    acceptBloc = _MockAcceptBloc();
    whenListen<BidState>(
      bidBloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
    whenListen<BidAcceptanceState>(
      acceptBloc,
      const Stream.empty(),
      initialState: BidAcceptanceInitial(),
    );
  });

  Future<void> pumpBar(
    WidgetTester tester,
    BidModel bid, {
    bool isLoading = false,
    Locale locale = const Locale('fr'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
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
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<BidBloc>.value(value: bidBloc),
                  BlocProvider<BidAcceptanceBloc>.value(value: acceptBloc),
                ],
                child: Scaffold(
                  bottomNavigationBar: TravelerStickyBar(
                    bid: bid,
                    isLoading: isLoading,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // flutter_animate laisse des Timers : plusieurs pas courts.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  DonyButton button(WidgetTester tester, Finder f) =>
      tester.widget<DonyButton>(f);

  group('V1 : ligne [Refuser | Accepter]', () {
    for (final status in ['PENDING', 'PAYMENT_ESCROWED']) {
      testWidgets('$status : deux DonyButton de 52 sur une ligne, Refuser à '
          'gauche en 1/3, Accepter à droite en 2/3', (tester) async {
        await pumpBar(tester, _bid(status: status));

        expect(find.byType(DonyButton), findsNWidgets(2));
        final decline = find.widgetWithText(DonyButton, 'Refuser');
        final accept = find.widgetWithText(DonyButton, 'Accepter');
        expect(decline, findsOneWidget);
        expect(accept, findsOneWidget);

        expect(
          button(tester, decline).variant,
          DonyButtonVariant.destructiveGhost,
        );
        // Sans icône : avec elle, « Refuser » rétrécit dans 1/3 de 360 dp.
        expect(button(tester, decline).iconAsset, isNull);
        expect(button(tester, accept).variant, DonyButtonVariant.success);
        expect(button(tester, accept).iconAsset, 'check');

        final d = tester.getRect(decline);
        final a = tester.getRect(accept);
        expect(d.top, a.top);
        expect(d.height, 52);
        expect(a.height, 52);
        expect(d.right, lessThan(a.left));
        expect(a.width, closeTo(d.width * 2, 0.5));
        // Aucun OutlinedButton / FilledButton brut dans le footer.
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      });
    }

    testWidgets('tap Refuser ouvre la feuille du motif', (tester) async {
      await pumpBar(tester, _bid());
      await tester.tap(find.widgetWithText(DonyButton, 'Refuser'));
      await tester.pumpAndSettle();

      expect(find.text('Refuser la demande'), findsOneWidget);
      expect(find.text('Confirmer le refus'), findsOneWidget);
    });

    testWidgets('tap Accepter lance l\'acceptation', (tester) async {
      await pumpBar(tester, _bid(status: 'PAYMENT_ESCROWED'));
      await tester.tap(find.widgetWithText(DonyButton, 'Accepter'));
      await tester.pump();

      verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);
    });

    testWidgets('chargement : les deux boutons désactivés, Accepter affiche '
        'l\'indicateur', (tester) async {
      await pumpBar(tester, _bid(), isLoading: true);

      final decline = button(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is DonyButton &&
              w.variant == DonyButtonVariant.destructiveGhost,
        ),
      );
      final accept = button(
        tester,
        find.byWidgetPredicate(
          (w) => w is DonyButton && w.variant == DonyButtonVariant.success,
        ),
      );
      expect(decline.onPressed, isNull);
      expect(accept.onPressed, isNull);
      expect(accept.isLoading, isTrue);
    });
  });

  group('V2 / V3 : plus de footer', () {
    testWidgets('AWAITING_PAYMENT mobile money : aucun footer', (tester) async {
      final bid = _bid(
        status: 'AWAITING_PAYMENT',
        paymentMethod: BidPaymentMethod.mobileMoney,
      );
      expect(TravelerStickyBar.hasAction(bid), isFalse);
      await pumpBar(tester, bid);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.textContaining('En attente du paiement'), findsNothing);
      expect(tester.getSize(find.byType(TravelerStickyBar)).height, 0);
    });

    testWidgets('REJECTED : aucun footer, plus de bouton Supprimer', (
      tester,
    ) async {
      final bid = _bid(status: 'REJECTED');
      expect(TravelerStickyBar.hasAction(bid), isFalse);
      await pumpBar(tester, bid);
      expect(find.byType(DonyButton), findsNothing);
      expect(find.text('Supprimer cette demande'), findsNothing);
    });
  });

  group('V4 / V5 / V6 : scan', () {
    testWidgets(
      'présence confirmée, rien ne bloque : « Lire le QR du colis »',
      (tester) async {
        await pumpBar(
          tester,
          _bid(status: 'ACCEPTED', voyageurConfirmed: true),
        );

        expect(find.byType(DonyButton), findsOneWidget);
        final b = button(tester, find.byKey(const Key('traveler-scan-btn')));
        expect(b.label, 'Lire le QR du colis');
        expect(b.iconAsset, 'scan-line');
        expect(b.onPressed, isNotNull);
      },
    );

    for (final (name, bid) in [
      (
        'supplément',
        _bid(
          status: 'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _blockingSupplement,
        ),
      ),
      (
        'modification',
        _bid(
          status: 'ACCEPTED',
          voyageurConfirmed: true,
          amendments: const [_blockingAmendment],
        ),
      ),
    ]) {
      testWidgets('$name en attente : bouton désactivé « Scan en attente », '
          'aucune phrase dans le footer', (tester) async {
        await pumpBar(tester, bid);

        expect(find.byType(DonyButton), findsOneWidget);
        final b = button(tester, find.byKey(const Key('traveler-scan-btn')));
        expect(b.label, 'Scan en attente');
        expect(b.iconAsset, 'scan-line');
        expect(b.onPressed, isNull);
        expect(find.textContaining('le scan est bloqué'), findsNothing);
        expect(find.text('Lire le QR du colis'), findsNothing);
      });
    }

    testWidgets('anglais : « Scan on hold »', (tester) async {
      await pumpBar(
        tester,
        _bid(
          status: 'ACCEPTED',
          voyageurConfirmed: true,
          supplement: _blockingSupplement,
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Scan on hold'), findsOneWidget);
    });
  });

  group('V7 : présence', () {
    testWidgets('« Confirmer ma présence » inchangé', (tester) async {
      await pumpBar(tester, _bid(status: 'ACCEPTED'));
      expect(find.byType(DonyButton), findsOneWidget);
      expect(find.text('Confirmer ma présence'), findsOneWidget);
    });
  });

  group('V8 / V9 : remise', () {
    final past = DateTime.now().subtract(const Duration(hours: 2));
    final future = DateTime.now().add(const Duration(days: 2));

    for (final status in ['HANDED_OVER', 'IN_TRANSIT', 'ARRIVED']) {
      testWidgets('$status, départ passé : un seul bouton « Valider la '
          'remise », pas de scan du transit', (tester) async {
        await pumpBar(tester, _bid(status: status, departureAt: past));

        expect(find.byType(DonyButton), findsOneWidget);
        final b = button(tester, find.byKey(const Key('traveler-deliver-btn')));
        expect(b.label, 'Valider la remise');
        expect(b.iconAsset, 'badge-check');
        expect(b.variant, DonyButtonVariant.success);
        expect(b.onPressed, isNotNull);
        expect(
          find.byKey(const Key('traveler-optional-transit-btn')),
          findsNothing,
        );
        expect(find.textContaining('Scanner le transit'), findsNothing);
      });
    }

    testWidgets('départ inconnu : bouton actif', (tester) async {
      await pumpBar(tester, _bid(status: 'ARRIVED'));
      final b = button(tester, find.byKey(const Key('traveler-deliver-btn')));
      expect(b.label, 'Valider la remise');
      expect(b.onPressed, isNotNull);
    });

    testWidgets('verrou avant le départ : bouton désactivé « Disponible au '
        'départ », aucune phrase dans le footer', (tester) async {
      await pumpBar(tester, _bid(status: 'HANDED_OVER', departureAt: future));

      expect(find.byType(DonyButton), findsOneWidget);
      final b = button(tester, find.byKey(const Key('traveler-deliver-btn')));
      expect(b.label, 'Disponible au départ');
      expect(b.iconAsset, 'clock');
      expect(b.onPressed, isNull);
      expect(find.textContaining('Disponible après le départ'), findsNothing);
      expect(find.textContaining('code de retrait'), findsNothing);
      expect(find.text('Valider la remise'), findsNothing);
    });

    // Le verrou tombe seul à l'heure du départ : même State de la porte
    // (didUpdateWidget), la porte lit DateTime.now(), donc on rejoue le même
    // colis avec un départ désormais passé.
    testWidgets('le départ passe : « Disponible au départ » devient « Valider '
        'la remise » actif', (tester) async {
      final bid = ValueNotifier<BidModel>(
        _bid(status: 'HANDED_OVER', departureAt: future),
      );
      addTearDown(bid.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            bottomNavigationBar: ValueListenableBuilder<BidModel>(
              valueListenable: bid,
              builder: (_, value, _) =>
                  TravelerStickyBar(bid: value, isLoading: false),
            ),
          ),
        ),
      );
      final locked = button(
        tester,
        find.byKey(const Key('traveler-deliver-btn')),
      );
      expect(locked.label, 'Disponible au départ');
      expect(locked.onPressed, isNull);

      bid.value = _bid(status: 'HANDED_OVER', departureAt: past);
      await tester.pump();

      final open = button(
        tester,
        find.byKey(const Key('traveler-deliver-btn')),
      );
      expect(open.label, 'Valider la remise');
      expect(open.iconAsset, 'badge-check');
      expect(open.onPressed, isNotNull);
      expect(find.text('Disponible au départ'), findsNothing);
    });

    testWidgets('anglais : « Available at departure »', (tester) async {
      await pumpBar(
        tester,
        _bid(status: 'ARRIVED', departureAt: future),
        locale: const Locale('en'),
      );
      expect(find.text('Available at departure'), findsOneWidget);
    });
  });

  group('libellés à taille nominale (360 dp)', () {
    /// Rapport entre la largeur rendue du libellé dans le `FittedBox` du
    /// `DonyButton` et sa largeur naturelle : 1 = aucune réduction.
    double labelScale(WidgetTester tester, Finder button, String label) {
      final fitted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
        ),
      );
      final text = find.descendant(of: button, matching: find.text(label));
      expect(fitted, findsOneWidget, reason: label);
      expect(text, findsOneWidget, reason: label);
      return tester.getSize(fitted).width / tester.getSize(text).width;
    }

    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l = lookupAppLocalizations(locale);

      testWidgets(
        '${locale.languageCode} x1.0 : « ${l.bidDetailDeclineRequestButton} » '
        'et « ${l.bidDetailAcceptRequestButton} » tiennent sans réduction',
        (tester) async {
          await pumpBar(tester, _bid(), locale: locale);

          expect(tester.takeException(), isNull);
          for (final label in [
            l.bidDetailDeclineRequestButton,
            l.bidDetailAcceptRequestButton,
          ]) {
            expect(
              labelScale(tester, find.widgetWithText(DonyButton, label), label),
              closeTo(1, 0.001),
              reason: label,
            );
          }
        },
      );

      testWidgets(
        '${locale.languageCode} x1.0 : « ${l.bidDetailHandoverLockedLabel} » '
        'tient sans réduction',
        (tester) async {
          await pumpBar(
            tester,
            _bid(
              status: 'ARRIVED',
              departureAt: DateTime.now().add(const Duration(days: 2)),
            ),
            locale: locale,
          );

          expect(tester.takeException(), isNull);
          expect(
            labelScale(
              tester,
              find.byKey(const Key('traveler-deliver-btn')),
              l.bidDetailHandoverLockedLabel,
            ),
            closeTo(1, 0.001),
          );
        },
      );

      testWidgets('${locale.languageCode} x1.0 : « ${l.bidDetailScanPending} » '
          'tient sans réduction', (tester) async {
        await pumpBar(
          tester,
          _bid(
            status: 'ACCEPTED',
            voyageurConfirmed: true,
            supplement: _blockingSupplement,
          ),
          locale: locale,
        );

        expect(tester.takeException(), isNull);
        expect(
          labelScale(
            tester,
            find.byKey(const Key('traveler-scan-btn')),
            l.bidDetailScanPending,
          ),
          closeTo(1, 0.001),
        );
      });

      // ×1,3 (très grand texte) : mesuré à 360 dp avec les vraies polices,
      // Refuser / Decline (sans icône), Accepter / Accept et « Disponible au
      // départ » tiennent encore à taille nominale.
      testWidgets('${locale.languageCode} x1.3 : libellés de la ligne et du '
          'verrou à taille nominale', (tester) async {
        await pumpBar(tester, _bid(), locale: locale, textScale: 1.3);
        expect(tester.takeException(), isNull);
        for (final label in [
          l.bidDetailDeclineRequestButton,
          l.bidDetailAcceptRequestButton,
        ]) {
          expect(
            labelScale(tester, find.widgetWithText(DonyButton, label), label),
            closeTo(1, 0.001),
            reason: label,
          );
        }

        await pumpBar(
          tester,
          _bid(
            status: 'ARRIVED',
            departureAt: DateTime.now().add(const Duration(days: 2)),
          ),
          locale: locale,
          textScale: 1.3,
        );
        expect(
          labelScale(
            tester,
            find.byKey(const Key('traveler-deliver-btn')),
            l.bidDetailHandoverLockedLabel,
          ),
          closeTo(1, 0.001),
        );
      });
    }
  });
}
