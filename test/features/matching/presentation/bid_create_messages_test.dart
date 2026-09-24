// Messages introduits par la tâche C2 (création d'une offre) : le pluriel
// `bidCreateSelectedItems` et le disclaimer horodaté `bidCreateDisclaimerSigned`
// — vérifiés en français (identiques à l'ancien rendu) et en anglais — plus
// un test anglais qui ouvre la feuille de création d'offre et vérifie son
// titre.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/content_categories/data/content_category_model.dart';
import 'package:dony/features/content_categories/data/content_category_repository.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_photo_upload.dart';
import 'package:dony/features/matching/bloc/bid_photos_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/create_bid_bottom_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/disclaimer_card.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/recipients/bloc/recipient_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

// ── Mocks (harnais minimal pour ouvrir CreateBidScreen) ─────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockBidPhotosCubit extends MockCubit<List<BidPhotoUpload>>
    implements BidPhotosCubit {}

class _MockRecipientBloc extends MockBloc<RecipientEvent, RecipientState>
    implements RecipientBloc {}

class _FakeContentCategoryRepository implements IContentCategoryRepository {
  @override
  Future<List<ContentCategory>> getCategories() async => fallbackCatalog;
}

AnnouncementModel _announcement() => AnnouncementModel(
  id: 'ann-1',
  travelerId: 'trav-1',
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

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('bidCreateSelectedItems', () {
    test('français : accord singulier/pluriel identique à l\'ancien rendu', () {
      // Ancien rendu : '$totalSelected article${n > 1 ? 's' : ''} sélectionné${n > 1 ? 's' : ''}'
      expect(fr.bidCreateSelectedItems(1), '1 article sélectionné');
      expect(fr.bidCreateSelectedItems(3), '3 articles sélectionnés');
    });

    test('anglais', () {
      expect(en.bidCreateSelectedItems(1), '1 item selected');
      expect(en.bidCreateSelectedItems(3), '3 items selected');
    });
  });

  group('bidCreateDisclaimerSigned', () {
    final signedAt = DateTime(2026, 10, 6, 14, 5);

    test('français : identique à l\'ancien "dd/MM/yyyy à HH:mm"', () {
      final dateTime = fr.commonDateAtTime(
        DateFormat.yMd('fr').format(signedAt),
        DateFormat.jm('fr').format(signedAt),
      );
      expect(
        fr.bidCreateDisclaimerSigned(dateTime),
        'Disclaimer signé le 06/10/2026 à 14:05',
      );
    });

    test('anglais', () {
      final dateTime = en.commonDateAtTime(
        DateFormat.yMd('en').format(signedAt),
        DateFormat.jm('en').format(signedAt),
      );
      expect(
        en.bidCreateDisclaimerSigned(dateTime),
        'Disclaimer signed on $dateTime',
      );
    });

    testWidgets('DisclaimerCard affiche la date dans la langue courante', (
      tester,
    ) async {
      useEnglish();
      final bid = BidModel(
        id: 'bid-1',
        announcementId: 'ann-1',
        senderId: 'sender-1',
        weightKg: 5,
        status: 'ACCEPTED',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        disclaimerSignedAt: signedAt,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DisclaimerCard(bid: bid)),
        ),
      );

      final expected = en.bidCreateDisclaimerSigned(
        en.commonDateAtTime(
          DateFormat.yMd('en').format(signedAt.toLocal()),
          DateFormat.jm('en').format(signedAt.toLocal()),
        ),
      );
      expect(find.text(expected), findsOneWidget);
    });
  });

  group('CreateBidScreen — titre', () {
    late _MockBidBloc bidBloc;
    late _MockPaymentBloc paymentBloc;
    late _MockBidPhotosCubit photosCubit;
    late _MockRecipientBloc recipientBloc;

    setUpAll(() {
      registerFallbackValue(BidInitial());
      registerFallbackValue(const PaymentInitial());
    });

    setUp(() {
      bidBloc = _MockBidBloc();
      when(() => bidBloc.state).thenReturn(BidInitial());
      when(() => bidBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => bidBloc.close()).thenAnswer((_) async {});

      paymentBloc = _MockPaymentBloc();
      when(() => paymentBloc.state).thenReturn(const PaymentInitial());
      when(() => paymentBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => paymentBloc.close()).thenAnswer((_) async {});

      photosCubit = _MockBidPhotosCubit();
      when(() => photosCubit.state).thenReturn(const <BidPhotoUpload>[]);
      when(() => photosCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => photosCubit.close()).thenAnswer((_) async {});
      when(() => photosCubit.readyKeys).thenReturn(const <String>[]);

      recipientBloc = _MockRecipientBloc();
      when(() => recipientBloc.state).thenReturn(const RecipientState());
      when(() => recipientBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => recipientBloc.close()).thenAnswer((_) async {});

      void register<T extends Object>(T Function() factory) {
        if (getIt.isRegistered<T>()) getIt.unregister<T>();
        getIt.registerFactory<T>(factory);
      }

      register<BidBloc>(() => bidBloc);
      register<PaymentBloc>(() => paymentBloc);
      register<BidPhotosCubit>(() => photosCubit);
      register<RecipientBloc>(() => recipientBloc);
      register<IContentCategoryRepository>(_FakeContentCategoryRepository.new);
    });

    tearDown(() {
      void unregister<T extends Object>() {
        if (getIt.isRegistered<T>()) getIt.unregister<T>();
      }

      unregister<BidBloc>();
      unregister<PaymentBloc>();
      unregister<BidPhotosCubit>();
      unregister<RecipientBloc>();
      unregister<IContentCategoryRepository>();
    });

    testWidgets('en anglais : titre "Make a request"', (tester) async {
      useEnglish();
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: CreateBidScreen(announcement: _announcement())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Make a request'), findsOneWidget);
    });
  });
}
