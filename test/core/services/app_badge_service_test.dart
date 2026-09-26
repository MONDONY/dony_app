import 'package:dony/core/services/app_badge_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// La pastille de l'icône restait à 1 pour toujours : le backend posait `1` en dur sur
/// chaque push, le champ APNs `badge` est absolu, et rien côté application ne le remettait
/// jamais à zéro. Ce service est le seul endroit qui écrit désormais cette valeur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AppBadgeService.channelName);
  late List<int> ecrits;

  void brancherCanal({bool disponible = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          disponible
              ? (call) async {
                  if (call.method == 'setBadge') {
                    ecrits.add((call.arguments as Map)['count'] as int);
                  }
                  return null;
                }
              : null,
        );
  }

  setUp(() {
    ecrits = <int>[];
    brancherCanal();
  });

  tearDown(() => brancherCanal(disponible: false));

  test('la pastille porte la somme des trois sources de non-lus', () async {
    final badge = AppBadgeService();

    await badge.setNotifications(2);
    await badge.setMessages(3);
    await badge.setSupport(1);

    expect(badge.total, 6);
    expect(ecrits, [2, 5, 6]);
  });

  test('le même total n\'est pas réécrit sur l\'icône', () async {
    final badge = AppBadgeService();

    await badge.setNotifications(2);
    // Même valeur : rien ne traverse la frontière native.
    await badge.setNotifications(2);
    await badge.setMessages(1);
    // Une source baisse, le total aussi : l'icône doit suivre.
    await badge.setNotifications(1);

    expect(ecrits, [2, 3, 2]);
    expect(badge.total, 2);
  });

  test('clear remet la pastille à zéro, ce que personne ne faisait', () async {
    final badge = AppBadgeService();
    await badge.setNotifications(4);
    await badge.setMessages(2);

    await badge.clear();

    expect(badge.total, isZero);
    expect(ecrits.last, 0);
  });

  test('un compteur négatif est ramené à zéro, jamais envoyé tel quel', () async {
    final badge = AppBadgeService();

    await badge.setNotifications(-3);

    expect(badge.total, isZero);
    // Zéro est bien écrit, et c'est voulu : au premier calcul après le
    // démarrage, c'est ce qui efface une pastille laissée par une ancienne push.
    expect(ecrits, [0]);
  });

  test('plateforme sans pastille : aucune exception ne remonte', () async {
    // Android laisse la pastille au lanceur, le canal n'y est pas implémenté.
    brancherCanal(disponible: false);
    final badge = AppBadgeService();

    await expectLater(badge.setNotifications(5), completes);
    expect(badge.total, 5);
  });

  test('une pastille refusée par la plateforme ne casse rien', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'denied'),
        );
    final badge = AppBadgeService();

    await expectLater(badge.setMessages(2), completes);
  });
}
