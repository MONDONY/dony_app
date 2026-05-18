import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_disabled_banner.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_rejected_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStripeAccountBloc
    extends MockBloc<StripeAccountEvent, StripeAccountState>
    implements StripeAccountBloc {}

void main() {
  late MockStripeAccountBloc mockBloc;

  setUp(() {
    mockBloc = MockStripeAccountBloc();
  });

  Widget buildWidget(Widget child) => MaterialApp(
        home: BlocProvider<StripeAccountBloc>.value(
          value: mockBloc,
          child: Scaffold(body: child),
        ),
      );

  group('AccountDisabledBanner', () {
    testWidgets('renders warning icon and message', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountDisabledBanner()));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('temporairement désactivé'), findsOneWidget);
    });

    testWidgets('shows "En savoir plus" button', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountDisabledBanner()));
      expect(find.text('En savoir plus'), findsOneWidget);
    });
  });

  group('AccountRejectedBanner', () {
    testWidgets('renders error icon and message', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.textContaining('rejeté'), findsOneWidget);
    });

    testWidgets('shows "Reconfigurer" button', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(find.text('Reconfigurer'), findsOneWidget);
    });
  });
}
