import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/retrait_code_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

BidModel _bid({String? confirmationCode = '4729'}) => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  status: 'IN_TRANSIT',
  weightKg: 5,
  confirmationCode: confirmationCode,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

void main() {
  late _MockTrackingBloc tracking;
  late _MockBidBloc bid;

  setUp(() {
    tracking = _MockTrackingBloc();
    bid = _MockBidBloc();
    when(() => tracking.state).thenReturn(TrackingInitial());
    when(() => bid.state).thenReturn(BidInitial());
  });

  Widget host(BidModel b) => MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => RetraitCodeSheet.show(
              context,
              bid: b,
              trackingBloc: tracking,
              bidBloc: bid,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('ouvre le sheet avec le code de retrait et ses actions', (
    tester,
  ) async {
    await tester.pumpWidget(host(_bid()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CODE DE RETRAIT'), findsOneWidget);
    for (final d in '4729'.split('')) {
      expect(find.text(d), findsWidgets);
    }
    expect(find.text('Copier le code'), findsOneWidget);
    expect(find.textContaining('Régénérer'), findsOneWidget);

    // Drain des timers d'animation.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  // FLUTTER-G1 : `bid.confirmationCode!` plantait quand le code venait d'être
  // effacé (trois essais faux). Sans code, rien ne s'ouvre et rien ne plante.
  testWidgets('sans code : aucune feuille, aucune exception', (tester) async {
    await tester.pumpWidget(host(_bid(confirmationCode: null)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CODE DE RETRAIT'), findsNothing);
  });

  testWidgets('anglais — titre du sheet "Pickup code" traduit', (tester) async {
    useEnglish();
    await tester.pumpWidget(host(_bid()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup code'), findsOneWidget);

    // Drain des timers d'animation.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });
}
