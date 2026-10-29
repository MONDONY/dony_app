import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/confirm_delete_bid.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

final _l = lookupAppLocalizations(AppL10n.fr);

BidModel _bid() => BidModel(
  id: 'bid-del-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'CANCELLED',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late _MockBidBloc bloc;

  setUpAll(() => registerFallbackValue(BidDeleteRequested('x')));

  setUp(() {
    bloc = _MockBidBloc();
    whenListen<BidState>(
      bloc,
      const Stream.empty(),
      initialState: BidInitial(),
    );
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<BidBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => confirmDeleteBid(context, _bid()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('affiche la question et son corps', (tester) async {
    await open(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_l.bidDetailDeleteRequestQuestionTitle), findsOneWidget);
    expect(find.text(_l.bidDetailDeleteRequestDefaultBody), findsOneWidget);
  });

  testWidgets('confirmer émet BidDeleteRequested une seule fois', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text(_l.commonDelete));
    await tester.pumpAndSettle();

    final event =
        verify(
              () => bloc.add(captureAny(that: isA<BidDeleteRequested>())),
            ).captured.single
            as BidDeleteRequested;
    expect(event.bidId, 'bid-del-1');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Annuler ferme la boîte sans événement', (tester) async {
    await open(tester);

    await tester.tap(find.text(_l.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any()));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
