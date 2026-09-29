import 'package:dony/features/support/bloc/support_summary_cubit.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Compteur global de messages non lus dans les tickets support.
///
/// Singleton (via GetIt) : le badge de l'onglet et l'écran de détail
/// partagent la même instance — sinon la pastille ne s'éteint pas à la
/// lecture.
///
/// [refresh] avale les erreurs réseau et garde la valeur courante ; le badge
/// reste à 0 par défaut si le chargement initial échoue.
///
/// [decrementBy] permet à l'écran de détail de décrémenter localement sans
/// attendre le serveur, pour une UX réactive. La valeur ne descend jamais
/// sous zéro.
///
/// Avec [summaryCubit], [refresh] passe d'abord par `/support/summary`, qui
/// alimente aussi l'aperçu de la ligne épinglée : compteur et aperçu viennent
/// de la même réponse. Sur un back antérieur (404), repli sur
/// `/support/unread-count`.
class SupportUnreadCubit extends Cubit<int> {
  SupportUnreadCubit(this._repository, {SupportSummaryCubit? summaryCubit})
    : _summaryCubit = summaryCubit,
      super(0);

  final SupportRepository _repository;
  final SupportSummaryCubit? _summaryCubit;

  Future<void> refresh() async {
    final summary = await _summaryCubit?.refresh();
    if (isClosed) return;
    if (summary != null) {
      emit(summary.unreadCount);
      return;
    }
    try {
      final count = await _repository.loadUnreadCount();
      if (!isClosed) emit(count);
    } catch (_) {
      // silence intentionnel : garder la valeur courante en cas d'erreur réseau
    }
  }

  void decrementBy(int n) {
    final next = state - n;
    emit(next < 0 ? 0 : next);
  }
}
