import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_status_signal.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Où en est le voyageur avec le badge GP Pro, tel que la ligne le dit.
enum ProfileGpProState {
  /// Première lecture de la demande en cours : ligne neutre, ni « Devenir GP
  /// Pro » ni pastille (on ne sait pas encore).
  loading('loading'),

  /// Pas GP Pro, aucune demande ouverte : « Devenir GP Pro ».
  none('none'),

  /// Demande ouverte (en attente de l'identité ou de l'équipe).
  open('open'),

  /// Badge accordé.
  active('active');

  const ProfileGpProState(this.wire);

  /// Valeur de la propriété `state` de l'événement de tap.
  final String wire;
}

/// Section « GP PRO » de l'écran Profil, entre « Argent » et « Ma réputation » :
/// une ligne qui ouvre `/profile/gp-pro`, dont le libellé suit l'état.
///
/// - GP Pro validé (`user.gpPro`, déjà dans le profil : aucune lecture réseau) :
///   « GP Pro », pastille « Actif » ;
/// - sinon, la demande est lue une fois (`GpProCubit.load`, comme la ligne
///   « Statut de voyageur » de « Modifier le profil ») : ouverte, la ligne dit
///   « Demande GP Pro », pastille « En validation » ; sinon « Devenir GP Pro ».
///
/// Une lecture qui échoue, ou un cubit absent du graphe, retombe sur « Devenir
/// GP Pro » : la ligne reste utilisable, jamais d'erreur affichée.
class ProfileGpProSection extends StatelessWidget {
  const ProfileGpProSection({super.key, required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionLabel(label: l.profileSectionGpPro, cs: cs),
        ProfileListSection(tiles: [_row(context)]),
      ],
    );
  }

  Widget _row(BuildContext context) {
    if (user?.gpPro ?? false) {
      return const _GpProRow(state: ProfileGpProState.active);
    }
    // Un cubit à lire seulement quand le profil ne dit pas déjà « GP Pro ».
    if (!getIt.isRegistered<GpProCubit>()) {
      return const _GpProRow(state: ProfileGpProState.none);
    }
    return BlocProvider<GpProCubit>(
      create: (_) => getIt<GpProCubit>()..load(),
      child: _StatusRefresher(
        child: BlocBuilder<GpProCubit, GpProCubitState>(
          buildWhen: (p, c) => p.status != c.status || p.load != c.load,
          builder: (context, s) => _GpProRow(
            state: switch ((s.status, s.load)) {
              (final status?, _) when status.isOpen => ProfileGpProState.open,
              (null, GpProLoadStatus.loading) => ProfileGpProState.loading,
              _ => ProfileGpProState.none,
            },
          ),
        ),
      ),
    );
  }
}

/// Relit la demande quand elle a pu changer, l'onglet Profil restant en mémoire
/// d'une visite à l'autre : un nouveau profil de l'`AuthBloc`, un changement de
/// statut GP Pro ([gpProStatusChanged], quel que soit l'écran d'où il vient), la
/// reprise de l'app. `GpProCubit.load` ignore un appel pendant une lecture en
/// cours : pas de requêtes en rafale. Le `State` ne porte que des abonnements,
/// jamais d'état d'écran (aucun `setState`).
class _StatusRefresher extends StatefulWidget {
  const _StatusRefresher({required this.child});

  final Widget child;

  @override
  State<_StatusRefresher> createState() => _StatusRefresherState();
}

class _StatusRefresherState extends State<_StatusRefresher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gpProStatusChanged.addListener(_reload);
  }

  @override
  void dispose() {
    gpProStatusChanged.removeListener(_reload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (!mounted) return;
    final cubit = maybeRead<GpProCubit>(context);
    if (cubit != null && !cubit.isClosed) unawaited(cubit.load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = maybeRead<AuthBloc>(context);
    if (auth == null) return widget.child;
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => prev.currentUser != curr.currentUser,
      listener: (_, _) => _reload(),
      child: widget.child,
    );
  }
}

class _GpProRow extends StatelessWidget {
  const _GpProRow({required this.state});

  final ProfileGpProState state;

  Future<void> _open(BuildContext context) async {
    final analytics = getItSafe<AnalyticsService>();
    if (analytics != null) {
      unawaited(
        analytics.logEvent(
          AnalyticsEvents.profileGpProRowTapped,
          properties: {'state': state.wire},
        ),
      );
    }
    final auth = maybeRead<AuthBloc>(context);
    final cubit = maybeRead<GpProCubit>(context);
    await context.push<void>('/profile/gp-pro');
    // Au retour : une demande a pu partir ou être décidée, le badge a pu
    // changer. Le profil et la ligne se relisent.
    if (auth != null && !auth.isClosed) {
      auth.add(const AuthProfileRefreshRequested());
    }
    if (cubit != null && !cubit.isClosed) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final active = state == ProfileGpProState.active;
    final open = state == ProfileGpProState.open;
    final label = switch (state) {
      ProfileGpProState.loading => l.gpProBadgeLabel,
      ProfileGpProState.none => l.profileGpProBecome,
      ProfileGpProState.open => l.profileGpProApplication,
      ProfileGpProState.active => l.gpProBadgeLabel,
    };
    final pill = switch (state) {
      ProfileGpProState.loading || ProfileGpProState.none => null,
      ProfileGpProState.open => l.profileTravelerStatusPending,
      ProfileGpProState.active => l.profileGpProActivePill,
    };
    return DonyListTile(
      key: const Key('profile-gp-pro-row'),
      iconAsset: 'badge-check',
      iconColor: active ? cs.success : cs.primary,
      iconBgColor: active ? cs.successLight : cs.primaryContainer,
      label: label,
      subtitle: state == ProfileGpProState.none
          ? l.profileGpProBecomeSubtitle
          : null,
      trailing: pill == null
          ? null
          : _StatePill(
              label: pill,
              background: open ? cs.warningLight : cs.successLight,
              foreground: open ? cs.warning : cs.success,
            ),
      showDivider: false,
      onTap: () => unawaited(_open(context)),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
