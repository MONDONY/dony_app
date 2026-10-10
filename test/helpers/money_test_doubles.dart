import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';

class MockMoneyOverviewBloc
    extends MockBloc<MoneyOverviewEvent, MoneyOverviewState>
    implements MoneyOverviewBloc {}

/// Enregistre la fabrique du [MoneyOverviewBloc] de la pastille « Mon
/// argent » de l'en-tête (FLUTTER-HV) : rien en attente par défaut, une
/// simple icône.
void registerFakeMoneyOverview({MoneyOverviewState? state}) {
  final initial = state ?? MoneyOverviewLoaded(const MoneyOverviewModel());
  getIt.registerFactoryParam<MoneyOverviewBloc, bool, void>((_, _) {
    final bloc = MockMoneyOverviewBloc();
    whenListen(
      bloc,
      const Stream<MoneyOverviewState>.empty(),
      initialState: initial,
    );
    return bloc;
  });
}
