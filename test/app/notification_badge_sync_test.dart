import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:dony/app/notification_badge_sync.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int fetches;
  late List<int> applied;
  late DateTime now;
  late Future<int> Function() fetch;

  NotificationBadgeSync build() => NotificationBadgeSync(
    fetchUnreadCount: () {
      fetches++;
      return fetch();
    },
    applyBadge: (unread) async => applied.add(unread),
    now: () => now,
  );

  setUp(() {
    fetches = 0;
    applied = [];
    now = DateTime(2026, 10, 10, 12);
    fetch = () async => 3;
  });

  test(
    'paused, inactive, hidden, detached : aucun appel (FLUTTER-JQ)',
    () async {
      final sync = build();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        await sync.onLifecycleChanged(state);
      }
      expect(fetches, 0);
      expect(applied, isEmpty);
    },
  );

  test('resumed : un appel, compteur reporté sur l\'icône', () async {
    final sync = build();
    await sync.onLifecycleChanged(AppLifecycleState.resumed);
    expect(fetches, 1);
    expect(applied, [3]);
  });

  test(
    'une seule lecture à la fois : les appels concurrents la rejoignent',
    () async {
      final pending = Completer<int>();
      fetch = () => pending.future;
      final sync = build();

      final first = sync.onLifecycleChanged(AppLifecycleState.resumed);
      final second = sync.onLifecycleChanged(AppLifecycleState.resumed);
      expect(fetches, 1);

      pending.complete(5);
      await Future.wait([first, second]);
      expect(applied, [5]);
    },
  );

  test('anti-rebond : pas de relecture avant minInterval', () async {
    final sync = build();
    await sync.sync();
    now = now.add(const Duration(seconds: 2));
    await sync.sync();
    expect(fetches, 1);

    now = now.add(const Duration(seconds: 5));
    await sync.sync();
    expect(fetches, 2);
  });

  test('échec réseau : silencieux, ancien compteur conservé', () async {
    final sync = build();
    await sync.sync();
    expect(applied, [3]);

    fetch = () async => throw DioException(
      requestOptions: RequestOptions(path: '/notifications/unread-count'),
      error: const SocketException('Software caused connection abort'),
    );
    now = now.add(const Duration(minutes: 1));
    await expectLater(sync.sync(), completes);
    expect(fetches, 2);
    expect(applied, [3]);

    // La lecture suivante repart normalement.
    fetch = () async => 1;
    now = now.add(const Duration(minutes: 1));
    await sync.sync();
    expect(applied, [3, 1]);
  });

  test('horloge par défaut utilisable', () async {
    final sync = NotificationBadgeSync(
      fetchUnreadCount: () async => 0,
      applyBadge: (_) async {},
    );
    await expectLater(sync.sync(), completes);
  });
}
