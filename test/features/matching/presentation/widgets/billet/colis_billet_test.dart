import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidModel _bid() => BidModel(
  id: 'bid-1',
  announcementId: 'a-1',
  senderId: 's-1',
  weightKg: 5,
  status: 'ACCEPTED',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  trackingNumber: 'DON-3TSTR9VH',
  departureCity: 'Paris',
  arrivalCity: 'Abidjan',
);

void main() {
  testWidgets('le billet montre le tampon de statut et le talon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        // isSender: false → talon voyageur (TalonTravelerActionView), sans bloc.
        // isSender: true + ACCEPTED rendrait QrCodeCard, qui exige un
        // TrackingBloc ambiant — hors périmètre d'un widget test isolé.
        home: Scaffold(body: ColisBillet(bid: _bid(), isSender: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BilletStatusStamp), findsOneWidget);
    expect(find.byType(BilletTalon), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.textContaining('Paris'), findsWidgets);
  });
}
