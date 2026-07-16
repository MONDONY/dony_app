import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _presignedUrl =
    'https://s3.dony.store/bucket/tracking/abc/123_photo.jpg'
    '?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20260716T120000Z'
    '&X-Amz-Expires=900&X-Amz-Signature=deadbeef';
const _stableKey = 'https://s3.dony.store/bucket/tracking/abc/123_photo.jpg';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('DonyImage.stableCacheKey', () {
    test('strips presigned query params', () {
      expect(DonyImage.stableCacheKey(_presignedUrl), _stableKey);
    });

    test('returns url unchanged when no query', () {
      expect(DonyImage.stableCacheKey(_stableKey), _stableKey);
    });

    test('two presigned urls of same object share the same key', () {
      const other = '$_stableKey?X-Amz-Signature=cafebabe&X-Amz-Date=20260717T000000Z';
      expect(
        DonyImage.stableCacheKey(_presignedUrl),
        DonyImage.stableCacheKey(other),
      );
    });
  });

  group('DonyImage', () {
    testWidgets('renders CachedNetworkImage with stable cacheKey', (tester) async {
      await tester.pumpWidget(_wrap(const DonyImage(url: _presignedUrl)));
      final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(img.imageUrl, _presignedUrl);
      expect(img.cacheKey, _stableKey);
    });

    testWidgets('applies fit, width and height', (tester) async {
      await tester.pumpWidget(_wrap(const DonyImage(
        url: _presignedUrl,
        width: 44,
        height: 44,
        fit: BoxFit.contain,
      )));
      final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(img.width, 44);
      expect(img.height, 44);
      expect(img.fit, BoxFit.contain);
    });

    testWidgets('wraps in ClipRRect when borderRadius provided', (tester) async {
      await tester.pumpWidget(_wrap(DonyImage(
        url: _presignedUrl,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      )));
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('no ClipRRect without borderRadius', (tester) async {
      await tester.pumpWidget(_wrap(const DonyImage(url: _presignedUrl)));
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('uses soft fade-in shorter than 500ms', (tester) async {
      await tester.pumpWidget(_wrap(const DonyImage(url: _presignedUrl)));
      final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(img.fadeInDuration.inMilliseconds, lessThanOrEqualTo(500));
    });

    testWidgets('custom placeholder is used while loading', (tester) async {
      await tester.pumpWidget(_wrap(DonyImage(
        url: _presignedUrl,
        placeholder: (_) => const Text('chargement'),
      )));
      await tester.pump();
      expect(find.text('chargement'), findsOneWidget);
    });
  });

  group('DonyAvatar cache', () {
    testWidgets('uses CachedNetworkImage with stable cacheKey', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(
        name: 'Ibrahima Diallo',
        imageUrl: _presignedUrl,
      )));
      final img = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(img.imageUrl, _presignedUrl);
      expect(img.cacheKey, _stableKey);
    });

    testWidgets('shows initials as placeholder while loading', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(
        name: 'Ibrahima Diallo',
        imageUrl: _presignedUrl,
      )));
      await tester.pump();
      expect(find.text('ID'), findsOneWidget);
    });

    testWidgets('shows initials without imageUrl', (tester) async {
      await tester.pumpWidget(_wrap(const DonyAvatar(name: 'Ibrahima Diallo')));
      expect(find.text('ID'), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}
