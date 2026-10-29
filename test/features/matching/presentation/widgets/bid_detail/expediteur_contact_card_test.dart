import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockConvBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _FakeConversationOpenEvent extends Fake
    implements ConversationOpenEvent {}

BidModel _bid({
  String status = 'ACCEPTED',
  bool senderPhoneAvailable = true,
  bool? contactWindowOpen,
  DateTime? returnDeadline,
  DateTime? returnedAt,
  String? senderName = 'Mariama D.',
  String senderId = 's1',
  int? senderTotalShipments,
  bool senderKycVerified = true,
  bool senderGpPro = false,
}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: senderId,
  status: status,
  weightKg: 5,
  senderName: senderName,
  senderPhoneAvailable: senderPhoneAvailable,
  contactWindowOpen: contactWindowOpen,
  returnDeadline: returnDeadline,
  returnedAt: returnedAt,
  senderTotalShipments: senderTotalShipments,
  senderKycVerified: senderKycVerified,
  senderGpPro: senderGpPro,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

_MockConvBloc _convBloc([
  ConversationOpenState state = const ConversationOpenInitial(),
]) {
  final conv = _MockConvBloc();
  when(() => conv.state).thenReturn(state);
  return conv;
}

Future<void> _pump(
  WidgetTester tester,
  BidModel bid, {
  ConversationOpenBloc? conv,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: BlocProvider<ConversationOpenBloc>.value(
          value: conv ?? _convBloc(),
          child: ExpediteurContactCard(bid: bid),
        ),
      ),
    ),
  );
}

Finder _icon(String name) =>
    find.byWidgetPredicate((w) => w is DonyIcon && w.name == name);

/// Le bouton rond « Contacter » : icône conversation.
Finder get _contactIcon => _icon('messages-square');

/// Anciens boutons, retirés : téléphone et bulle simple.
Finder get _phoneIcon => _icon('phone');
Finder get _oldChatIcon => _icon('message-circle');

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeConversationOpenEvent());
  });

  group('bouton « Contacter » unique', () {
    testWidgets('un seul bouton rond, icône conversation, jamais d\'appel', (
      tester,
    ) async {
      await _pump(tester, _bid());
      expect(find.text('EXPÉDITEUR'), findsOneWidget);
      expect(find.text('Mariama D.'), findsOneWidget);
      expect(_contactIcon, findsOneWidget);
      expect(_phoneIcon, findsNothing);
      expect(_oldChatIcon, findsNothing);
    });

    testWidgets('nom annoncé « Contacter l\'expéditeur » (FR)', (tester) async {
      await _pump(tester, _bid());
      expect(_semanticsLabel("Contacter l'expéditeur"), findsOneWidget);
      expect(_semanticsLabel('Appeler'), findsNothing);
    });

    testWidgets('nom annoncé « Contact the sender » (EN)', (tester) async {
      useEnglish();
      await _pump(tester, _bid());
      expect(_semanticsLabel('Contact the sender'), findsOneWidget);
      expect(_semanticsLabel('Call'), findsNothing);
    });

    testWidgets('l\'expéditeur joignable ne fait pas réapparaître 📞', (
      tester,
    ) async {
      for (final available in [true, false]) {
        await _pump(
          tester,
          _bid(
            status: 'IN_TRANSIT',
            senderPhoneAvailable: available,
            contactWindowOpen: true,
          ),
        );
        expect(_phoneIcon, findsNothing);
        expect(_contactIcon, findsOneWidget);
      }
    });

    testWidgets('tap → ConversationOpenRequested(bid.id), une seule fois', (
      tester,
    ) async {
      final conv = _convBloc();
      await _pump(tester, _bid(), conv: conv);
      await tester.tap(_contactIcon);
      await tester.pumpAndSettle();
      final captured = verify(() => conv.add(captureAny())).captured;
      expect(captured, hasLength(1));
      expect(captured.single, isA<ConversationOpenRequested>());
      expect((captured.single as ConversationOpenRequested).bidId, 'b1');
    });

    testWidgets('ouverture en cours → spinner et bouton désactivé', (
      tester,
    ) async {
      final conv = _convBloc(const ConversationOpenLoading());
      await _pump(tester, _bid(), conv: conv);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_contactIcon, findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == "Contacter l'expéditeur" &&
              w.properties.enabled == false,
        ),
        findsOneWidget,
      );
      verifyNever(() => conv.add(any()));
    });

    testWidgets('tap sur la carte → profil public de l\'expéditeur', (
      tester,
    ) async {
      final pushed = <Object?>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BlocProvider<ConversationOpenBloc>.value(
                value: _convBloc(),
                child: ExpediteurContactCard(bid: _bid()),
              ),
            ),
          ),
          GoRoute(
            path: '/profile/public',
            builder: (_, state) {
              pushed.add(state.extra);
              return const Scaffold(body: Text('profil-public'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.tap(find.text('Mariama D.'));
      await tester.pumpAndSettle();
      expect(find.text('profil-public'), findsOneWidget);
      expect(pushed.single, isA<ProfilePublicArgs>());
    });
  });

  group('condition d\'affichage du bouton par statut', () {
    // Bouton présent : demande acceptée ou au-delà (bidContactStatuses).
    for (final status in [
      'ACCEPTED',
      'HANDED_OVER',
      'IN_TRANSIT',
      'ARRIVED',
      'COMPLETED',
      'DELIVERED',
    ]) {
      testWidgets('$status → bouton, aucun indice', (tester) async {
        await _pump(tester, _bid(status: status));
        expect(_contactIcon, findsOneWidget);
        expect(
          find.byKey(const Key('contact-after-acceptance-hint')),
          findsNothing,
        );
      });
    }

    // Avant l'acceptation : profil seul + indice qui dit pourquoi (FLUTTER-4T).
    for (final status in ['PENDING', 'PAYMENT_ESCROWED']) {
      testWidgets('$status → pas de bouton, indice « une fois acceptée »', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status));
        expect(_contactIcon, findsNothing);
        expect(
          find.text(
            "Vous pourrez contacter l'expéditeur une fois la demande acceptée.",
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('AWAITING_PAYMENT → pas de bouton, indice « paiement »', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'AWAITING_PAYMENT'));
      expect(_contactIcon, findsNothing);
      expect(
        find.text(
          "Vous pourrez contacter l'expéditeur dès que son paiement sera confirmé.",
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "Vous pourrez contacter l'expéditeur une fois la demande acceptée.",
        ),
        findsNothing,
      );
    });

    testWidgets('AWAITING_PAYMENT en anglais → indice traduit', (tester) async {
      useEnglish();
      await _pump(tester, _bid(status: 'AWAITING_PAYMENT'));
      expect(_contactIcon, findsNothing);
      expect(
        find.byKey(const Key('contact-after-acceptance-hint')),
        findsOneWidget,
      );
    });

    // Statuts clos hors fenêtre : profil seul, sans bouton ni indice.
    for (final status in [
      'REJECTED',
      'NO_SHOW',
      'EXPIRED',
      'PARCEL_REFUSED',
      'CANCELLED',
    ]) {
      testWidgets('$status sans fenêtre → profil seul, sans indice', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status));
        expect(_contactIcon, findsNothing);
        expect(_phoneIcon, findsNothing);
        expect(
          find.byKey(const Key('contact-after-acceptance-hint')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('contact-cancelled-window-hint')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('contact-return-in-progress-hint')),
          findsNothing,
        );
      });
    }

    for (final status in ['REJECTED', 'NO_SHOW', 'EXPIRED', 'PARCEL_REFUSED']) {
      testWidgets('$status même avec contactWindowOpen → pas de bouton', (
        tester,
      ) async {
        await _pump(tester, _bid(status: status, contactWindowOpen: true));
        expect(_contactIcon, findsNothing);
      });
    }

    // La fenêtre de contact ne change plus rien pour COMPLETED : le bouton
    // ouvre la messagerie, qui gère elle-même l'appel (J+3).
    for (final open in [true, false, null]) {
      testWidgets('COMPLETED, fenêtre $open → bouton présent', (tester) async {
        await _pump(tester, _bid(status: 'COMPLETED', contactWindowOpen: open));
        expect(_contactIcon, findsOneWidget);
        expect(_phoneIcon, findsNothing);
      });
    }
  });

  group('colis annulé', () {
    // Retour en cours d'un colis annulé après remise (FLUTTER-FM).
    testWidgets('retour en cours : bouton + indication, sans appel', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          contactWindowOpen: true,
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      expect(_contactIcon, findsOneWidget);
      expect(_phoneIcon, findsNothing);
      expect(
        find.text(
          "Retour en cours : contactez l'expéditeur pour lui rendre son colis.",
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('contact-cancelled-window-hint')),
        findsNothing,
      );
    });

    testWidgets('retour en cours sans le champ (ancien back) : délai lu', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      expect(_contactIcon, findsOneWidget);
    });

    testWidgets('colis restitué : plus de bouton ni d\'indication', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          contactWindowOpen: false,
          returnDeadline: DateTime.now().add(const Duration(days: 2)),
          returnedAt: DateTime.now(),
        ),
      );
      expect(_contactIcon, findsNothing);
      expect(
        find.byKey(const Key('contact-return-in-progress-hint')),
        findsNothing,
      );
    });

    // FLUTTER-P1 : contact gardé 48 h après l'annulation, sur décision serveur.
    testWidgets('fenêtre de 48 h ouverte : bouton + indication', (
      tester,
    ) async {
      await _pump(tester, _bid(status: 'CANCELLED', contactWindowOpen: true));
      expect(_contactIcon, findsOneWidget);
      expect(
        find.byKey(const Key('contact-cancelled-window-hint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('contact-return-in-progress-hint')),
        findsNothing,
      );
    });

    testWidgets('fenêtre ouverte, numéro non servi : le bouton reste', (
      tester,
    ) async {
      await _pump(
        tester,
        _bid(
          status: 'CANCELLED',
          contactWindowOpen: true,
          senderPhoneAvailable: false,
        ),
      );
      expect(_contactIcon, findsOneWidget);
    });

    testWidgets('annulé sans le champ (ancien back) : fermé', (tester) async {
      await _pump(tester, _bid(status: 'CANCELLED'));
      expect(_contactIcon, findsNothing);
      expect(
        find.byKey(const Key('contact-cancelled-window-hint')),
        findsNothing,
      );
    });

    testWidgets('annulé, fenêtre fermée : aucun bouton', (tester) async {
      await _pump(tester, _bid(status: 'CANCELLED', contactWindowOpen: false));
      expect(_contactIcon, findsNothing);
    });
  });

  group('profil de l\'expéditeur', () {
    testWidgets('chip Identité si senderKycVerified', (tester) async {
      await _pump(tester, _bid());
      expect(find.text('Identité'), findsOneWidget);
    });

    testWidgets('pas de chip Identité sinon', (tester) async {
      await _pump(tester, _bid(senderKycVerified: false));
      expect(find.text('Identité'), findsNothing);
    });

    testWidgets('badge GP Pro si senderGpPro', (tester) async {
      await _pump(tester, _bid(senderGpPro: true));
      expect(find.byType(GpProBadge), findsOneWidget);
    });

    testWidgets('pas de badge GP Pro sinon', (tester) async {
      await _pump(tester, _bid());
      expect(find.byType(GpProBadge), findsNothing);
    });

    testWidgets('envois au pluriel', (tester) async {
      await _pump(tester, _bid(senderTotalShipments: 3));
      expect(find.textContaining('3 envois'), findsOneWidget);
    });

    testWidgets('envoi au singulier', (tester) async {
      await _pump(tester, _bid(senderTotalShipments: 1));
      expect(find.textContaining('1 envoi'), findsOneWidget);
    });

    testWidgets('senderTotalShipments null → pas de texte envois', (
      tester,
    ) async {
      await _pump(tester, _bid());
      expect(find.textContaining('envoi'), findsNothing);
    });

    testWidgets('sans nom → « Expéditeur »', (tester) async {
      await _pump(tester, _bid(senderName: null));
      expect(find.text('Expéditeur'), findsOneWidget);
    });

    testWidgets('chevron vers le profil si senderId connu', (tester) async {
      await _pump(tester, _bid());
      expect(_icon('chevron-right'), findsOneWidget);
    });

    testWidgets('senderId vide → pas de chevron', (tester) async {
      await _pump(tester, _bid(senderId: ''));
      expect(_icon('chevron-right'), findsNothing);
    });

    testWidgets('anglais — rôle, nom et compteur d\'envois traduits', (
      tester,
    ) async {
      useEnglish();
      await _pump(tester, _bid(senderTotalShipments: 3));
      expect(find.text('SENDER'), findsOneWidget);
      expect(find.text('Mariama D.'), findsOneWidget);
      expect(find.textContaining('3 shipments'), findsOneWidget);
    });
  });
}
