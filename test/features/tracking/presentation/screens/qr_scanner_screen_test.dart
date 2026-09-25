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

  // Régression finale F (Important 6 de la relecture) : la fonction comparait
  // le libellé traduit (`event.stepLabel(l)`), donc ne reconnaissait jamais
  // l'étape finale en anglais. Elle compare maintenant `eventType`, le code
  // d'étape serveur — indépendant de la langue affichée.
  group('isFinalDeliveryStep', () {
    test('reconnaît le code ARRIVEE', () {
      expect(isFinalDeliveryStep('ARRIVEE'), isTrue);
    });

    test('renvoie false pour les codes intermédiaires', () {
      expect(isFinalDeliveryStep('DEPART'), isFalse);
      expect(isFinalDeliveryStep('TRANSIT'), isFalse);
      expect(isFinalDeliveryStep(''), isFalse);
    });

    test('indépendant de la langue affichée (anglais)', () {
      useEnglish();
      expect(isFinalDeliveryStep('ARRIVEE'), isTrue);
      expect(isFinalDeliveryStep('DEPART'), isFalse);
    });
  });
}
