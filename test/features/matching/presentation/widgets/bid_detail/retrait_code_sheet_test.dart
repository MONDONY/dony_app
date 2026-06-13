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
    theme: AppTheme.light,
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
}
