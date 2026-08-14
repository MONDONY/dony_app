import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/stripe_account/presentation/widgets/account_rejected_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('AccountRejectedBanner', () {
    testWidgets('renders error icon and message', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(
        find.byWidgetPredicate(
          (w) => w is DonyIcon && w.name == 'circle-alert',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('rejeté'), findsOneWidget);
    });

    testWidgets('shows "Reconfigurer" button', (tester) async {
      await tester.pumpWidget(buildWidget(const AccountRejectedBanner()));
      expect(find.text('Reconfigurer'), findsOneWidget);
    });
  });
}
