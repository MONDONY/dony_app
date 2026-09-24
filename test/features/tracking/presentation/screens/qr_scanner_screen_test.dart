import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/presentation/screens/qr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

Widget _wrap(TrackingBloc bloc, RatingBloc ratingBloc) => MaterialApp(
  home: MultiBlocProvider(
    providers: [
      BlocProvider<TrackingBloc>.value(value: bloc),
      BlocProvider<RatingBloc>.value(value: ratingBloc),
    ],
    child: const QrScannerScreen(),
  ),
);

void main() {
  group('QrScannerScreen — anglais', () {
    testWidgets('titre, étape et bouton traduits', (tester) async {
      useEnglish();
      final bloc = _MockTrackingBloc();
      when(() => bloc.state).thenReturn(TrackingInitial());
      whenListen(bloc, const Stream<TrackingState>.empty());
      final ratingBloc = _MockRatingBloc();
      when(() => ratingBloc.state).thenReturn(const RatingInitial());
      whenListen(ratingBloc, const Stream<RatingState>.empty());

      await tester.pumpWidget(_wrap(bloc, ratingBloc));
      await tester.pump();

      expect(find.text('Departure scan'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Confirm & continue'), findsOneWidget);

      // Laisse le temps aux timers internes (animations) de se terminer
      // avant la fin du test, sinon flutter_test signale un timer pendant.
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('isFinalDeliveryStep', () {
    test('reconnaît "livré" / "livraison" / "Colis livré"', () {
      expect(isFinalDeliveryStep('Colis livré'), isTrue);
      expect(isFinalDeliveryStep('Livraison terminée'), isTrue);
      expect(isFinalDeliveryStep('LIVRÉ'), isTrue);
    });

    test('reconnaît "remis"', () {
      expect(isFinalDeliveryStep('Remis au destinataire'), isTrue);
    });

    test('reconnaît "delivered" (fallback EN)', () {
      expect(isFinalDeliveryStep('Package delivered'), isTrue);
    });

    test('renvoie false pour étapes intermédiaires', () {
      expect(isFinalDeliveryStep('Embarqué'), isFalse);
      expect(isFinalDeliveryStep('En vol'), isFalse);
      expect(isFinalDeliveryStep('Retiré au point relais'), isFalse);
      expect(isFinalDeliveryStep(''), isFalse);
    });
  });
}
