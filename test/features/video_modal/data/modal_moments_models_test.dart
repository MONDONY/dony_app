import 'package:dony/features/video_modal/bloc/video_modal_state.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_corridor.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video_modal_test_data.dart';

VideoModalMomentCorridor _parisAbidjan() => VideoModalMomentCorridor(
  fromCity: 'Paris',
  fromCountryCode: 'FR',
  toCity: 'Abidjan',
  toCountryCode: 'CI',
);

void main() {
  group('normalizeCorridorText', () {
    test('sans casse, sans accent, sans espace ni ponctuation de mot', () {
      expect(normalizeCorridorText("Côte d'Ivoire"), 'cotedivoire');
      expect(normalizeCorridorText('COTE-D’IVOIRE'), 'cotedivoire');
      expect(normalizeCorridorText('  Saint Denis '), 'saintdenis');
      expect(normalizeCorridorText('Saint-Denis'), 'saintdenis');
      expect(normalizeCorridorText('Ségou'), 'segou');
      expect(normalizeCorridorText(null), '');
      expect(normalizeCorridorText('   '), '');
    });
  });

  group('VideoModalMomentCorridor', () {
    test(
      'garde ville, code pays et noms du pays en français et en anglais',
      () {
        final c = _parisAbidjan();
        expect(c.from, containsAll(['paris', 'fr', 'france']));
        expect(c.to, containsAll(['abidjan', 'ci', 'cotedivoire']));
        expect(c.isEmpty, isFalse);
      },
    );

    test('sans rien de connu : vide', () {
      expect(VideoModalMomentCorridor().isEmpty, isTrue);
      expect(VideoModalMomentCorridor.empty.isEmpty, isTrue);
      expect(VideoModalMomentCorridor(fromCity: ' ').isEmpty, isTrue);
    });

    test('un code pays inconnu est gardé tel quel', () {
      final c = VideoModalMomentCorridor(fromCountryCode: 'zz');
      expect(c.from, {'zz'});
    });
  });

  group('VideoModalCorridor', () {
    test('tryParse : côtés nuls, vides ou texte ; autre type refusé', () {
      expect(
        VideoModalCorridor.tryParse({'from': 'Paris', 'to': ' Abidjan '}),
        const VideoModalCorridor(from: 'Paris', to: 'Abidjan'),
      );
      expect(
        VideoModalCorridor.tryParse({'from': null, 'to': 'Dakar'}),
        const VideoModalCorridor(to: 'Dakar'),
      );
      expect(
        VideoModalCorridor.tryParse({'from': '  ', 'to': 'Dakar'}),
        const VideoModalCorridor(to: 'Dakar'),
      );
      expect(VideoModalCorridor.tryParse({'from': 3}), isNull);
      expect(VideoModalCorridor.tryParse('Paris'), isNull);
    });

    test(
      'correspond sans tenir compte de la casse, des accents, des espaces',
      () {
        final c = _parisAbidjan();
        expect(
          const VideoModalCorridor(from: ' PARIS ', to: 'abidjan').matches(c),
          isTrue,
        );
        expect(
          const VideoModalCorridor(to: "cote d'ivoire").matches(c),
          isTrue,
        );
        expect(const VideoModalCorridor(from: 'france').matches(c), isTrue);
        expect(
          const VideoModalCorridor(from: 'Lyon', to: 'Abidjan').matches(c),
          isFalse,
        );
        expect(
          const VideoModalCorridor(from: 'Paris', to: 'Dakar').matches(c),
          isFalse,
        );
        // Le départ ne se compare pas à l'arrivée.
        expect(const VideoModalCorridor(from: 'Abidjan').matches(c), isFalse);
      },
    );

    test('un moment sans corridor connu ne correspond à aucune entrée', () {
      const entry = VideoModalCorridor(from: 'Paris');
      expect(entry.matches(null), isFalse);
      expect(entry.matches(VideoModalMomentCorridor.empty), isFalse);
    });

    test('une entrée sans côté correspond à tout corridor connu', () {
      expect(const VideoModalCorridor().matches(_parisAbidjan()), isTrue);
    });
  });

  group('VideoModalTriggerOptions', () {
    test('défauts : 2 et 3', () {
      const o = VideoModalTriggerOptions();
      expect(o.fewResultsMax, 2);
      expect(o.tripViewedTimes, 3);
      expect(VideoModalTriggerOptions.parse(null), o);
      expect(VideoModalTriggerOptions.parse('x'), o);
      expect(VideoModalTriggerOptions.parse(const <String, Object?>{}), o);
    });

    test('valeurs lues dans les bornes', () {
      final o = VideoModalTriggerOptions.parse({
        'fewResultsMax': 5,
        'tripViewedTimes': 4.0,
      });
      expect(o.fewResultsMax, 5);
      expect(o.tripViewedTimes, 4);
    });

    test('hors bornes ou illisible : valeur par défaut', () {
      final o = VideoModalTriggerOptions.parse({
        'fewResultsMax': 21,
        'tripViewedTimes': 1,
      });
      expect(o, const VideoModalTriggerOptions());
      expect(
        VideoModalTriggerOptions.parse({'fewResultsMax': '5'}).fewResultsMax,
        2,
      );
      expect(
        VideoModalTriggerOptions.parse({
          'fewResultsMax': 20,
          'tripViewedTimes': 10,
        }),
        const VideoModalTriggerOptions(fewResultsMax: 20, tripViewedTimes: 10),
      );
    });
  });

  group('lecture des campagnes', () {
    test('un back ancien (aucun champ de moment) : valeurs par défaut', () {
      final c = VideoModalCampaign.tryParse(campaignJson())!;
      expect(c.triggerOptions, const VideoModalTriggerOptions());
      expect(c.corridors, isEmpty);
    });

    test('déclencheurs de moment, options et corridors', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: [
            'SEARCH_FEW_RESULTS',
            'PAYMENT_FAILED',
            'APP_UPDATED',
            'TRIP_VIEWED_REPEATEDLY',
          ],
          extra: {
            'triggerOptions': {'fewResultsMax': 4, 'tripViewedTimes': 5},
            'corridors': [
              {'from': 'Paris', 'to': 'Abidjan'},
              {'to': 'Dakar'},
            ],
          },
        ),
      )!;
      expect(c.triggers, {
        VideoModalTrigger.searchFewResults,
        VideoModalTrigger.paymentFailed,
        VideoModalTrigger.appUpdated,
        VideoModalTrigger.tripViewedRepeatedly,
      });
      expect(c.triggerOptions.fewResultsMax, 4);
      expect(c.triggerOptions.tripViewedTimes, 5);
      expect(c.corridors, [
        const VideoModalCorridor(from: 'Paris', to: 'Abidjan'),
        const VideoModalCorridor(to: 'Dakar'),
      ]);
    });

    test('un déclencheur inconnu est retiré, les autres restent', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(triggers: ['FUTURE_MOMENT', 'KYC_VERIFIED']),
      )!;
      expect(c.triggers, {VideoModalTrigger.kycVerified});
    });

    test('plus aucun déclencheur connu : campagne ignorée', () {
      expect(
        VideoModalCampaign.tryParse(campaignJson(triggers: ['FUTURE_MOMENT'])),
        isNull,
      );
      expect(
        VideoModalCampaign.parseList([
          campaignJson(triggers: ['FUTURE_MOMENT']),
          campaignJson(id: 'ok', triggers: ['APP_UPDATED']),
        ]).map((c) => c.id),
        ['ok'],
      );
    });

    test('corridors : au plus 10, entrées illisibles ignorées', () {
      final c = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: ['FORM_ABANDONED'],
          extra: {
            'corridors': [
              for (var i = 0; i < 12; i++) {'from': 'V$i'},
              'illisible',
            ],
          },
        ),
      )!;
      expect(c.corridors, hasLength(10));
    });

    test(
      'corridors tous illisibles : campagne ignorée (pas ouverte à tous)',
      () {
        expect(
          VideoModalCampaign.tryParse(
            campaignJson(
              triggers: ['FORM_ABANDONED'],
              extra: {
                'corridors': ['x', 3],
              },
            ),
          ),
          isNull,
        );
      },
    );

    test('corridors vide ou absent ou pas une liste : tous', () {
      for (final value in [const <Object?>[], null, 'x']) {
        final c = VideoModalCampaign.tryParse(
          campaignJson(extra: {'corridors': value}),
        )!;
        expect(c.corridors, isEmpty);
      }
    });
  });

  group('déclencheurs', () {
    test('isMoment : seuls les déclencheurs d\'écran ne le sont pas', () {
      const screen = {
        VideoModalTrigger.appOpen,
        VideoModalTrigger.searchTab,
        VideoModalTrigger.activitiesTab,
        VideoModalTrigger.trackingTab,
        VideoModalTrigger.messagesTab,
        VideoModalTrigger.profileTab,
        VideoModalTrigger.publishTrip,
        VideoModalTrigger.sendParcel,
      };
      for (final t in VideoModalTrigger.values) {
        expect(t.isMoment, !screen.contains(t), reason: t.wire);
      }
    });

    test(
      'usesCorridors : recherche, favori, consultation, formulaire, publication',
      () {
        const withCorridor = {
          VideoModalTrigger.searchNoTripResults,
          VideoModalTrigger.searchNoParcelResults,
          VideoModalTrigger.searchFewResults,
          VideoModalTrigger.favoriteAdded,
          VideoModalTrigger.tripViewedRepeatedly,
          VideoModalTrigger.formAbandoned,
          VideoModalTrigger.tripPublished,
          VideoModalTrigger.requestPublished,
        };
        for (final t in VideoModalTrigger.values) {
          expect(t.usesCorridors, withCorridor.contains(t), reason: t.wire);
        }
      },
    );

    test('valeurs échangées avec le back', () {
      expect(VideoModalTrigger.fromWire('DELIVERY_CONFIRMED'), isNotNull);
      expect(
        VideoModalTrigger.fromWire('SEARCH_NO_PARCEL_RESULTS'),
        VideoModalTrigger.searchNoParcelResults,
      );
      expect(VideoModalTrigger.fromWire('NOPE'), isNull);
    });
  });

  group('VideoModalMoment.search', () {
    test('0 résultat : sans résultat (trajet ou colis), jamais « peu »', () {
      expect(
        VideoModalMoment.search(
          kind: VideoModalSearchKind.trip,
          resultCount: 0,
        ).trigger,
        VideoModalTrigger.searchNoTripResults,
      );
      expect(
        VideoModalMoment.search(
          kind: VideoModalSearchKind.parcel,
          resultCount: 0,
        ).trigger,
        VideoModalTrigger.searchNoParcelResults,
      );
    });

    test(
      'au moins un résultat : peu de résultats, jamais « sans résultat »',
      () {
        for (final kind in VideoModalSearchKind.values) {
          final m = VideoModalMoment.search(kind: kind, resultCount: 1);
          expect(m.trigger, VideoModalTrigger.searchFewResults);
        }
      },
    );

    test('un compte négatif vaut zéro', () {
      expect(
        VideoModalMoment.search(
          kind: VideoModalSearchKind.trip,
          resultCount: -3,
        ).trigger,
        VideoModalTrigger.searchNoTripResults,
      );
    });

    test('seuil de peu de résultats : de 1 au seuil de la campagne inclus', () {
      final c = campaign(triggers: {VideoModalTrigger.searchFewResults});
      VideoModalMoment few(int n) => VideoModalMoment.search(
        kind: VideoModalSearchKind.trip,
        resultCount: n,
      );
      // Seuil par défaut : 2.
      expect(few(1).accepts(c), isTrue);
      expect(few(2).accepts(c), isTrue);
      expect(few(3).accepts(c), isFalse);
      final wide = VideoModalCampaign.tryParse(
        campaignJson(
          triggers: ['SEARCH_FEW_RESULTS'],
          extra: {
            'triggerOptions': {'fewResultsMax': 5},
          },
        ),
      )!;
      expect(few(5).accepts(wide), isTrue);
      expect(few(6).accepts(wide), isFalse);
    });

    test('une recherche sans résultat n\'ouvre pas une campagne « peu »', () {
      final few = campaign(triggers: {VideoModalTrigger.searchFewResults});
      final none = VideoModalMoment.search(
        kind: VideoModalSearchKind.trip,
        resultCount: 0,
      );
      expect(none.accepts(few), isFalse);
      final noTrip = campaign(
        triggers: {VideoModalTrigger.searchNoTripResults},
      );
      expect(none.accepts(noTrip), isTrue);
      // Colis ≠ trajet.
      expect(
        VideoModalMoment.search(
          kind: VideoModalSearchKind.parcel,
          resultCount: 0,
        ).accepts(noTrip),
        isFalse,
      );
    });
  });

  group('VideoModalMoment.tripViewed', () {
    test('s\'ouvre à partir du nombre de consultations de la campagne', () {
      final c = campaign(triggers: {VideoModalTrigger.tripViewedRepeatedly});
      VideoModalMoment views(int n) =>
          VideoModalMoment.tripViewed(tripId: 't1', viewCount: n);
      expect(views(2).accepts(c), isFalse);
      expect(views(3).accepts(c), isTrue);
      expect(views(7).accepts(c), isTrue);
      expect(views(3).trigger, VideoModalTrigger.tripViewedRepeatedly);
      expect(views(3).tripId, 't1');
    });
  });

  group('corridors d\'une campagne', () {
    VideoModalCampaign withCorridors(
      VideoModalTrigger trigger,
      List<Map<String, Object?>> corridors,
    ) => VideoModalCampaign.tryParse(
      campaignJson(triggers: [trigger.wire], extra: {'corridors': corridors}),
    )!;

    test('liste vide : tous les corridors, même sans corridor connu', () {
      final c = campaign(triggers: {VideoModalTrigger.formAbandoned});
      expect(
        VideoModalMoment.action(VideoModalTrigger.formAbandoned).accepts(c),
        isTrue,
      );
    });

    test('le corridor du moment doit correspondre à une entrée', () {
      final c = withCorridors(VideoModalTrigger.favoriteAdded, [
        {'from': 'Lyon'},
        {'from': 'paris', 'to': "COTE D'IVOIRE"},
      ]);
      expect(
        VideoModalMoment.action(
          VideoModalTrigger.favoriteAdded,
          corridor: _parisAbidjan(),
        ).accepts(c),
        isTrue,
      );
      expect(
        VideoModalMoment.action(
          VideoModalTrigger.favoriteAdded,
          corridor: VideoModalMomentCorridor(
            fromCity: 'Marseille',
            toCity: 'Dakar',
          ),
        ).accepts(c),
        isFalse,
      );
      // Corridor inconnu : pas de correspondance précise possible.
      expect(
        VideoModalMoment.action(VideoModalTrigger.favoriteAdded).accepts(c),
        isFalse,
      );
    });

    test('sans effet pour les déclencheurs qui n\'en tiennent pas compte', () {
      final c = withCorridors(VideoModalTrigger.paymentSucceeded, [
        {'from': 'Lyon'},
      ]);
      expect(
        VideoModalMoment.action(
          VideoModalTrigger.paymentSucceeded,
          corridor: _parisAbidjan(),
        ).accepts(c),
        isTrue,
      );
      expect(
        VideoModalMoment.action(VideoModalTrigger.paymentSucceeded).accepts(c),
        isTrue,
      );
    });

    test(
      'un moment ne convient qu\'à une campagne qui liste son déclencheur',
      () {
        final c = campaign(triggers: {VideoModalTrigger.searchTab});
        expect(
          VideoModalMoment.action(VideoModalTrigger.kycVerified).accepts(c),
          isFalse,
        );
      },
    );

    test('publication de trajet ou de demande : corridors appliqués', () {
      for (final t in [
        VideoModalTrigger.tripPublished,
        VideoModalTrigger.requestPublished,
      ]) {
        final c = withCorridors(t, [
          {'to': 'Abidjan'},
        ]);
        expect(
          VideoModalMoment.action(t, corridor: _parisAbidjan()).accepts(c),
          isTrue,
        );
        expect(
          VideoModalMoment.action(
            t,
            corridor: VideoModalMomentCorridor(toCity: 'Dakar'),
          ).accepts(c),
          isFalse,
        );
      }
    });
  });

  group('VideoModalState.candidateForMoment', () {
    VideoModalState ready(
      List<VideoModalCampaign> campaigns, {
      Set<VideoModalSlot> used = const {},
    }) => VideoModalState(
      status: VideoModalStatus.ready,
      campaigns: campaigns,
      usedSlots: used,
    );

    final moment = VideoModalMoment.action(VideoModalTrigger.kycVerified);
    const search = {VideoModalTrigger.searchTab};
    final kyc = {VideoModalTrigger.kycVerified};

    /// Première campagne qui convient, dans l'ordre du back.
    test('première campagne qui convient, dans l\'ordre du back', () {
      final state = ready([
        campaign(id: 'a', triggers: {VideoModalTrigger.searchTab}),
        campaign(id: 'b', triggers: kyc),
        campaign(id: 'c', triggers: kyc),
      ]);
      expect(state.candidateForMoment(moment)?.id, 'b');
    });

    /// Rien avant le chargement, rien dans une case déjà prise.
    test('rien avant le chargement ni dans une case prise', () {
      final c = campaign(triggers: kyc);
      expect(
        VideoModalState(campaigns: [c]).candidateForMoment(moment),
        isNull,
      );
      expect(
        ready(
          [c],
          used: {VideoModalSlot.videoMoment},
        ).candidateForMoment(moment),
        isNull,
      );
      expect(ready(const []).candidateForMoment(moment), isNull);
    });

    /// Un modal d'écran (vidéo ou info) ne bloque jamais un moment.
    test('les cases « où » ne bloquent pas les moments', () {
      final v = campaign(triggers: kyc);
      final i = infoCampaign(triggers: kyc);
      final used = {VideoModalSlot.videoAmbient, VideoModalSlot.infoAmbient};
      expect(ready([v], used: used).candidateForMoment(moment)?.id, 'c1');
      expect(ready([i], used: used).candidateForMoment(moment)?.id, 'i1');
    });

    /// Un moment ne bloque pas les écrans.
    test('les cases « moment » ne bloquent pas les écrans', () {
      final c = campaign();
      final used = {VideoModalSlot.videoMoment, VideoModalSlot.infoMoment};
      expect(ready([c], used: used).candidateFor(search)?.id, 'c1');
      expect(
        ready([c], used: {VideoModalSlot.videoAmbient}).candidateFor(search),
        isNull,
      );
    });

    /// Vidéo et information sont deux cases distinctes, même nature.
    test('vidéo et information ne se bloquent pas', () {
      final v = campaign(id: 'v', triggers: kyc);
      final i = infoCampaign(id: 'i', triggers: kyc);
      final state = ready([v, i], used: {VideoModalSlot.videoMoment});
      expect(state.candidateForMoment(moment)?.id, 'i');
      expect(
        ready(
          [v, i],
          used: {VideoModalSlot.infoMoment},
        ).candidateForMoment(moment)?.id,
        'v',
      );
    });

    /// « À chaque fois » n'est bloquée par aucune case.
    test('« à chaque fois » n\'est bloquée par aucune case', () {
      final m = campaign(
        id: 'm',
        triggers: kyc,
        frequency: VideoModalFrequency.everyTime,
      );
      final s = campaign(id: 's', frequency: VideoModalFrequency.everyTime);
      final both = ready([m, s], used: VideoModalSlot.values.toSet());
      expect(both.candidateForMoment(moment)?.id, 'm');
      expect(both.candidateFor(search)?.id, 's');
    });

    /// Un moment bloqué laisse passer le « à chaque fois » derrière.
    test('un moment bloqué laisse passer le « à chaque fois » derrière', () {
      final once = campaign(id: 'o', triggers: kyc);
      final every = campaign(
        id: 'e',
        triggers: kyc,
        frequency: VideoModalFrequency.everyTime,
      );
      expect(
        ready(
          [once, every],
          used: {VideoModalSlot.videoMoment},
        ).candidateForMoment(moment)?.id,
        'e',
      );
    });

    /// `hasShown` : case prise, ou « à chaque fois ».
    test('hasShown suit la case de la campagne', () {
      final c = campaign();
      expect(ready([c]).hasShown(c, moment: true), isFalse);
      expect(
        ready(
          [c],
          used: {VideoModalSlot.videoMoment},
        ).hasShown(c, moment: true),
        isTrue,
      );
      final e = campaign(frequency: VideoModalFrequency.everyTime);
      expect(ready([e]).hasShown(e, moment: false), isTrue);
    });

    test('les déclencheurs d\'écran ne voient pas les moments', () {
      final c = campaign(triggers: kyc);
      expect(ready([c]).candidateFor(search), isNull);
    });
  });
}
