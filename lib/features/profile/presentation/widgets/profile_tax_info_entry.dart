import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:dony/features/tax_info/bloc/tax_info_prompt_cubit.dart';
import 'package:dony/features/tax_info/bloc/tax_info_signal.dart';
import 'package:dony/features/tax_info/bloc/tax_info_state.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Entrée « Informations fiscales » de l'écran Profil (déclaration DAC7), sous
/// la section « Argent ».
///
/// - voyageur concerné (`solicitation == SOLLICITER` ; collecte ciblée :
///   `INFO_REQUIRED` après une demande) : bannière discrète avec « Compléter »
///   et « Plus tard » (masquée pour la session) ;
/// - informations déjà fournies (`DEJA_FOURNI` ; collecte ciblée : `COMPLETE`,
///   ou `INFO_REQUIRED` sans bannière, sous-titre « À compléter ») : une ligne
///   discrète qui ouvre l'écran ;
/// - sinon (pays hors périmètre, pays inconnu), et pour toute réponse 404,
///   403, 401 ou ancien back : rien du tout, ni erreur ni espace.
///
/// Une lecture au chargement et à la reprise de l'app, coalescée par le cubit.
/// L'entrée porte elle-même son espacement bas : absente, elle ne laisse aucun
/// vide entre les sections.
class ProfileTaxInfoEntry extends StatelessWidget {
  const ProfileTaxInfoEntry({super.key, required this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final current = user;
    // Voyageurs seulement : le back répond 403 à un expéditeur pur, inutile de
    // l'interroger à chaque ouverture du Profil et à chaque reprise de l'app.
    if (current == null ||
        !current.isTraveler ||
        !getIt.isRegistered<TaxInfoPromptCubit>()) {
      return const SizedBox.shrink();
    }
    return BlocProvider<TaxInfoPromptCubit>(
      key: ValueKey('tax-info-prompt-${current.id}'),
      create: (_) => getIt<TaxInfoPromptCubit>(param1: current.id)..load(),
      child: _Refresher(
        child: BlocBuilder<TaxInfoPromptCubit, TaxInfoPromptState>(
          builder: (context, s) {
            if (s.showBanner) {
              return _Spaced(
                child: TaxInfoBanner(
                  residenceOnly: s.bannerAsksResidence,
                  onOpen: () => unawaited(_open(context, 'banner')),
                  onLater: context.read<TaxInfoPromptCubit>().dismiss,
                ),
              );
            }
            if (s.showRow) {
              return _Spaced(
                child: _Row(onTap: _open, needsAction: s.rowNeedsAction),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, String variant) async {
    context.read<TaxInfoPromptCubit>().trackTapped(variant);
    await context.push<void>('/profile/tax-info');
  }
}

class _Spaced extends StatelessWidget {
  const _Spaced({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      const SizedBox(height: DonySpacing.lg),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.onTap, required this.needsAction});

  final Future<void> Function(BuildContext context, String variant) onTap;

  /// Il manque quelque chose : « À compléter » au lieu de « Voir ou
  /// modifier ».
  final bool needsAction;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ProfileListSection(
      tiles: [
        DonyListTile(
          key: const Key('profile-tax-info-row'),
          iconAsset: 'landmark',
          iconColor: cs.primary,
          iconBgColor: cs.primaryContainer,
          label: l.taxInfoRowLabel,
          subtitle: needsAction
              ? l.taxInfoRowSubtitleToComplete
              : l.taxInfoRowSubtitle,
          showDivider: false,
          onTap: () => unawaited(onTap(context, 'row')),
        ),
      ],
    );
  }
}

/// Relit les informations quand elles ont pu changer, l'onglet Profil restant
/// en mémoire d'une visite à l'autre : enregistrement depuis l'écran
/// ([taxInfoChanged]), ouverture de l'onglet Profil
/// ([taxInfoRefreshRequested]) et reprise de l'app. `TaxInfoPromptCubit.load` coalesce
/// les appels : pas de requêtes en rafale. Le `State` ne porte que des
/// abonnements, jamais d'état d'écran (aucun `setState`).
class _Refresher extends StatefulWidget {
  const _Refresher({required this.child});

  final Widget child;

  @override
  State<_Refresher> createState() => _RefresherState();
}

class _RefresherState extends State<_Refresher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    taxInfoChanged.addListener(_reload);
    taxInfoRefreshRequested.addListener(_reload);
  }

  @override
  void dispose() {
    taxInfoChanged.removeListener(_reload);
    taxInfoRefreshRequested.removeListener(_reload);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    if (!mounted) return;
    final cubit = maybeRead<TaxInfoPromptCubit>(context);
    if (cubit != null && !cubit.isClosed) unawaited(cubit.load());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
