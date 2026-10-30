import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// `context.read<T>()`, ou `null` quand aucun provider de [T] n'est au-dessus
/// de [context] (widget monté hors de l'écran qui le fournit, tests).
T? maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
