import 'dart:convert';

import 'package:dony/features/video_modal/bloc/video_modal_state.dart';
import 'package:dony/features/video_modal/data/datasources/video_modal_local_datasource.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/parcel_step.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_local_history.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:dony/features/video_modal/data/video_modal_moments.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../moment_test_support.dart';
import '../video_modal_test_data.dart';

/// Modals d'étape du colis, partie données : déclencheur par statut, rôles,
/// variables, historique « une fois par colis », boutons selon le rôle.
void main() {
  Future<void> noop(BuildContext _) async {}

  VideoModalMoment step(
    VideoModalTrigger trigger, {
    String bidId = 'bid-1',
    Set<ParcelRole> roles = const {ParcelRole.sender},
    Map<String, String> variables = const {},
    bool canSendCode = false,
    ParcelActionOpeners openers = const ParcelActionOpeners(),
  }) => VideoModalMoment.parcelStep(
    trigger: trigger,
    bidId: bidId,
    roles: roles,
    variables: variables,
    canSendCode: canSendCode,
    openers: openers,
  );

  VideoModalCampaign parcelCampaign({
    String id = 'p1',
    List<String> triggers = const ['PARCEL_ARRIVED'],
    List<String>? roles,
    String frequency = 'ONCE_PER_PARCEL',
    int priority = 0,
    Object? primary = const {'kind': 'SCREEN', 'screen': 'PARCEL_QR'},
    Object? secondary = const {'kind': 'CLOSE'},
  }) => VideoModalCampaign.tryParse(
    infoJson(
      id: id,
      triggers: triggers,
      primaryAction: primary,
      secondaryAction: secondary,
      extra: {
        'frequency': frequency,
        'priority': priority,
        'parcelRoles': ?roles,
      },
    ),
  )!;

  group('statut du colis vers déclencheur', () {
    test('les cinq statuts des rails ont leur étape', () {
      expect(
        VideoModalTrigger.forParcelStatus('ACCEPTED'),
        VideoModalTrigger.parcelAccepted,
      );
      expect(
        VideoModalTrigger.forParcelStatus('HANDED_OVER'),
        VideoModalTrigger.parcelHandedOver,
      );
      expect(
        VideoModalTrigger.forParcelStatus('IN_TRANSIT'),
        VideoModalTrigger.parcelInTransit,
      );
      expect(
        VideoModalTrigger.forParcelStatus('ARRIVED'),
        VideoModalTrigger.parcelArrived,
      );
      expect(
        VideoModalTrigger.forParcelStatus('COMPLETED'),
        VideoModalTrigger.parcelDelivered,
      );
    });

    test('outOfRailsStatus_emitsNoMoment : aucun déclencheur hors rails', () {
      for (final status in [
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
        '',
        'UNKNOWN_STATUS',
      ]) {
        expect(
          VideoModalTrigger.forParcelStatus(status),
          isNull,
          reason: status,
        );
      }
      expect(VideoModalTrigger.forParcelStatus(null), isNull);
    });
  });

  group('rôle sur le colis', () {
    test('campaignWithRoles_showsOnlyForMatchingRole', () {
      final c = parcelCampaign(roles: ['TRAVELER']);
      expect(c.parcelRoles, {ParcelRole.traveler});
      expect(
        step(
          VideoModalTrigger.parcelArrived,
          roles: {ParcelRole.traveler},
        ).accepts(c),
        isTrue,
      );
      expect(
        step(
          VideoModalTrigger.parcelArrived,
          roles: {ParcelRole.sender},
        ).accepts(c),
        isFalse,
      );
      expect(
        step(
          VideoModalTrigger.parcelArrived,
          roles: {ParcelRole.recipient},
        ).accepts(c),
        isFalse,
      );
    });

    test('emptyRoles_showsForAll', () {
      final c = parcelCampaign();
      expect(c.parcelRoles, isEmpty);
      for (final role in ParcelRole.values) {
        expect(
          step(VideoModalTrigger.parcelArrived, roles: {role}).accepts(c),
          isTrue,
          reason: role.wire,
        );
      }
    });

    test('expéditeur qui est son propre destinataire : les deux rôles', () {
      final recipientOnly = parcelCampaign(roles: ['RECIPIENT']);
      final senderOnly = parcelCampaign(roles: ['SENDER']);
      final travelerOnly = parcelCampaign(roles: ['TRAVELER']);
      final both = step(
        VideoModalTrigger.parcelArrived,
        roles: {ParcelRole.sender, ParcelRole.recipient},
      );
      expect(both.accepts(recipientOnly), isTrue);
      expect(both.accepts(senderOnly), isTrue);
      expect(both.accepts(travelerOnly), isFalse);
    });

    test("l'étape doit être celle de la campagne", () {
      final c = parcelCampaign(triggers: ['PARCEL_ARRIVED']);
      expect(step(VideoModalTrigger.parcelAccepted).accepts(c), isFalse);
    });

    test('campaignWithoutParcelTrigger_unaffected', () {
      final delivery = VideoModalCampaign.tryParse(
        infoJson(triggers: ['DELIVERY_CONFIRMED']),
      )!;
      // Une étape de colis n'ouvre pas une campagne d'un autre moment…
      expect(
        step(VideoModalTrigger.parcelDelivered).accepts(delivery),
        isFalse,
      );
      // … et un moment d'action garde ses règles, rôles ignorés.
      final withRoles = VideoModalCampaign.tryParse(
        infoJson(
          triggers: ['DELIVERY_CONFIRMED'],
          extra: {
            'parcelRoles': ['TRAVELER'],
          },
        ),
      )!;
      final action = VideoModalMoment.action(
        VideoModalTrigger.deliveryConfirmed,
      );
      expect(action.accepts(delivery), isTrue);
      expect(action.accepts(withRoles), isTrue);
      expect(action.parcel, isNull);
      // Une campagne d'étape n'est pas ouverte par un moment d'action.
      expect(action.accepts(parcelCampaign()), isFalse);
    });

    test('unknownParcelTrigger_ignored : déclencheur inconnu de cette app', () {
      expect(
        VideoModalCampaign.tryParse(infoJson(triggers: ['PARCEL_LOST'])),
        isNull,
      );
      final mixed = VideoModalCampaign.tryParse(
        infoJson(triggers: ['PARCEL_LOST', 'PARCEL_ARRIVED']),
      )!;
      expect(mixed.triggers, {VideoModalTrigger.parcelArrived});
    });

    test('égalité : même colis, même étape, mêmes rôles et variables', () {
      Future<void> other(BuildContext _) async {}
      final a = step(
        VideoModalTrigger.parcelArrived,
        variables: const {'voyageur': 'Moussa'},
        openers: ParcelActionOpeners(qr: noop),
      );
      final b = step(
        VideoModalTrigger.parcelArrived,
        variables: const {'voyageur': 'Moussa'},
        openers: ParcelActionOpeners(qr: other),
      );
      expect(a, b);
      expect(
        a == step(VideoModalTrigger.parcelArrived, bidId: 'bid-2'),
        isFalse,
      );
    });
  });

  group('variables des textes', () {
    const fallbacks = {
      'destinataire': 'votre destinataire',
      'voyageur': 'votre voyageur',
      'expéditeur': "l'expéditeur",
      'ville_arrivee': "la ville d'arrivée",
    };

    String fill(String text, Map<String, String> values) =>
        fillParcelVariables(text, values: values, fallbacks: fallbacks);

    test('variablesFilledWithFallback : noms remplis, sinon repli', () {
      expect(
        fill('{voyageur} arrive à {ville_arrivee} pour {destinataire}.', {
          'voyageur': 'Moussa',
          'ville_arrivee': 'Dakar',
          'destinataire': 'Awa',
        }),
        'Moussa arrive à Dakar pour Awa.',
      );
      expect(
        fill(
          'Prévenez {destinataire} : {expéditeur} attend à {ville_arrivee}.',
          {'destinataire': '   ', 'expéditeur': ''},
        ),
        "Prévenez votre destinataire : l'expéditeur attend à la ville d'arrivée.",
      );
    });

    test('repli en tête de phrase : majuscule, le nom reste tel quel', () {
      expect(
        fill('{destinataire} peut retirer le colis. {voyageur} est là.', {}),
        'Votre destinataire peut retirer le colis. Votre voyageur est là.',
      );
      expect(
        fill('{voyageur} est là.', {'voyageur': 'moussa'}),
        'moussa est là.',
      );
    });

    test('seules les quatre variables connues sont remplacées', () {
      expect(
        fill('Code {code}, {inconnu} et {Voyageur} pour {voyageur}', {
          'voyageur': 'Moussa',
          'code': '482913',
        }),
        'Code {code}, {inconnu} et {Voyageur} pour Moussa',
      );
    });

    test("un nom qui contient une variable n'est pas réinterprété", () {
      expect(
        fill('{voyageur} et {destinataire}', {
          'voyageur': '{destinataire}',
          'destinataire': 'Awa',
        }),
        '{destinataire} et Awa',
      );
    });

    test('noms coupés de leurs espaces de bord', () {
      expect(fill('[{voyageur}]', {'voyageur': '  Moussa  '}), '[Moussa]');
    });
  });

  group('historique « une fois par colis »', () {
    test('hasShownForParcel / recordShownForParcel', () {
      const empty = VideoModalLocalHistory();
      expect(empty.hasShownForParcel('c1', 1, 'bid-1'), isFalse);
      final once = empty.recordShownForParcel('c1', 1, 'bid-1');
      expect(once.hasShownForParcel('c1', 1, 'bid-1'), isTrue);
      // Autre colis, autre version, autre campagne : pas encore affiché.
      expect(once.hasShownForParcel('c1', 1, 'bid-2'), isFalse);
      expect(once.hasShownForParcel('c1', 2, 'bid-1'), isFalse);
      expect(once.hasShownForParcel('c2', 1, 'bid-1'), isFalse);
      // Réafficher le même ne duplique pas l'entrée.
      expect(
        once.recordShownForParcel('c1', 1, 'bid-1').parcelShown,
        hasLength(1),
      );
    });

    test('borné aux 200 plus récents, les plus anciens partent', () {
      var h = const VideoModalLocalHistory();
      for (var i = 0; i < 205; i++) {
        h = h.recordShownForParcel('c1', 1, 'bid-$i');
      }
      expect(VideoModalLocalHistory.maxParcelEntries, 200);
      expect(h.parcelShown, hasLength(200));
      expect(h.hasShownForParcel('c1', 1, 'bid-0'), isFalse);
      expect(h.hasShownForParcel('c1', 1, 'bid-4'), isFalse);
      expect(h.hasShownForParcel('c1', 1, 'bid-5'), isTrue);
      expect(h.hasShownForParcel('c1', 1, 'bid-204'), isTrue);
      // Un colis réaffiché remonte en tête : il survit aux suivants.
      h = h.recordShownForParcel('c1', 1, 'bid-5');
      h = h.recordShownForParcel('c1', 1, 'bid-new');
      expect(h.hasShownForParcel('c1', 1, 'bid-5'), isTrue);
      expect(h.hasShownForParcel('c1', 1, 'bid-6'), isFalse);
    });

    test('les réponses des visiteurs gardent les affichages par colis', () {
      final h = const VideoModalLocalHistory()
          .recordShownForParcel('c1', 1, 'bid-1')
          .apply('c9', 1, VideoModalEventType.shown);
      expect(h.hasShownForParcel('c1', 1, 'bid-1'), isTrue);
    });

    test(
      'ONCE_PER_PARCEL : une réponse ne bloque pas, « Ne plus afficher » oui',
      () {
        final c = infoCampaign(
          triggers: {VideoModalTrigger.parcelArrived},
          frequency: VideoModalFrequency.oncePerParcel,
        );
        expect(c.stopAfterAnswer, isTrue);
        final answered = const VideoModalLocalHistory()
            .apply(c.id, c.version, VideoModalEventType.shown)
            .apply(c.id, c.version, VideoModalEventType.opened);
        expect(answered.isEligible(c), isTrue);
        final never = answered.apply(
          c.id,
          c.version,
          VideoModalEventType.dontShowAgain,
        );
        expect(never.isEligible(c), isFalse);
      },
    );

    group('stockage', () {
      setUp(() => SharedPreferences.setMockInitialValues({}));

      test(
        'clé à part, jamais effacée par la synchro de la connexion',
        () async {
          final local = VideoModalLocalDatasource();
          await local.writeParcelShown(
            const VideoModalLocalHistory()
                .recordShownForParcel('c1', 1, 'bid-1')
                .parcelShown,
          );
          await local.writeHistory(
            const VideoModalLocalHistory().apply(
              'c9',
              1,
              VideoModalEventType.shown,
            ),
          );
          expect(
            (await local.readHistory()).hasShownForParcel('c1', 1, 'bid-1'),
            isTrue,
          );
          await local.clear();
          final after = await local.readHistory();
          expect(after.campaigns, isEmpty);
          expect(after.hasShownForParcel('c1', 1, 'bid-1'), isTrue);
          final prefs = await SharedPreferences.getInstance();
          expect(
            jsonDecode(
              prefs.getString(VideoModalLocalDatasource.parcelShownKey)!,
            ),
            isA<List<Object?>>(),
          );
        },
      );

      test('valeur illisible : historique vide, sans exception', () async {
        SharedPreferences.setMockInitialValues({
          VideoModalLocalDatasource.parcelShownKey: '{pas du json',
        });
        expect(await VideoModalLocalDatasource().readParcelShown(), isEmpty);
        SharedPreferences.setMockInitialValues({
          VideoModalLocalDatasource.parcelShownKey: jsonEncode([1, 'ok', null]),
        });
        expect(await VideoModalLocalDatasource().readParcelShown(), ['ok']);
      });

      test('VideoModalMoments : écrit puis relit par colis', () async {
        final moments = VideoModalMoments(appVersion: () async => '1.0.0');
        addTearDown(moments.dispose);
        expect(await moments.hasShownForParcel('c1', 1, 'bid-1'), isFalse);
        await moments.recordShownForParcel('c1', 1, 'bid-1');
        expect(moments.shownForParcelNow('c1', 1, 'bid-1'), isTrue);
        expect(await moments.hasShownForParcel('c1', 1, 'bid-1'), isTrue);
        expect(await moments.hasShownForParcel('c1', 1, 'bid-2'), isFalse);
        // Un nouveau lancement relit le téléphone.
        final next = VideoModalMoments(appVersion: () async => '1.0.0');
        addTearDown(next.dispose);
        expect(await next.hasShownForParcel('c1', 1, 'bid-1'), isTrue);
      });
    });
  });

  group('notifyParcelStep', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('émet le moment, historique du téléphone lu avant', () async {
      SharedPreferences.setMockInitialValues({
        VideoModalLocalDatasource.parcelShownKey: jsonEncode([
          VideoModalLocalHistory.parcelKey('c1', 1, 'bid-1'),
        ]),
      });
      final moments = useRecordingMoments();
      VideoModalMoments.notifyParcelStep(step(VideoModalTrigger.parcelArrived));
      await pumpEventQueue();
      expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
      expect(moments.shownForParcelNow('c1', 1, 'bid-1'), isTrue);
    });

    test('déclencheur qui n\'est pas une étape de colis : ignoré', () async {
      final moments = useRecordingMoments();
      VideoModalMoments.notifyParcelStep(
        VideoModalMoment.parcelStep(
          trigger: VideoModalTrigger.deliveryConfirmed,
          bidId: 'bid-1',
          roles: const {ParcelRole.sender},
          variables: const {},
        ),
      );
      VideoModalMoments.notifyParcelStep(
        VideoModalMoment.action(VideoModalTrigger.deliveryConfirmed),
      );
      VideoModalMoments.notifyParcelStep(
        step(VideoModalTrigger.parcelArrived, bidId: ''),
      );
      VideoModalMoments.notifyParcelStep(
        step(VideoModalTrigger.parcelArrived, roles: const {}),
      );
      await pumpEventQueue();
      expect(moments.emitted, isEmpty);
    });

    test(
      'stockage illisible : le moment part quand même, sans exception',
      () async {
        final moments = _BrokenStorageMoments();
        addTearDown(moments.dispose);
        await moments.emitParcelStep(step(VideoModalTrigger.parcelArrived));
        expect(moments.emitted, hasLength(1));
        expect(moments.shownForParcelNow('c1', 1, 'bid-1'), isFalse);
        await moments.recordShownForParcel('c1', 1, 'bid-1');
        expect(await moments.hasShownForParcel('c1', 1, 'bid-2'), isFalse);
      },
    );
  });

  group('session : une fois par colis ignore la limite de la session', () {
    test('ni bloquée par la case occupée ni par le plafond de la version', () {
      final c = parcelCampaign();
      final capped = VideoModalCampaign.tryParse(
        infoJson(
          id: 'p2',
          triggers: ['PARCEL_ARRIVED'],
          extra: {
            'frequency': 'ONCE_PER_PARCEL',
            'maxDisplays': 1,
            'displays': 9,
          },
        ),
      )!;
      expect(c.ignoresSessionLimit, isTrue);
      expect(capped.underDisplayCap, isTrue);
      final state = VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [c],
        usedSlots: VideoModalSlot.values.toSet(),
      );
      expect(
        state.candidateForMoment(step(VideoModalTrigger.parcelArrived)),
        c,
      );
    });

    test('déjà affichée pour ce colis : campagne suivante', () {
      final first = parcelCampaign(priority: 5);
      final second = parcelCampaign(id: 'p2');
      final state = VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [first, second],
      );
      expect(
        state.candidateForMoment(
          step(VideoModalTrigger.parcelArrived),
          shownForParcel: (c) => c.id == 'p1',
        ),
        second,
      );
      expect(
        state.candidateForMoment(
          step(VideoModalTrigger.parcelArrived),
          shownForParcel: (_) => true,
        ),
        isNull,
      );
    });

    test('une campagne d\'étape à fréquence classique garde la limite', () {
      final c = parcelCampaign(frequency: 'ONCE');
      final state = VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [c],
        usedSlots: const {VideoModalSlot.infoMoment},
      );
      expect(
        state.candidateForMoment(step(VideoModalTrigger.parcelArrived)),
        isNull,
      );
    });

    test('« Ne plus afficher » écarte la version pour la session', () {
      final c = parcelCampaign();
      final state = VideoModalState(
        status: VideoModalStatus.ready,
        campaigns: [c],
        suppressed: {VideoModalState.suppressionKey(c)},
      );
      expect(
        state.candidateForMoment(step(VideoModalTrigger.parcelArrived)),
        isNull,
      );
    });
  });

  group('boutons du colis selon le rôle', () {
    ParcelActionContext ctx(
      Set<ParcelRole> roles, {
      bool canSendCode = true,
      ParcelActionOpeners? openers,
    }) => ParcelActionContext(
      bidId: 'bid-1',
      roles: roles,
      canSendCode: canSendCode,
      openers:
          openers ??
          ParcelActionOpeners(qr: noop, sendCode: noop, tracking: noop),
    );

    test('qrButtonHiddenForRecipient', () {
      expect(ctx({ParcelRole.recipient}).canRun(InfoScreen.parcelQr), isFalse);
      expect(ctx({ParcelRole.traveler}).canRun(InfoScreen.parcelQr), isFalse);
      expect(ctx({ParcelRole.sender}).canRun(InfoScreen.parcelQr), isTrue);
      expect(
        ctx({
          ParcelRole.sender,
          ParcelRole.recipient,
        }).canRun(InfoScreen.parcelQr),
        isTrue,
      );
    });

    test(
      'sendCodeButtonHiddenWithoutCode : expéditeur seulement, code présent',
      () {
        expect(
          ctx({ParcelRole.sender}).canRun(InfoScreen.parcelSendCode),
          isTrue,
        );
        expect(
          ctx({
            ParcelRole.sender,
          }, canSendCode: false).canRun(InfoScreen.parcelSendCode),
          isFalse,
        );
        expect(
          ctx({ParcelRole.traveler}).canRun(InfoScreen.parcelSendCode),
          isFalse,
        );
        expect(
          ctx({ParcelRole.recipient}).canRun(InfoScreen.parcelSendCode),
          isFalse,
        );
      },
    );

    test('suivi et détail : pour tous, si l\'écran sait les ouvrir', () {
      for (final role in ParcelRole.values) {
        expect(ctx({role}).canRun(InfoScreen.parcelTracking), isTrue);
        expect(ctx({role}).canRun(InfoScreen.parcelDetail), isTrue);
      }
      expect(
        ctx(
          {ParcelRole.sender},
          openers: const ParcelActionOpeners(),
        ).canRun(InfoScreen.parcelTracking),
        isFalse,
      );
      // Les écrans qui ne sont pas des écrans de colis restent possibles.
      expect(ctx({ParcelRole.sender}).canRun(InfoScreen.myMoney), isTrue);
    });

    test(
      'détail : la fiche colis, ou la réception pour le seul destinataire',
      () {
        expect(ctx({ParcelRole.sender}).detailRoute, '/bids/bid-1');
        expect(ctx({ParcelRole.traveler}).detailRoute, '/bids/bid-1');
        expect(
          ctx({ParcelRole.sender, ParcelRole.recipient}).detailRoute,
          '/bids/bid-1',
        );
        expect(ctx({ParcelRole.recipient}).detailRoute, '/receptions/bid-1');
      },
    );
  });

  group('campagne adaptée au colis (textes et boutons)', () {
    String fill(String t) => t.replaceAll('{voyageur}', 'Moussa');

    test('textes : titre, sous-titre, texte et libellés', () {
      final c = VideoModalCampaign.tryParse(
        infoJson(
          triggers: ['PARCEL_ARRIVED'],
          primaryAction: const {'kind': 'CLOSE'},
          secondaryAction: null,
          extra: {
            'title': '{voyageur} est arrivé',
            'subtitle': 'Avec {voyageur}',
            'body': 'Appelez {voyageur}.',
            'primaryLabel': 'Merci {voyageur}',
          },
        ),
      )!;
      final out = c.withParcelStep(fill: fill, canRun: (_) => true);
      expect(out.title, 'Moussa est arrivé');
      expect(out.subtitle, 'Avec Moussa');
      expect(out.body, 'Appelez Moussa.');
      expect(out.primaryLabel, 'Merci Moussa');
      expect(out.id, c.id);
      expect(out.version, c.version);
      expect(out.frequency, c.frequency);
      expect(out.priority, c.priority);
      expect(out.triggers, c.triggers);
    });

    test('bouton principal masqué : le secondaire devient le seul bouton', () {
      final c = parcelCampaign(
        secondary: const {'kind': 'SCREEN', 'screen': 'PARCEL_TRACKING'},
      );
      final out = c.withParcelStep(
        fill: (t) => t,
        canRun: (s) => s != InfoScreen.parcelQr,
      );
      expect(
        out.primaryAction,
        const VideoModalAction.openScreen(InfoScreen.parcelTracking),
      );
      expect(out.primaryLabel, c.secondaryLabel);
      expect(out.secondaryAction, isNull);
      expect(out.secondaryLabel, isNull);
    });

    test('bouton secondaire masqué : seul le principal reste', () {
      final c = parcelCampaign(
        primary: const {'kind': 'SCREEN', 'screen': 'PARCEL_TRACKING'},
        secondary: const {'kind': 'SCREEN', 'screen': 'PARCEL_SEND_CODE'},
      );
      final out = c.withParcelStep(
        fill: (t) => t,
        canRun: (s) => s != InfoScreen.parcelSendCode,
      );
      expect(
        out.primaryAction,
        const VideoModalAction.openScreen(InfoScreen.parcelTracking),
      );
      expect(out.primaryLabel, c.primaryLabel);
      expect(out.secondaryAction, isNull);
    });

    test('les deux masqués : un modal qui se ferme seulement', () {
      final c = parcelCampaign(
        secondary: const {'kind': 'SCREEN', 'screen': 'PARCEL_SEND_CODE'},
      );
      final out = c.withParcelStep(fill: (t) => t, canRun: (_) => false);
      expect(out.primaryAction, const VideoModalAction.close());
      expect(out.primaryLabel, isNull);
      expect(out.secondaryAction, isNull);
      final alone = parcelCampaign(secondary: null);
      final closeOnly = alone.withParcelStep(
        fill: (t) => t,
        canRun: (_) => false,
      );
      expect(closeOnly.primaryAction, const VideoModalAction.close());
      expect(closeOnly.secondaryAction, isNull);
    });

    test('liens, fermeture et écrans hors colis : jamais masqués', () {
      final c = parcelCampaign(
        primary: const {'kind': 'URL', 'url': 'https://yadony.com/aide'},
        secondary: const {'kind': 'SCREEN', 'screen': 'MY_MONEY'},
      );
      final out = c.withParcelStep(fill: (t) => t, canRun: (_) => false);
      expect(out.primaryAction, c.primaryAction);
      expect(out.secondaryAction, c.secondaryAction);
    });
  });
}

/// Service dont le stockage échoue toujours : le moment part sans historique.
class _BrokenStorageMoments extends VideoModalMoments {
  _BrokenStorageMoments()
    : super(local: _BrokenLocal(), appVersion: () async => '1.0.0');

  final List<VideoModalMoment> emitted = [];

  @override
  void emit(VideoModalMoment moment, {BuildContext? origin}) =>
      emitted.add(moment);
}

class _BrokenLocal extends VideoModalLocalDatasource {
  @override
  Future<List<String>> readParcelShown() => throw StateError('illisible');

  @override
  Future<void> writeParcelShown(List<String> keys) =>
      throw StateError('illisible');
}
