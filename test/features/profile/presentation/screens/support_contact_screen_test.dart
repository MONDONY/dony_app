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
        GoRoute(path: '/', builder: (_, __) => const SupportContactScreen()),
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
    registerFallbackValue(const SupportEmailComposerOpened());
    registerFallbackValue(
      const SupportEmailComposerFailed(reason: 'test_failure'),
    );
  });

  setUp(() {
    bloc = MockSupportContactBloc();
    when(() => bloc.state).thenReturn(const SupportContactState());
  });

  test('buildSupportMailtoUri encode les espaces sans signe plus', () {
    final uri = buildSupportMailtoUri(
      const SupportContactState(
        category: 'Annulation et remboursement',
        subject: 'Colis non livré',
        message: 'Je souhaite connaître les étapes à suivre.',
      ),
    );

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@yadony.com');
    expect(uri.toString(), isNot(contains('+')));
    expect(uri.toString(), contains('%20'));
    expect(
      uri.queryParameters['subject'],
      '[Annulation et remboursement] Colis non livré',
    );
    expect(uri.queryParameters['body'], contains('Envoyé depuis Yadony'));
  });

  testWidgets('renders the form elements', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Contacter le support'), findsOneWidget);
    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Sujet'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Continuer dans l\'app Mail'), findsOneWidget);
  });

  testWidgets('submit button is disabled when state is invalid', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const SupportContactState());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final submitBtn = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(DonyButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(submitBtn.onTap, isNull);
  });

  testWidgets('submit button is enabled when state is valid', (tester) async {
    when(() => bloc.state).thenReturn(
      const SupportContactState(
        category: 'Paiement',
        subject: 'Problème remboursement',
        message: 'Je n\'ai pas reçu mon remboursement depuis 5 jours.',
      ),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final submitBtn = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(DonyButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(submitBtn.onTap, isNotNull);
  });

  testWidgets('info card is rendered', (tester) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Notre équipe répond sous 24'), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'support@yadony.com'),
      findsOneWidget,
    );
  });

  testWidgets('success keeps the form visible after opening the email draft', (
    tester,
  ) async {
    const validState = SupportContactState(
      category: 'Paiement',
      subject: 'Problème remboursement',
      message: 'Je n\'ai pas reçu mon remboursement depuis plusieurs jours.',
    );
    whenListen(
      bloc,
      Stream<SupportContactState>.fromIterable([
        validState.copyWith(submitStatus: SupportSubmitStatus.success),
      ]),
      initialState: validState,
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Contacter le support'), findsOneWidget);
    expect(find.text('Continuer dans l\'app Mail'), findsOneWidget);
  });

  testWidgets('shows char count hint when message is short but not empty', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(const SupportContactState(message: 'Court'));

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Au moins 20 caractères'), findsOneWidget);
  });

  testWidgets('does not show char count hint when message is empty', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(const SupportContactState());

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Au moins 20 caractères'), findsNothing);
  });

  testWidgets('dispatches SupportCategorySelected when dropdown changes', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    final dropdown = find.byType(DropdownButton<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Paiement').last);
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => bloc.add(any(that: isA<SupportCategorySelected>()))).called(1);
  });

  testWidgets('submit button shows loading when isSubmitting', (tester) async {
    when(() => bloc.state).thenReturn(
      const SupportContactState(
        category: 'Paiement',
        subject: 'Problème remboursement',
        message: 'Je n\'ai pas reçu mon remboursement depuis 5 jours.',
        submitStatus: SupportSubmitStatus.submitting,
      ),
    );

    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('typing in subject field dispatches SupportSubjectChanged', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byType(TextFormField).first,
      'Mon problème de paiement',
    );

    verify(
      () => bloc.add(any(that: isA<SupportSubjectChanged>())),
    ).called(greaterThan(0));
  });

  testWidgets('typing in message field dispatches SupportMessageChanged', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(
      find.byType(TextFormField).last,
      'Description du problème rencontré sur l\'application.',
    );

    verify(
      () => bloc.add(any(that: isA<SupportMessageChanged>())),
    ).called(greaterThan(0));
  });

  testWidgets('category dropdown renders all options when opened', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Choisir une catégorie'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // All dropdown items should be in the tree when opened
    for (final cat in [
      'Paiement',
      'Annulation et remboursement',
      'Vérification d\'identité',
      'Compte et sécurité',
      'Livraison',
      'Litige',
      'Signalement ou fraude',
      'Bug technique',
      'Autre',
    ]) {
      expect(find.text(cat), findsWidgets);
    }
  });
}
