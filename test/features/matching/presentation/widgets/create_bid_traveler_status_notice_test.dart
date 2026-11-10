import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/features/traveler_status/data/traveler_status.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

/// Lot 2 : avant le paiement, un encart d'information seulement si le voyageur
/// de l'annonce est un particulier (le droit de la consommation ne s'applique
/// pas à leur accord). Absent pour un professionnel et pour un statut inconnu
/// (ancien back, voyageur qui n'a pas répondu). Il ne bloque rien.

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeRecipientEvent extends Fake implements RecipientEvent {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

late _MockBidBloc _bidBloc;
late _MockPaymentBloc _paymentBloc;
late _MockWalletBloc _walletBloc;
late _MockBidPhotosCubit _photosCubit;
late _MockRecipientBloc _recipientBloc;

AnnouncementModel _announcement({TravelerStatus? status}) => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  arrivalCountryCode: 'SN',
  departureDate: DateTime(2026, 8, 15),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: 8,
  status: 'ACTIVE',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  traveler: TravelerProfile(
    id: 'trav-1',
    displayName: 'Aminata K.',
    travelerStatus: status,
  ),
);

Widget _harness(AnnouncementModel announcement, Locale locale) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => Scaffold(
          body: Builder(
            builder: (inner) => TextButton(
              onPressed: () =>
                  CreateBidBottomSheet.show(inner, announcement: announcement),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/bids/new',
        builder: (_, state) => CreateBidScreen(
          announcement: (state.extra! as CreateBidArgs).announcement,
          negotiation: (state.extra! as CreateBidArgs).negotiation,
        ),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Future<void> _open(
  WidgetTester tester,
  AnnouncementModel announcement, {
  Locale locale = AppL10n.fr,
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(announcement, locale));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidInitial());
    registerFallbackValue(const PaymentInitial());
    registerFallbackValue(_FakeRecipientEvent());
    if (!getIt.isRegistered<BidBloc>()) {
      getIt.registerFactory<BidBloc>(() => _bidBloc);
    }
    if (!getIt.isRegistered<PaymentBloc>()) {
      getIt.registerFactory<PaymentBloc>(() => _paymentBloc);
    }
    if (!getIt.isRegistered<WalletBloc>()) {
      getIt.registerFactory<WalletBloc>(() => _walletBloc);
    }
    if (!getIt.isRegistered<BidPhotosCubit>()) {
      getIt.registerFactory<BidPhotosCubit>(() => _photosCubit);
    }
    if (!getIt.isRegistered<RecipientBloc>()) {
      getIt.registerFactory<RecipientBloc>(() => _recipientBloc);
    }
    if (!getIt.isRegistered<IContentCategoryRepository>()) {
      getIt.registerFactory<IContentCategoryRepository>(
        () => _FakeContentCategoryRepository(),
      );
    }
  });

  setUp(() {
    _bidBloc = _MockBidBloc();
    when(() => _bidBloc.state).thenReturn(BidInitial());
    when(() => _bidBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _bidBloc.close()).thenAnswer((_) async {});

    _paymentBloc = _MockPaymentBloc();
    when(() => _paymentBloc.state).thenReturn(const PaymentInitial());
    when(() => _paymentBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _paymentBloc.close()).thenAnswer((_) async {});

    _walletBloc = _MockWalletBloc();
    when(() => _walletBloc.state).thenReturn(WalletInitial());
    when(() => _walletBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _walletBloc.close()).thenAnswer((_) async {});

    _photosCubit = _MockBidPhotosCubit();
    when(() => _photosCubit.state).thenReturn(const <BidPhotoUpload>[]);
    when(() => _photosCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => _photosCubit.close()).thenAnswer((_) async {});
    when(() => _photosCubit.readyKeys).thenReturn(const <String>[]);

    _recipientBloc = _MockRecipientBloc();
    when(
      () => _recipientBloc.state,
    ).thenReturn(const RecipientState(loaded: true));
    when(() => _recipientBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => _recipientBloc.close()).thenAnswer((_) async {});
    when(() => _recipientBloc.add(any())).thenReturn(null);
  });

  testWidgets('voyageur particulier : l\'encart d\'information est affiché', (
    tester,
  ) async {
    await _open(tester, _announcement(status: TravelerStatus.individual));

    final title = find.text(fr.bidCreateIndividualTravelerTitle);
    expect(title, findsOneWidget);
    expect(find.text(fr.bidCreateIndividualTravelerBody), findsOneWidget);
    expect(
      fr.bidCreateIndividualTravelerTitle,
      'Ce voyageur est un particulier.',
    );
    expect(
      fr.bidCreateIndividualTravelerBody,
      'Le droit de la consommation ne s\'applique pas à votre accord avec lui.',
    );
    expect(
      find.ancestor(of: title, matching: find.byType(DonyStatusBanner)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('voyageur professionnel : pas d\'encart', (tester) async {
    await _open(tester, _announcement(status: TravelerStatus.professional));
    expect(find.text(fr.bidCreateIndividualTravelerTitle), findsNothing);
    expect(find.text(fr.bidCreateIndividualTravelerBody), findsNothing);
  });

  testWidgets('statut inconnu (ancien back, non déclaré) : pas d\'encart', (
    tester,
  ) async {
    await _open(tester, _announcement());
    expect(find.text(fr.bidCreateIndividualTravelerTitle), findsNothing);
  });

  testWidgets('sans profil voyageur dans l\'annonce : pas d\'encart', (
    tester,
  ) async {
    final bare = AnnouncementModel(
      id: 'ann-2',
      travelerId: 'trav-2',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 15),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: 8,
      status: 'ACTIVE',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _open(tester, bare);
    expect(find.text(fr.bidCreateIndividualTravelerTitle), findsNothing);
  });

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('360 dp (${locale.languageCode}) : sans exception', (
      tester,
    ) async {
      final l = locale == AppL10n.fr ? fr : en;
      await _open(
        tester,
        _announcement(status: TravelerStatus.individual),
        locale: locale,
        width: 360,
      );
      expect(find.text(l.bidCreateIndividualTravelerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
