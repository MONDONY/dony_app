import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:flutter/widgets.dart';

/// Déclaration d'une feuille ouverte par-dessus un écran : elle affiche
/// elle-même les `CancellationError` de [bloc] (au-dessus d'elle, contexte de
/// la feuille).
///
/// L'écran dessous (fiche colis) ne se tait que pour un bloc ainsi déclaré :
/// son snackbar resterait caché sous la feuille, et, doublé, il éteindrait
/// celui de la feuille (déduplication de `DonySnackbar`). Une feuille qui ne
/// le déclare pas laisse l'écran afficher l'erreur comme avant (dialogue pour
/// une erreur critique, snackbar sinon).
///
/// À poser dans le contenu de la feuille, sous l'écouteur qui affiche
/// l'erreur. La déclaration vaut tant que le widget est monté, et par bloc :
/// deux écrans ne se gênent pas.
class CancellationErrorsShownAbove extends StatefulWidget {
  const CancellationErrorsShownAbove({
    super.key,
    required this.bloc,
    required this.child,
  });

  final CancellationBloc bloc;
  final Widget child;

  static final _claims = Expando<int>('cancellationErrorsShownAbove');

  /// Une feuille montée affiche les erreurs de [bloc].
  static bool isClaimed(CancellationBloc bloc) => (_claims[bloc] ?? 0) > 0;

  @override
  State<CancellationErrorsShownAbove> createState() =>
      _CancellationErrorsShownAboveState();
}

class _CancellationErrorsShownAboveState
    extends State<CancellationErrorsShownAbove> {
  static void _claim(CancellationBloc bloc) =>
      CancellationErrorsShownAbove._claims[bloc] =
          (CancellationErrorsShownAbove._claims[bloc] ?? 0) + 1;

  static void _release(CancellationBloc bloc) {
    final count = (CancellationErrorsShownAbove._claims[bloc] ?? 0) - 1;
    CancellationErrorsShownAbove._claims[bloc] = count > 0 ? count : null;
  }

  @override
  void initState() {
    super.initState();
    _claim(widget.bloc);
  }

  @override
  void didUpdateWidget(CancellationErrorsShownAbove oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bloc, widget.bloc)) {
      _release(oldWidget.bloc);
      _claim(widget.bloc);
    }
  }

  @override
  void dispose() {
    _release(widget.bloc);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
