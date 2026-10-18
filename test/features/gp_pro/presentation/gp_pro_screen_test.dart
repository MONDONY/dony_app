import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/design/widgets/gp_pro_badge.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/media_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';
import 'package:dony/features/gp_pro/presentation/screens/gp_pro_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _MockGpProCubit extends MockCubit<GpProCubitState>
    implements GpProCubit {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockMediaService extends Mock implements DonyMediaService {}

const _verified = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

const _unverified = UserModel(
  id: 'u1',
  roles: ['TRAVELER'],
  kycStatus: 'NOT_STARTED',
  status: 'ACTIVE',
);

const _rgpd =
    'Vos documents servent uniquement à examiner votre demande. Ils sont '
    'supprimés dès que nous avons décidé.';

GpProCubitState _ready(
  GpProState state, {
  GpProFrequency? frequency,
  List<GpProPiece> pieces = const [],
  String? reason,
  String? commercialName,
  bool restarting = false,
  bool submitting = false,
  String? errorCode,
}) => GpProCubitState(
  load: GpProLoadStatus.ready,
  status: GpProStatus(
    state: state,
    reason: reason,
    commercialName: commercialName,
    travelFrequency: state == GpProState.none ? null : GpProFrequency.monthly,
  ),
  frequency: frequency,
  pieces: pieces,
  restarting: restarting,
  submitting: submitting,
  errorCode: errorCode,
);

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);
  late _MockGpProCubit cubit;
  late _MockAuthBloc auth;

  setUp(() {
    DonySnackbar.clearDedup();
    cubit = _MockGpProCubit();
    auth = _MockAuthBloc();
    when(() => auth.state).thenReturn(const AuthAuthenticated(_verified));
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.cancel()).thenAnswer((_) async {});
    when(() => cubit.removePiece(any())).thenAnswer((_) async {});
    when(
      () => cubit.submit(commercialName: any(named: 'commercialName')),
    ).thenAnswer((_) async {});
    when(
      () => cubit.addPiece(
        filePath: any(named: 'filePath'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async {});
  });

  setUpAll(() {
    registerFallbackValue(GpProDocType.other);
    registerFallbackValue(GpProFrequency.weekly);
  });

  Widget host() => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: auth),
      BlocProvider<GpProCubit>.value(value: cubit),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const GpProScreen()),
          GoRoute(
            path: '/kyc/verify',
            builder: (_, _) => const Scaffold(body: Text('ECRAN KYC')),
          ),
        ],
      ),
    ),
  );

  Future<void> pump(WidgetTester tester, GpProCubitState state) async {
    when(() => cubit.state).thenReturn(state);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  group('chargement', () {
    testWidgets('loading : indicateur', (tester) async {
      when(() => cubit.state).thenReturn(const GpProCubitState());
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l.gpProScreenTitle), findsOneWidget);
    });

    testWidgets('failure : « Réessayer » relance load', (tester) async {
      await pump(tester, const GpProCubitState(load: GpProLoadStatus.failure));
      expect(find.text(l.gpProFailureTitle), findsOneWidget);
      await tester.tap(find.text(l.commonRetry));
      verify(() => cubit.load()).called(1);
    });

    testWidgets('unavailable (back ancien) : indisponible pour le moment', (
      tester,
    ) async {
      await pump(
        tester,
        const GpProCubitState(load: GpProLoadStatus.unavailable),
      );
      expect(find.text('Indisponible pour le moment'), findsOneWidget);
      await tester.tap(find.text(l.commonRetry));
      verify(() => cubit.load()).called(1);
    });
  });

  group('NONE', () {
    testWidgets('sans KYC : bouton KYC, pas de formulaire', (tester) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_unverified));
      await pump(tester, _ready(GpProState.none));
      expect(find.text(l.gpProKycCta), findsOneWidget);
      expect(find.text(l.gpProSubmit), findsNothing);
      expect(find.text(l.gpProFrequencyWeekly), findsNothing);

      await tester.tap(find.text(l.gpProKycCta));
      await tester.pumpAndSettle();
      expect(find.text('ECRAN KYC'), findsOneWidget);
    });

    testWidgets('profil mis à jour (AuthProfileUpdated) vérifié : formulaire', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthProfileUpdated(_verified));
      await pump(tester, _ready(GpProState.none));
      expect(find.text(l.gpProSubmit), findsOneWidget);
      expect(find.text(l.gpProKycCta), findsNothing);
    });

    testWidgets('refus serveur gp-pro-kyc-required : voie KYC', (tester) async {
      await pump(
        tester,
        _ready(GpProState.none, errorCode: 'gp-pro-kyc-required'),
      );
      expect(find.text(l.gpProKycCta), findsOneWidget);
    });

    testWidgets('formulaire : libellés, phrase RGPD, envoi désactivé', (
      tester,
    ) async {
      await pump(tester, _ready(GpProState.none));
      for (final label in [
        'Chaque semaine',
        'Deux fois par mois',
        'Une fois par mois',
        'Moins souvent',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(_rgpd), findsOneWidget);
      expect(find.textContaining('facultatif'), findsWidgets);

      final submit = tester.widget<DonyButton>(
        find.byKey(const Key('gp_pro_submit')),
      );
      expect(submit.onPressed, isNull);
    });

    testWidgets('fréquence choisie : selectFrequency', (tester) async {
      when(() => cubit.selectFrequency(any())).thenReturn(null);
      await pump(tester, _ready(GpProState.none));
      await tester.tap(find.text('Chaque semaine'));
      verify(() => cubit.selectFrequency(GpProFrequency.weekly)).called(1);
    });

    testWidgets('envoi : submit avec le nom commercial saisi', (tester) async {
      await pump(
        tester,
        _ready(GpProState.none, frequency: GpProFrequency.weekly),
      );
      await tester.enterText(find.byType(TextField), 'Diallo Express');
      await tester.tap(find.byKey(const Key('gp_pro_submit')));
      verify(() => cubit.submit(commercialName: 'Diallo Express')).called(1);
    });

    testWidgets('nom commercial limité à 80 caractères', (tester) async {
      await pump(tester, _ready(GpProState.none));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 80);
    });

    testWidgets('« Refaire une demande » en cours : formulaire', (
      tester,
    ) async {
      await pump(
        tester,
        _ready(GpProState.rejected, restarting: true, reason: 'Motif X'),
      );
      expect(find.text(l.gpProSubmit), findsOneWidget);
      expect(find.text(l.gpProRestart), findsNothing);
    });
  });

  group('pièces', () {
    testWidgets('retrait d\'une pièce : removePiece', (tester) async {
      await pump(
        tester,
        _ready(
          GpProState.pending,
          pieces: const [
            GpProPiece(
              localId: 'r-1',
              type: GpProDocType.travelProof,
              remoteId: '1',
              status: GpProUploadStatus.ready,
            ),
          ],
        ),
      );
      expect(find.text('Billet ou carte d\'embarquement'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(l.gpProRemovePiece));
      verify(() => cubit.removePiece('r-1')).called(1);
    });

    testWidgets('envoi en cours : plus de retrait possible', (tester) async {
      // Le bouton d'envoi anime un indicateur sans fin : pas de pumpAndSettle.
      when(() => cubit.state).thenReturn(
        _ready(
          GpProState.none,
          frequency: GpProFrequency.monthly,
          submitting: true,
          pieces: const [
            GpProPiece(
              localId: 'r-1',
              type: GpProDocType.travelProof,
              remoteId: '1',
              status: GpProUploadStatus.ready,
            ),
          ],
        ),
      );
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Billet ou carte d\'embarquement'), findsOneWidget);
      expect(find.bySemanticsLabel(l.gpProRemovePiece), findsNothing);
      verifyNever(() => cubit.removePiece(any()));
    });

    testWidgets('pièce en échec : message d\'échec', (tester) async {
      await pump(
        tester,
        _ready(
          GpProState.pending,
          pieces: const [
            GpProPiece(
              localId: 'p0',
              type: GpProDocType.other,
              status: GpProUploadStatus.failed,
            ),
          ],
        ),
      );
      expect(find.text(l.gpProPieceFailed), findsOneWidget);
    });

    testWidgets('4 pièces : plus d\'ajout', (tester) async {
      await pump(
        tester,
        _ready(
          GpProState.pending,
          pieces: [
            for (var i = 0; i < 4; i++)
              GpProPiece(
                localId: 'r-$i',
                type: GpProDocType.other,
                remoteId: '$i',
                status: GpProUploadStatus.ready,
              ),
          ],
        ),
      );
      expect(find.text(l.gpProAddPiece), findsNothing);
    });

    group('ajout', () {
      late _MockMediaService media;

      setUp(() {
        media = _MockMediaService();
        getIt.registerSingleton<DonyMediaService>(media);
      });

      tearDown(() => getIt.unregister<DonyMediaService>());

      Future<void> choose(WidgetTester tester, String source) async {
        await pump(tester, _ready(GpProState.none));
        await tester.ensureVisible(find.text(l.gpProAddPiece));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.gpProAddPiece));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Registre d\'entreprise (Kbis, SIRET, NINEA, RCCM…)'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(source));
        await tester.pumpAndSettle();
      }

      testWidgets('type puis galerie : addPiece avec le type choisi', (
        tester,
      ) async {
        when(
          () => media.pick(source: ImageSource.gallery),
        ).thenAnswer((_) async => XFile('/tmp/kbis.jpg'));
        await choose(tester, l.commonPickFromGallery);
        verify(
          () => cubit.addPiece(
            filePath: '/tmp/kbis.jpg',
            type: GpProDocType.businessRegistration,
          ),
        ).called(1);
      });

      testWidgets('appareil annulé : rien n\'est ajouté', (tester) async {
        when(
          () => media.pick(source: ImageSource.camera),
        ).thenAnswer((_) async => null);
        await choose(tester, l.commonTakePhoto);
        verifyNever(
          () => cubit.addPiece(
            filePath: any(named: 'filePath'),
            type: any(named: 'type'),
          ),
        );
      });

      testWidgets('image trop lourde : avis d\'erreur', (tester) async {
        when(
          () => media.pick(source: ImageSource.camera),
        ).thenThrow(const MediaFileTooLargeException(1, 0));
        await choose(tester, l.commonTakePhoto);
        expect(find.text(l.commonImageUnsupported), findsOneWidget);
      });
    });
  });

  group('demandes ouvertes', () {
    testWidgets('PENDING : « En cours d\'examen », pièces, RGPD', (
      tester,
    ) async {
      await pump(
        tester,
        _ready(GpProState.pending, commercialName: 'Diallo Express'),
      );
      expect(find.text('En cours d\'examen'), findsOneWidget);
      expect(find.text('Diallo Express'), findsOneWidget);
      expect(find.text(l.gpProFrequencyMonthly), findsOneWidget);
      expect(find.text(_rgpd), findsOneWidget);
      expect(find.text(l.gpProAddPiece), findsOneWidget);
      expect(find.text(l.gpProCancel), findsOneWidget);
    });

    testWidgets('AWAITING_KYC : phrase d\'attente', (tester) async {
      await pump(tester, _ready(GpProState.awaitingKyc));
      expect(
        find.text('Votre demande partira dès que votre identité sera vérifiée'),
        findsOneWidget,
      );
      expect(find.text(l.gpProCancel), findsOneWidget);
      expect(find.text(_rgpd), findsOneWidget);
    });

    testWidgets('AWAITING_KYC sans KYC : vérifier puis recharger', (
      tester,
    ) async {
      when(() => auth.state).thenReturn(const AuthAuthenticated(_unverified));
      await pump(tester, _ready(GpProState.awaitingKyc));
      expect(find.text(l.gpProCancel), findsOneWidget);
      await tester.tap(find.text(l.gpProKycCta));
      await tester.pumpAndSettle();
      expect(find.text('ECRAN KYC'), findsOneWidget);
      // Retour du parcours KYC : le statut est relu.
      GoRouter.of(tester.element(find.text('ECRAN KYC'))).pop();
      await tester.pumpAndSettle();
      verify(() => cubit.load()).called(1);
    });

    testWidgets('annulation : confirmation puis cancel', (tester) async {
      await pump(tester, _ready(GpProState.pending));
      await tester.tap(find.text(l.gpProCancel));
      await tester.pumpAndSettle();
      expect(find.text(l.gpProCancelDialogTitle), findsOneWidget);
      verifyNever(() => cubit.cancel());

      await tester.tap(find.text(l.gpProCancelDialogConfirm));
      await tester.pumpAndSettle();
      verify(() => cubit.cancel()).called(1);
    });

    testWidgets('annulation abandonnée : aucun appel', (tester) async {
      await pump(tester, _ready(GpProState.pending));
      await tester.tap(find.text(l.gpProCancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.gpProCancelDialogKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.cancel());
    });
  });

  group('décisions', () {
    testWidgets('ACTIVE : badge non interactif', (tester) async {
      await pump(tester, _ready(GpProState.active));
      final badge = tester.widget<GpProBadge>(find.byType(GpProBadge));
      expect(badge.interactive, isFalse);
      expect(badge.surface, 'gp_pro_screen');
      expect(find.text(l.gpProActiveTitle), findsOneWidget);
      expect(find.text(l.gpProCancel), findsNothing);
    });

    testWidgets('REJECTED : motif et « Refaire une demande »', (tester) async {
      when(() => cubit.restart()).thenReturn(null);
      await pump(
        tester,
        _ready(GpProState.rejected, reason: 'Trajets trop rares'),
      );
      expect(find.text('Refusée'), findsOneWidget);
      expect(find.textContaining('Trajets trop rares'), findsOneWidget);
      await tester.tap(find.text('Refaire une demande'));
      verify(() => cubit.restart()).called(1);
    });

    testWidgets('REVOKED : « Retiré » et motif', (tester) async {
      when(() => cubit.restart()).thenReturn(null);
      await pump(tester, _ready(GpProState.revoked, reason: 'Abus'));
      expect(find.text('Retiré'), findsOneWidget);
      expect(find.textContaining('Abus'), findsOneWidget);
      await tester.tap(find.text('Refaire une demande'));
      verify(() => cubit.restart()).called(1);
    });
  });

  group('erreurs', () {
    Future<void> emitError(WidgetTester tester, String code) async {
      final controller = StreamController<GpProCubitState>();
      addTearDown(controller.close);
      whenListen(
        cubit,
        controller.stream,
        initialState: _ready(GpProState.pending),
      );
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      controller.add(_ready(GpProState.pending, errorCode: code));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('réseau : message réseau', (tester) async {
      await emitError(tester, 'network');
      expect(find.text(l.gpProErrorNetwork), findsOneWidget);
    });

    testWidgets('stockage indisponible : message dédié', (tester) async {
      await emitError(tester, 'gp-pro-document-storage-unavailable');
      expect(find.text(l.gpProErrorStorageUnavailable), findsOneWidget);
    });

    testWidgets('trop de justificatifs : message dédié', (tester) async {
      await emitError(tester, 'gp-pro-too-many-documents');
      expect(find.text(l.gpProErrorTooManyDocuments), findsOneWidget);
    });

    testWidgets('justificatif refusé : message dédié', (tester) async {
      await emitError(tester, 'gp-pro-document-invalid');
      expect(find.text(l.gpProErrorDocumentInvalid), findsOneWidget);
    });

    testWidgets('code inconnu : message générique', (tester) async {
      await emitError(tester, 'unknown');
      expect(find.text(l.gpProErrorGeneric), findsOneWidget);
    });
  });
}
