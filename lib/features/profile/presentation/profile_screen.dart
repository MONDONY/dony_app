import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/presentation/widgets/pending_deletion_banner.dart';
import 'package:dony/features/profile/presentation/widgets/profile_header.dart';
import 'package:dony/features/profile/presentation/widgets/profile_sections.dart';
import 'package:dony/features/settings/bloc/account_deletion_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran « Moi ».
///
/// Page unique : les trois onglets (Activité / Compte / Réglages) ont été
/// retirés. Une fois « Mes trajets et colis » parti vers le hub Activités,
/// chaque onglet ne portait plus que trois ou quatre lignes — la navigation
/// coûtait plus cher que le contenu qu'elle séparait.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scroll = ScrollController();

  final GlobalKey _headerKey = GlobalKey();
  double? _measuredHeaderHeight;

  /// Estimation de repli — utilisée uniquement à la 1re frame, avant la
  /// mesure réelle du header (puis remplacée par la hauteur exacte).
  static const double _kContentHeight = 124.0;
  static const double _kProgressBarSectionHeight = 38.0;

  /// Hauteur de la nav flottante + marge, pour que le bas de la page passe
  /// au-dessus de l'île de navigation.
  static const double _kNavBarClearance = 100.0;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthInitial || state is AuthAccountDeleted) {
              context.go('/auth/phone');
            }
          },
        ),
        BlocListener<AccountDeletionBloc, AccountDeletionState>(
          listener: (context, state) {
            if (state is AccountReactivated) {
              context.read<AuthBloc>().add(const AuthCheckRequested());
            } else if (state is AccountDeletionError) {
              ErrorPresenter.show(context, state.error);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (prev, curr) =>
              curr is AuthAuthenticated || curr is AuthProfileUpdated,
          builder: (context, authState) {
            UserModel? user;
            if (authState is AuthAuthenticated) user = authState.user;
            if (authState is AuthProfileUpdated) user = authState.user;

            final isTraveler = user?.isTraveler ?? false;
            final isSender = user?.isSender ?? false;
            final isKycVerified = user?.isKycVerified ?? false;
            final isProAccount = user?.isProAccount ?? false;
            final displayName = user?.displayName ?? 'Utilisateur';

            return Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final topPad = MediaQuery.of(context).padding.top;

                int completionSteps = user?.profileCompletionSteps ?? 0;
                if (user?.phoneNumber?.isNotEmpty == true) {
                  completionSteps++;
                }
                if (user?.email?.isNotEmpty == true) completionSteps++;
                if (user?.isKycVerified == true) completionSteps++;
                const totalCompletionSteps = UserModel.profileTotalSteps + 3;
                final profileCompletionPercent = user != null
                    ? completionSteps / totalCompletionSteps
                    : 0.0;
                final isProfileComplete = profileCompletionPercent >= 1.0;
                final fallbackHeight =
                    topPad +
                    56.0 +
                    _kContentHeight -
                    (isProfileComplete ? _kProgressBarSectionHeight : 0.0);
                // La hauteur mesurée inclut topPad (ProfileHeader le pose
                // en padding). Or SliverAppBar ré-ajoute topPad par-dessus
                // expandedHeight → l'extent vaudrait header+topPad et
                // laisserait ~topPad de vide sous le header. On le retranche.
                final rawHeaderHeight = _measuredHeaderHeight ?? fallbackHeight;
                final expandedHeight = (rawHeaderHeight - topPad).clamp(
                  kToolbarHeight,
                  double.infinity,
                );

                final profileHeader = ProfileHeader(
                  displayName: displayName,
                  isTraveler: isTraveler,
                  isSender: isSender,
                  isKycVerified: isKycVerified,
                  isProAccount: isProAccount,
                  avatarUrl: user?.avatarUrl,
                  phoneNumber: user?.phoneNumber,
                  email: user?.email,
                  city: user?.city,
                  profileCompletionPercent: profileCompletionPercent,
                  onEditProfile: () => context.push('/profile/edit'),
                  topPadding: topPad,
                );

                // Mesure la hauteur réelle du header (sonde hors-écran) pour
                // dimensionner l'AppBar exactement : zéro overflow, zéro gap,
                // quel que soit le wrap des chips ou la barre de progression.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final box =
                      _headerKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  final h = box?.size.height;
                  if (h != null &&
                      (_measuredHeaderHeight == null ||
                          (_measuredHeaderHeight! - h).abs() > 0.5)) {
                    setState(() => _measuredHeaderHeight = h);
                  }
                });

                return Stack(
                  children: [
                    // Sonde de mesure invisible (même config que l'en-tête
                    // visible) — ne peint rien, ne prend pas de place.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Offstage(
                        child: KeyedSubtree(
                          key: _headerKey,
                          child: profileHeader,
                        ),
                      ),
                    ),
                    RefreshIndicator(
                      color: cs.primary,
                      onRefresh: () async {
                        context.read<AuthBloc>().add(
                          const AuthProfileRefreshRequested(),
                        );
                      },
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          _appBar(
                            context: context,
                            expandedHeight: expandedHeight,
                            displayName: displayName,
                            avatarUrl: user?.avatarUrl,
                            isKycVerified: isKycVerified,
                            isProAccount: isProAccount,
                            header: profileHeader,
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              DonySpacing.lg,
                              DonySpacing.xl,
                              DonySpacing.lg,
                              _kNavBarClearance +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            sliver: SliverList.list(
                              children: _sections(
                                context: context,
                                user: user,
                                isProAccount: isProAccount,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _appBar({
    required BuildContext context,
    required double expandedHeight,
    required String displayName,
    required String? avatarUrl,
    required bool isKycVerified,
    required bool isProAccount,
    required Widget header,
  }) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      // Le titre replié s'abonne seul au scroll : sans ça, un setState par
      // pixel scrollé reconstruirait toute la page — et relancerait ses
      // animations d'entrée.
      title: AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) {
          final offset = _scroll.hasClients
              ? _scroll.offset.clamp(0.0, double.infinity)
              : 0.0;
          final progress = (offset / _kContentHeight).clamp(0.0, 1.0);

          return Opacity(
            opacity: progress,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyAvatar(
                  name: displayName,
                  imageUrl: avatarUrl,
                  size: DonyAvatarSize.xs,
                  verified: isKycVerified,
                  pro: isProAccount,
                ),
                const SizedBox(width: DonySpacing.sm),
                Flexible(
                  child: Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isKycVerified) ...[
                  const SizedBox(width: DonySpacing.xs),
                  DonyIcon(
                    'badge-check',
                    size: 13,
                    color: isProAccount
                        ? DonyColors.kycBadgeGold
                        : DonyColors.kycBadgeBlue,
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: const [],
      flexibleSpace: FlexibleSpaceBar(
        // none : pas de parallax/étirement du background (sinon il est
        // agrandi puis décalé → vide sous le header).
        collapseMode: CollapseMode.none,
        // Le background est forcé à la taille de l'extent du sliver. Au 1er
        // frame (avant mesure de la sonde) `expandedHeight` peut sous-estimer
        // la hauteur réelle du header (nom 2 lignes, chips qui wrap…) → la
        // Column déborderait. Le ScrollView non scrollable laisse le header
        // prendre sa hauteur naturelle : box trop courte = clip silencieux
        // (zéro overflow), box correcte = rendu identique (top-aligné).
        background: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: header,
        ),
      ),
    );
  }

  /// Contenu de la page, dans l'ordre : ce qu'on vient vérifier souvent
  /// (compte, argent) avant ce qu'on consulte rarement (suivi, réglages).
  ///
  /// Aucune section n'est conditionnée au rôle — modèle double rôle : tout
  /// utilisateur est voyageur et expéditeur dès l'inscription, et peut donc
  /// activer les paiements par carte comme passer en compte PRO.
  List<Widget> _sections({
    required BuildContext context,
    required UserModel? user,
    required bool isProAccount,
  }) {
    const gap = SizedBox(height: DonySpacing.xl);
    var delay = 80;
    Widget animated(Widget child) {
      final w = child
          .animate()
          .fadeIn(delay: Duration(milliseconds: delay))
          .slideY(begin: 0.04, curve: Curves.easeOutCubic);
      delay += 40;
      return w;
    }

    return [
      if (user != null &&
          user.isPendingDeletion &&
          user.deletionRequestedAt != null) ...[
        PendingDeletionBanner(
          deletionRequestedAt: user.deletionRequestedAt!,
          onReactivate: () => context.read<AccountDeletionBloc>().add(
            const ReactivateAccount(),
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
      ],
      if (user != null && !user.isProfileComplete) ...[
        ProfileCompletionBanner(
          user: user,
          onTap: () => context.push('/profile/edit'),
        ).animate().fadeIn(delay: 40.ms),
        const SizedBox(height: DonySpacing.lg),
      ],

      animated(ProfileAccountSection(user: user)),
      gap,
      animated(ProfileMoneySection(user: user)),
      gap,
      animated(ProfileReputationSection(user: user)),
      gap,
      animated(
        ProfileAdvantagesSection(user: user, isProAccount: isProAccount),
      ),
      gap,
      animated(const ProfileFollowUpSection()),
      gap,
      animated(const ProfileHelpSection()),

      const SizedBox(height: DonySpacing.xxl),
      DonyButton(
        label: 'Se déconnecter',
        onPressed: () async {
          final authBloc = context.read<AuthBloc>();
          final confirmed = await DonyDialog.show(
            context,
            title: 'Se déconnecter ?',
            message: 'Vous devrez saisir à nouveau votre numéro pour '
                'vous reconnecter.',
            confirmLabel: 'Se déconnecter',
            variant: DonyDialogVariant.destructive,
            iconAsset: 'circle-alert',
          );
          if (confirmed ?? false) {
            authBloc.add(const AuthLogoutRequested());
          }
        },
        variant: DonyButtonVariant.ghost,
      ),
      const SizedBox(height: DonySpacing.xxl),
      Text(
        'yadony v1.0.0 · Made with ❤️ in Paris',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
        textAlign: TextAlign.center,
      ),
    ];
  }
}
