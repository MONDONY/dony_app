import 'package:dony/features/matching/data/models/bid_photo.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_photo_viewer_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('shows counter for the initial photo', (tester) async {
    const photos = [
      BidPhoto(id: '1', url: 'https://x/1.jpg'),
      BidPhoto(id: '2', url: 'https://x/2.jpg'),
      BidPhoto(id: '3', url: 'https://x/3.jpg'),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BidPhotoViewerModal(photos: photos, initialIndex: 1),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Photo 2 / 3'), findsOneWidget);
  });

  // I7 (review-finalD) : le bouton de fermeture était en dur « Fermer »,
  // jamais traduit en anglais (VoiceOver/TalkBack).
  testWidgets('en anglais : le bouton de fermeture est traduit ("Close")', (
    tester,
  ) async {
    useEnglish();
    const photos = [BidPhoto(id: '1', url: 'https://x/1.jpg')];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BidPhotoViewerModal(photos: photos)),
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.bySemanticsLabel('Fermer'), findsNothing);
  });
}
