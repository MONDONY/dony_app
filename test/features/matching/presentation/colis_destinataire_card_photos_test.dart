import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BidModel bidWith(List<BidPhoto> photos) => BidModel(
    id: 'b1',
    announcementId: 'a1',
    senderId: 's1',
    status: 'PENDING',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    photos: photos,
  );

  testWidgets('renders gallery when photos present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColisDestinataireCard(
              bid: bidWith(const [BidPhoto(id: '1', url: 'https://x/1.jpg')]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
    // La galerie est réellement rendue (1 thumbnail = 1 CachedNetworkImage).
    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('no gallery when no photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColisDestinataireCard(bid: bidWith(const [])),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ColisDestinataireCard), findsOneWidget);
    // Aucune galerie quand pas de photos.
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
