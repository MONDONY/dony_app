import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/settings/bloc/language_sync_cubit.dart';
import 'package:dony/features/settings/bloc/language_sync_state.dart';
import 'package:dony/features/settings/presentation/widgets/language_sync_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/l10n_test_helpers.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockLanguageSyncCubit extends MockCubit<LanguageSyncState>
    implements LanguageSyncCubit {}

UserModel _user() => const UserModel(
  id: 'u1',
  roles: ['ROLE_SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  preferredLanguage: 'fr',
);

void main() {
  late _MockAuthBloc authBloc;
  late _MockLanguageSyncCubit cubit;

  setUpAll(() {
    registerFallbackValue(_user());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    cubit = _MockLanguageSyncCubit();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_user()));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(
      () => cubit.sync(
        effective: any(named: 'effective'),
        user: any(named: 'user'),
      ),
    ).thenAnswer((_) async {});

    addTearDown(authBloc.close);
    addTearDown(cubit.close);
  });

  Widget wrap(Widget child) => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<LanguageSyncCubit>.value(value: cubit),
    ],
    child: child,
  );

  testWidgets('langue fr résolue : sync appelé avec effective "fr"', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(wrap(const LanguageSyncGate(child: SizedBox.shrink()))),
    );

    verify(() => cubit.sync(effective: 'fr', user: _user())).called(1);
  });

  testWidgets('langue en résolue : sync appelé avec effective "en"', (
    tester,
  ) async {
    useEnglish();
    enableEnglish();

    await tester.pumpWidget(
      localizedApp(
        wrap(const LanguageSyncGate(child: SizedBox.shrink())),
        locale: AppL10n.en,
      ),
    );

    verify(() => cubit.sync(effective: 'en', user: _user())).called(1);
  });
}
