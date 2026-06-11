import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

// ── Tiny PNG fixture (1×1 px) ─────────────────────────────────────────────────

const _tinyPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(_MockTrackingBloc bloc) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () {
            QrSheet.show(
              ctx,
              bidId: 'bid-1',
              status: 'ACCEPTED',
              trackingBlocFactory: () => bloc,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TrackingQrCodeRequested('bid-1'));
  });

  // ── Test 1: Loading state → spinner ──────────────────────────────────────────

  testWidgets('état TrackingQrLoading → spinner visible dans le sheet', (
    tester,
  ) async {
    final bloc = _MockTrackingBloc();
    whenListen<TrackingState>(
      bloc,
      Stream<TrackingState>.fromIterable([TrackingQrLoading()]),
      initialState: TrackingQrLoading(),
    );

    await tester.pumpWidget(_host(bloc));
    await tester.tap(find.text('Open'));
    // Use pump with timeout instead of pumpAndSettle because CircularProgressIndicator
    // is animated and would cause pumpAndSettle to loop indefinitely.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // ── Test 2: Loaded state → Image, texte, boutons ─────────────────────────────

  testWidgets(
    'état TrackingQrLoaded → Image + texte imprimer + boutons Enregistrer et Partager',
    (tester) async {
      final bloc = _MockTrackingBloc();
      final qr = QrCodeModel(
        bidId: 'bid-1',
        scanUrl: 'https://dony.app/track/bid-1',
        qrCodeBase64: _tinyPngB64,
      );
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrLoaded(qr)]),
        initialState: TrackingQrLoaded(qr),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('imprimer'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Partager'), findsOneWidget);
    },
  );

  // ── Test 3: Error state → Réessayer + re-dispatch ────────────────────────────

  testWidgets(
    'état TrackingQrError → bouton Réessayer visible, tap re-dispatch TrackingQrCodeRequested',
    (tester) async {
      final bloc = _MockTrackingBloc();
      const error = NetworkException('Erreur réseau', code: 'NETWORK_ERROR');
      whenListen<TrackingState>(
        bloc,
        Stream<TrackingState>.fromIterable([TrackingQrError(error)]),
        initialState: TrackingQrError(error),
      );

      await tester.pumpWidget(_host(bloc));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      // The initial add (from BlocProvider create) + retry tap = 2 calls
      verify(
        () => bloc.add(any(that: isA<TrackingQrCodeRequested>())),
      ).called(2);
    },
  );
}
