import 'dart:async';

import 'package:dony/features/connectivity/bloc/connectivity_cubit.dart';
import 'package:dony/features/connectivity/bloc/connectivity_state.dart';
import 'package:dony/features/connectivity/data/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivityRepository extends Mock
    implements ConnectivityRepository {}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _MockConnectivityRepository repo;
  late StreamController<bool> connectivityController;

  setUp(() {
    repo = _MockConnectivityRepository();
    connectivityController = StreamController<bool>.broadcast();
    when(
      () => repo.onHasConnectionChanged,
    ).thenAnswer((_) => connectivityController.stream);
  });

  tearDown(() => connectivityController.close());

  group('état initial', () {
    test('reste online quand le device a une connexion au démarrage', () async {
      when(() => repo.hasConnection()).thenAnswer((_) async => true);
      final cubit = ConnectivityCubit(repo);
      await _settle();

      expect(cubit.state, const ConnectivityState());

      await cubit.close();
    });

    test(
      'passe offline quand le device n\'a aucune connexion au démarrage',
      () async {
        when(() => repo.hasConnection()).thenAnswer((_) async => false);
        final cubit = ConnectivityCubit(repo);
        await _settle();

        expect(cubit.state.status, ConnectivityStatus.offline);

        await cubit.close();
      },
    );
  });

  group('checkNow()', () {
    test(
      'corrige un faux offline initial (device réellement connecté) — '
      'régression du bandeau bloqué en rouge malgré une vraie connexion',
      () async {
        // Simule la race de cold-start Android : le tout premier
        // hasConnection() ment (false), aucun event connectivity_plus ne suit
        // puisque la connexion n'a jamais réellement changé. Seule la sonde
        // périodique (qui rappelle checkNow, ici simulée manuellement) peut
        // s'auto-corriger en re-vérifiant hasConnection() à chaque itération.
        when(() => repo.hasConnection()).thenAnswer((_) async => false);
        final cubit = ConnectivityCubit(repo);
        await _settle();
        expect(cubit.state.status, ConnectivityStatus.offline);

        when(() => repo.hasConnection()).thenAnswer((_) async => true);
        when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
        await cubit.checkNow();

        expect(cubit.state.status, ConnectivityStatus.online);
        expect(cubit.state.justReconnected, isTrue);

        await cubit.close();
      },
    );

    test('passe weak quand l\'API ne répond pas', () async {
      when(() => repo.hasConnection()).thenAnswer((_) async => true);
      when(() => repo.isApiResponsive()).thenAnswer((_) async => false);
      final cubit = ConnectivityCubit(repo);
      await _settle();

      await cubit.checkNow();

      expect(cubit.state.status, ConnectivityStatus.weak);
      expect(cubit.state.justReconnected, isFalse);

      await cubit.close();
    });

    test(
      'passe online + justReconnected quand l\'API redevient responsive après weak',
      () async {
        when(() => repo.hasConnection()).thenAnswer((_) async => true);
        when(() => repo.isApiResponsive()).thenAnswer((_) async => false);
        final cubit = ConnectivityCubit(repo);
        await _settle();
        await cubit.checkNow(); // → weak

        when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
        await cubit.checkNow();

        expect(cubit.state.status, ConnectivityStatus.online);
        expect(cubit.state.justReconnected, isTrue);

        await cubit.close();
      },
    );

    test('ne ré-émet pas si déjà online et l\'API répond toujours', () async {
      when(() => repo.hasConnection()).thenAnswer((_) async => true);
      when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
      final cubit = ConnectivityCubit(repo);
      await _settle();

      final states = <ConnectivityState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.checkNow();
      await cubit.checkNow();

      expect(states, isEmpty); // toujours online, jamais justReconnected

      await sub.cancel();
      await cubit.close();
    });
  });

  group('clearReconnectedFlag()', () {
    test('masque le flag sans changer le status', () async {
      when(() => repo.hasConnection()).thenAnswer((_) async => true);
      when(() => repo.isApiResponsive()).thenAnswer((_) async => false);
      final cubit = ConnectivityCubit(repo);
      await _settle();
      await cubit.checkNow(); // → weak

      when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
      await cubit.checkNow(); // → online + justReconnected

      cubit.clearReconnectedFlag();

      expect(cubit.state.status, ConnectivityStatus.online);
      expect(cubit.state.justReconnected, isFalse);

      await cubit.close();
    });
  });

  group('changements de connectivité device', () {
    test(
      'coupe la connexion → offline, quel que soit l\'état précédent',
      () async {
        when(() => repo.hasConnection()).thenAnswer((_) async => true);
        when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
        final cubit = ConnectivityCubit(repo);
        await _settle();

        connectivityController.add(false);
        await _settle();

        expect(cubit.state.status, ConnectivityStatus.offline);
        expect(cubit.state.justReconnected, isFalse);

        await cubit.close();
      },
    );

    test(
      'retour du réseau device + API responsive → online + justReconnected',
      () async {
        when(() => repo.hasConnection()).thenAnswer((_) async => false);
        when(() => repo.isApiResponsive()).thenAnswer((_) async => true);
        final cubit = ConnectivityCubit(repo);
        await _settle();
        expect(cubit.state.status, ConnectivityStatus.offline);

        // Le stream ET checkConnectivity() partagent la même source OS en
        // vrai — checkNow() revérifie désormais hasConnection() lui-même
        // (cf. régression cold-start), donc le mock doit refléter le même
        // état que l'event poussé sur le stream.
        when(() => repo.hasConnection()).thenAnswer((_) async => true);
        connectivityController.add(true);
        await _settle();

        expect(cubit.state.status, ConnectivityStatus.online);
        expect(cubit.state.justReconnected, isTrue);

        await cubit.close();
      },
    );

    test(
      'retour du réseau device mais API injoignable → weak, pas online',
      () async {
        when(() => repo.hasConnection()).thenAnswer((_) async => false);
        when(() => repo.isApiResponsive()).thenAnswer((_) async => false);
        final cubit = ConnectivityCubit(repo);
        await _settle();

        when(() => repo.hasConnection()).thenAnswer((_) async => true);
        connectivityController.add(true);
        await _settle();

        expect(cubit.state.status, ConnectivityStatus.weak);

        await cubit.close();
      },
    );
  });
}
