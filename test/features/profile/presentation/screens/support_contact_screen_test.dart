import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/profile/bloc/support_contact_bloc.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/features/profile/presentation/screens/support_contact_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockSupportContactBloc
    extends MockBloc<SupportContactEvent, SupportContactState>
    implements SupportContactBloc {}

Widget _wrap(SupportContactBloc bloc) => BlocProvider<SupportContactBloc>.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const SupportContactScreen(),
            ),
          ],
        ),
      ),
    );

void main() {
  late MockSupportContactBloc bloc;

  setUpAll(() {
    registerFallbackValue(const SupportCategorySelected(''));
    registerFallbackValue(const SupportSubjectChanged(''));
    registerFallbackValue(const SupportMessageChanged(''));
    registerFallbackValue(const SupportSubmitRequested());
  });

  setUp(() {
    bloc = MockSupportContactBloc();
    when(() => bloc.state).thenReturn(const SupportContactState());
  });

  testWidgets('renders the form elements', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Contacter le support'), findsOneWidget);
    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Sujet'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Envoyer un message'), findsOneWidget);
  });

  testWidgets('submit button is disabled when state is invalid', (tester) async {
    when(() => bloc.state).thenReturn(const SupportContactState());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final submitBtn = tester.widget<InkWell>(
      find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
    );
    expect(submitBtn.onTap, isNull);
  });

  testWidgets('submit button is enabled when state is valid', (tester) async {
    when(() => bloc.state).thenReturn(const SupportContactState(
      category: 'Paiement',
      subject: 'Problème remboursement',
      message: 'Je n\'ai pas reçu mon remboursement depuis 5 jours.',
    ));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final submitBtn = tester.widget<InkWell>(
      find.descendant(of: find.byType(DonyButton), matching: find.byType(InkWell)),
    );
    expect(submitBtn.onTap, isNotNull);
  });

  testWidgets('info card is rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.textContaining('Notre équipe répond sous 24'),
      findsOneWidget,
    );
  });

  testWidgets('shows char count hint when message is short but not empty', (tester) async {
    when(() => bloc.state).thenReturn(const SupportContactState(
      message: 'Court',
    ));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Au moins 20 caractères'), findsOneWidget);
  });

  testWidgets('does not show char count hint when message is empty', (tester) async {
    when(() => bloc.state).thenReturn(const SupportContactState());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Au moins 20 caractères'), findsNothing);
  });

  testWidgets('dispatches SupportCategorySelected when dropdown changes', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Choisir une catégorie'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Paiement').last);
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => bloc.add(any(that: isA<SupportCategorySelected>()))).called(1);
  });

  testWidgets('submit button shows loading when isSubmitting', (tester) async {
    when(() => bloc.state).thenReturn(const SupportContactState(
      category: 'Paiement',
      subject: 'Problème remboursement',
      message: 'Je n\'ai pas reçu mon remboursement depuis 5 jours.',
      submitStatus: SupportSubmitStatus.submitting,
    ));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('typing in subject field dispatches SupportSubjectChanged', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byType(TextFormField).first,
      'Mon problème de paiement',
    );

    verify(() => bloc.add(any(that: isA<SupportSubjectChanged>()))).called(greaterThan(0));
  });

  testWidgets('typing in message field dispatches SupportMessageChanged', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byType(TextFormField).last,
      'Description du problème rencontré sur l\'application.',
    );

    verify(() => bloc.add(any(that: isA<SupportMessageChanged>()))).called(greaterThan(0));
  });

  testWidgets('category dropdown renders all options when opened', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Choisir une catégorie'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // All dropdown items should be in the tree when opened
    for (final cat in ['Paiement', 'KYC / vérification', 'Livraison', 'Litige', 'Bug technique', 'Autre']) {
      expect(find.text(cat), findsWidgets);
    }
  });
}
