import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/presentation/screens/recipients_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class FakeRecipientEvent extends Fake implements RecipientEvent {}

const _r1 = Recipient(
  id: 'r-1',
  fullName: 'Mamadou Diallo',
  phoneE164: '+221771234567',
  city: 'Dakar',
  country: 'SN',
);

const _r2 = Recipient(
  id: 'r-2',
  fullName: 'Aminata Koné',
  phoneE164: '+22507891234',
  city: 'Abidjan',
  country: 'CI',
);

Widget _wrap(RecipientBloc bloc) => BlocProvider<RecipientBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const RecipientsScreen(),
            ),
            GoRoute(
              path: '/profile/recipients/new',
              builder: (_, __) => const Scaffold(body: Text('New Recipient')),
            ),
            GoRoute(
              path: '/profile/recipients/:id',
              builder: (_, __) =>
                  const Scaffold(body: Text('Edit Recipient')),
            ),
          ],
        ),
      ),
    );

void main() {
  late MockRecipientBloc bloc;

  setUpAll(() => registerFallbackValue(FakeRecipientEvent()));

  setUp(() {
    bloc = MockRecipientBloc();
    when(() => bloc.state).thenReturn(const RecipientState());
  });

  testWidgets('shows loading state', (tester) async {
    when(() => bloc.state).thenReturn(
      const RecipientState(status: RecipientStatus.loading),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RecipientsScreen), findsOneWidget);
  });

  testWidgets('shows empty state when no recipients', (tester) async {
    when(() => bloc.state).thenReturn(
      const RecipientState(status: RecipientStatus.success),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Aucun destinataire'), findsOneWidget);
  });

  testWidgets('shows list of recipients', (tester) async {
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.success,
        recipients: [_r1, _r2],
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Mamadou Diallo'), findsOneWidget);
    expect(find.text('Aminata Koné'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('retry button dispatches RecipientLoaded', (tester) async {
    when(() => bloc.state).thenReturn(
      const RecipientState(
        status: RecipientStatus.error,
        error: 'Erreur réseau',
      ),
    );
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(any(that: isA<RecipientLoaded>()))).called(1);
  });
}
