import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/request_sender_cubit.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/presentation/widgets/request_sender_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockRequestSenderCubit extends MockCubit<RequestSenderState>
    implements RequestSenderCubit {}

SenderPublicProfile _sender({bool gpPro = false}) => SenderPublicProfile(
  id: 'sender-1',
  displayName: 'Fatou Diallo',
  averageRating: 4.8,
  totalRatings: 12,
  kycVerified: true,
  gpPro: gpPro,
);

Future<void> _pump(WidgetTester tester, SenderPublicProfile sender) async {
  final cubit = _MockRequestSenderCubit();
  whenListen(
    cubit,
    const Stream<RequestSenderState>.empty(),
    initialState: RequestSenderLoaded(sender),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: BlocProvider<RequestSenderCubit>.value(
          value: cubit,
          child: const RequestSenderRow(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('expéditeur GP Pro → badge compact dans la ligne', (
    tester,
  ) async {
    await _pump(tester, _sender(gpPro: true));
    expect(find.byType(GpProBadge), findsOneWidget);
  });

  testWidgets('expéditeur ordinaire → pas de badge', (tester) async {
    await _pump(tester, _sender());
    expect(find.byType(GpProBadge), findsNothing);
  });
}
