import 'dart:async';

import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/language_sync_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Relance [LanguageSyncCubit.sync] à chaque langue effective résolue
/// (démarrage, choix manuel dans Réglages, changement de langue du
/// téléphone) et à chaque transition d'[AuthBloc] (connexion, déconnexion,
/// mise à jour de profil).
///
/// `StatefulWidget` sans `setState` : [didChangeDependencies] dépend
/// uniquement de `Localizations.localeOf(context)` (via
/// `context.dependOnInheritedWidgetOfExactType`) — lire `AuthBloc` avec
/// `context.read` n'ajoute aucune dépendance supplémentaire, d'où le
/// `BlocListener` dédié pour rejouer la synchro à chaque changement d'état
/// d'authentification.
class LanguageSyncGate extends StatefulWidget {
  const LanguageSyncGate({required this.child, super.key});

  final Widget child;

  @override
  State<LanguageSyncGate> createState() => _LanguageSyncGateState();
}

class _LanguageSyncGateState extends State<LanguageSyncGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(context, context.read<AuthBloc>().state);
  }

  void _sync(BuildContext context, AuthState authState) {
    // Langue résolue (`fr`/`en`), jamais `system` : c'est ce que
    // `Localizations.localeOf` renvoie une fois le choix ('system' ou
    // manuel) tranché par `AppL10n.localeListResolution`.
    final effective = Localizations.localeOf(context).languageCode;
    unawaited(
      context.read<LanguageSyncCubit>().sync(
        effective: effective,
        user: authState.currentUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, AuthState>(listener: _sync, child: widget.child);
}
