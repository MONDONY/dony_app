import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/payments/money/bloc/money_overview_bloc.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';

class MockMoneyOverviewBloc
    extends MockBloc<MoneyOverviewEvent, MoneyOverviewState>
    implements MoneyOverviewBloc {}

/// Enregistre la fabrique du [MoneyOverviewBloc] de la pastille « Mon
/// argent » de l'en-tête d'Activités (FLUTTER-HV, FLUTTER-J3) : rien en attente par
/// défaut, une simple icône.
void registerFakeMoneyOverview({
  MoneyOverviewState state = const MoneyOverviewLoaded(MoneyOverviewModel()),
}) {
  getIt.registerFactoryParam<MoneyOverviewBloc, bool, void>((_, _) {
    final bloc = MockMoneyOverviewBloc();
    whenListen(
      bloc,
      const Stream<MoneyOverviewState>.empty(),
      initialState: state,
    );
    return bloc;
  });
}
