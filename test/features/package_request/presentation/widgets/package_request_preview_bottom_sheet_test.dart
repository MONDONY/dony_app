import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/package_request_preview_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PackageRequestSearchItem _item() => PackageRequestSearchItem(
  id: 'pr-42',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 6, 15),
  dateToleranceDays: 2,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  categories: const ['Vêtements'],
  targetPriceEur: 50,
  sender: const SenderPublicProfile(
    id: 's1',
    displayName: 'Fatou',
    averageRating: 4.5,
    totalRatings: 3,
    kycVerified: true,
  ),
);

void main() {
  testWidgets('show() pousse l\'écran plein /package-requests/:id/public', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (ctx, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    PackageRequestPreviewBottomSheet.show(ctx, item: _item()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/package-requests/:id/public',
          builder: (ctx, state) =>
              Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL pr-42'), findsOneWidget);
  });
}
