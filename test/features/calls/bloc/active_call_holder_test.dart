import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/calls/bloc/active_call_holder.dart';
import 'package:dony/features/calls/bloc/call_bloc.dart';
import 'package:dony/features/calls/data/call_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCallBloc extends MockBloc<CallEvent, CallState>
    implements CallBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const CallHangUpRequested()));

  late List<_MockCallBloc> created;
  late ActiveCallHolder holder;

  _MockCallBloc newBloc({bool live = true, bool closed = false}) {
    final bloc = _MockCallBloc();
    when(() => bloc.isLive).thenReturn(live);
    when(() => bloc.isClosed).thenReturn(closed);
    when(() => bloc.state).thenReturn(const CallStarting());
    when(bloc.close).thenAnswer((_) async {});
    return bloc;
  }

  setUp(() {
    created = [];
    holder = ActiveCallHolder(() {
      final bloc = newBloc();
      created.add(bloc);
      return bloc;
    });
  });

  const start = CallStartRequested('c1', 'Moussa');

  test('premier appel : crée le bloc et lui envoie l\'événement initial', () {
    final bloc = holder.blocFor(start, avatarUrl: 'https://a');

    expect(created, [bloc]);
    expect(holder.current.value, bloc);
    expect(holder.remoteAvatarUrl, 'https://a');
    verify(() => bloc.add(start)).called(1);
  });

  test('appel en cours : toujours repris, sans nouvel appel (retour depuis '
      'la barre ou second appel entrant)', () {
    final first = holder.blocFor(start);

    expect(holder.blocFor(null), same(first));
    expect(
      holder.blocFor(const CallIncomingAcceptRequested('x2', 'Awa')),
      same(first),
    );
    expect(created, hasLength(1));
    verifyNever(
      () => first.add(const CallIncomingAcceptRequested('x2', 'Awa')),
    );
  });

  test('appel terminé, nouvel appel : l\'ancien bloc est fermé', () {
    final first = holder.blocFor(start);
    when(() => first.isLive).thenReturn(false);

    final second = holder.blocFor(start);

    expect(second, isNot(same(first)));
    verify(first.close).called(1);
    expect(holder.current.value, second);
  });

  test('appel terminé, réouverture sans événement : même bloc (écran « Appel '
      'terminé »)', () {
    final first = holder.blocFor(start);
    when(() => first.isLive).thenReturn(false);

    expect(holder.blocFor(null), same(first));
    verifyNever(first.close);
  });

  test('showsBanner : appel vivant et écran masqué seulement', () {
    expect(holder.showsBanner, isFalse);
    final bloc = holder.blocFor(start);
    expect(holder.showsBanner, isTrue);
    holder.callScreenVisible.value = true;
    expect(holder.showsBanner, isFalse);
    holder.callScreenVisible.value = false;
    when(() => bloc.isLive).thenReturn(false);
    expect(holder.showsBanner, isFalse);
  });

  test('phase sonnerie : le bloc tenu garde son état (contrôle de type)', () {
    final bloc = holder.blocFor(start);
    when(() => bloc.state).thenReturn(
      const CallInProgress(phase: CallPhase.ringing, remoteName: 'Moussa'),
    );
    expect(holder.current.value!.state, isA<CallInProgress>());
  });
}
