import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SupportSummaryStatus {
  /// Rien de chargé pour l'instant.
  initial,

  /// Résumé servi par le back.
  ready,

  /// Back antérieur à `GET /support/summary` (404) : la ligne épinglée garde
  /// son texte d'invitation et ouvre l'écran `/support`.
  unavailable,
}

class SupportSummaryState extends Equatable {
  const SupportSummaryState({
    this.status = SupportSummaryStatus.initial,
    this.summary,
  });

  final SupportSummaryStatus status;
  final SupportSummary? summary;

  @override
  List<Object?> get props => [status, summary];
}

/// Résumé du support affiché par la ligne épinglée des conversations.
///
/// Singleton (via GetIt), rafraîchi par [SupportUnreadCubit.refresh] : un
/// seul appel à `/support/summary` alimente à la fois l'aperçu de la ligne et
/// le compteur de non-lus (pastille d'onglet, badge d'icône).
class SupportSummaryCubit extends Cubit<SupportSummaryState> {
  SupportSummaryCubit(this._repository) : super(const SupportSummaryState());

  final SupportRepository _repository;

  /// Rend le résumé chargé, ou `null` si le back ne le sert pas (404) ou si
  /// l'appel échoue. En cas d'échec réseau, l'état courant est conservé.
  Future<SupportSummary?> refresh() async {
    try {
      final summary = await _repository.getSummary();
      if (isClosed) return summary;
      emit(
        summary == null
            ? const SupportSummaryState(
                status: SupportSummaryStatus.unavailable,
              )
            : SupportSummaryState(
                status: SupportSummaryStatus.ready,
                summary: summary,
              ),
      );
      return summary;
    } catch (_) {
      // silence intentionnel : garder l'aperçu courant en cas d'erreur réseau
      return null;
    }
  }
}
