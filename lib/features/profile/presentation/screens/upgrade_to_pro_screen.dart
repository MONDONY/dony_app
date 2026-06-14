import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// UpgradeToProScreen — handles BOTH states:
///   • Non-PRO: upgrade form (companyName + siret, 14-digit validation)
///   • Already PRO: read-only company info + downgrade action
///
/// Uses StatefulWidget ONLY for TextEditingController lifecycle.
/// All business state (loading, error, success) is managed by UpgradeToProBloc.
class UpgradeToProScreen extends StatelessWidget {
  const UpgradeToProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UpgradeToProBloc(getIt<ProfileRepository>()),
      child: const _UpgradeToProView(),
    );
  }
}

class _UpgradeToProView extends StatefulWidget {
  const _UpgradeToProView();

  @override
  State<_UpgradeToProView> createState() => _UpgradeToProViewState();
}

class _UpgradeToProViewState extends State<_UpgradeToProView> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(AnalyticsEvents.upgradeToProStarted),
      );
    });
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await _showConfirmationDialog(context);
    if (!confirmed || !context.mounted) return;

    context.read<UpgradeToProBloc>().add(
      UpgradeToProSubmitted(
        companyName: _companyNameCtrl.text.trim(),
        siret: _siretCtrl.text.trim(),
      ),
    );
  }

  Future<bool> _showConfirmationDialog(BuildContext context) async {
    final result = await DonyDialog.show(
      context,
      title: 'Confirmer le passage en PRO',
      message:
          'Votre profil sera mis à jour avec le statut PRO. Vous pourrez modifier ces informations à tout moment.',
      icon: Icons.verified_rounded,
    );
    return result ?? false;
  }

  Future<void> _confirmDowngrade(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Désactiver le compte PRO',
      message:
          'Votre badge PRO et vos avantages seront supprimés. Cette action est irréversible.',
      confirmLabel: 'Désactiver',
      cancelLabel: 'Annuler',
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed == true && context.mounted) {
      context.read<UpgradeToProBloc>().add(const DowngradeRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read current user from the global AuthBloc
    final authState = context.watch<AuthBloc>().state;
    UserModel? user;
    if (authState is AuthAuthenticated) user = authState.user;
    if (authState is AuthProfileUpdated) user = authState.user;

    final isProAccount = user?.isProAccount ?? false;

    return BlocListener<UpgradeToProBloc, UpgradeToProState>(
      listener: (context, state) {
        if (state is UpgradeToProSuccess) {
          context.read<AuthBloc>().add(const AuthCheckRequested());
          DonySnackbar.show(
            context,
            message: 'Compte PRO activé',
            type: DonySnackbarType.success,
          );
          if (context.canPop()) {
            context.pop();
          }
        } else if (state is DowngradeSuccess) {
          context.read<AuthBloc>().add(const AuthCheckRequested());
          DonySnackbar.show(
            context,
            message: 'Compte PRO désactivé.',
            type: DonySnackbarType.success,
          );
          if (context.canPop()) {
            context.pop();
          }
        } else if (state is DowngradeError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: BlocBuilder<UpgradeToProBloc, UpgradeToProState>(
        builder: (context, state) {
          final isLoading = state is UpgradeToProLoading;

          if (isProAccount) {
            return _ProActiveScreen(
              user: user,
              isLoading: isLoading,
              onDowngrade: () => _confirmDowngrade(context),
            );
          }

          return _UpgradeFormScreen(
            formKey: _formKey,
            companyNameCtrl: _companyNameCtrl,
            siretCtrl: _siretCtrl,
            isLoading: isLoading,
            errorMessage: state is UpgradeToProError
                ? ErrorPresenter.resolve(state.error).message
                : null,
            onSubmit: () => _submit(context),
          );
        },
      ),
    );
  }
}

// ── Screen: compte PRO déjà actif ─────────────────────────────────────────────

class _ProActiveScreen extends StatelessWidget {
  const _ProActiveScreen({
    required this.user,
    required this.isLoading,
    required this.onDowngrade,
  });

  final UserModel? user;
  final bool isLoading;
  final VoidCallback onDowngrade;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Mon profil PRO'),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.xl,
                DonySpacing.lg,
                DonySpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Badge PRO actif ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(DonySpacing.base),
                    decoration: BoxDecoration(
                      color: cs.successLight,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      border: Border.all(
                        color: cs.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(DonySpacing.sm),
                          decoration: BoxDecoration(
                            color: cs.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            color: cs.success,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compte PRO actif',
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.success,
                                ),
                              ),
                              Text(
                                'Vous bénéficiez de tous les avantages PRO',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 60.ms),
                  const SizedBox(height: DonySpacing.xl),

                  // ── Infos entreprise ────────────────────────────────
                  if (user?.companyName != null || user?.siret != null) ...[
                    Text(
                      'INFORMATIONS ENTREPRISE',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.md),
                    if (user?.companyName != null)
                      _InfoRow(
                        icon: Icons.business_rounded,
                        label: "Nom de l'entreprise",
                        value: user!.companyName!,
                      ).animate().fadeIn(delay: 100.ms),
                    if (user?.companyName != null && user?.siret != null)
                      const SizedBox(height: DonySpacing.sm),
                    if (user?.siret != null)
                      _InfoRow(
                        icon: Icons.tag_rounded,
                        label: 'SIRET',
                        value: _formatSiret(user!.siret!),
                      ).animate().fadeIn(delay: 140.ms),
                    const SizedBox(height: DonySpacing.xl),
                  ],

                  // ── Avantages ───────────────────────────────────────
                  Text(
                    'VOS AVANTAGES',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  const Wrap(
                    spacing: DonySpacing.sm,
                    runSpacing: DonySpacing.xs,
                    children: [
                      _ProChip(label: 'Badge Pro'),
                      _ProChip(label: 'Volume illimité'),
                      _ProChip(label: 'Priorité matching'),
                      _ProChip(label: 'Support dédié'),
                    ],
                  ).animate().fadeIn(delay: 180.ms),
                  const SizedBox(height: DonySpacing.xxl),
                ],
              ),
            ),
          ),

          // ── Sticky bottom button ───────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.sm,
                DonySpacing.lg,
                DonySpacing.lg,
              ),
              child: DonyButton(
                label: 'Revenir en compte standard',
                variant: DonyButtonVariant.destructive,
                isLoading: isLoading,
                onPressed: isLoading ? null : onDowngrade,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSiret(String siret) {
    if (siret.length != 14) return siret;
    return '${siret.substring(0, 3)} ${siret.substring(3, 6)} '
        '${siret.substring(6, 9)} ${siret.substring(9, 14)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 18),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  value,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen: formulaire d'upgrade ──────────────────────────────────────────────

class _UpgradeFormScreen extends StatelessWidget {
  const _UpgradeFormScreen({
    required this.formKey,
    required this.companyNameCtrl,
    required this.siretCtrl,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController companyNameCtrl;
  final TextEditingController siretCtrl;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Compte PRO'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.xl,
          DonySpacing.lg,
          DonySpacing.huge,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              const DonyMascotteAnimated(
                type: DonyMascotteType.securise,
                size: DonyMascotteSize.lg,
              ),
              const SizedBox(height: DonySpacing.xl),

              Text(
                'Passe en PRO',
                style: tt.displayLarge,
              ).animate().fadeIn(delay: 60.ms),
              const SizedBox(height: DonySpacing.md),

              Text(
                'Le statut PRO te permet de déclarer ton activité de transporteur. Renseigne les informations de ton entreprise ou de ton auto-entreprise.',
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.55,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: DonySpacing.xxl),

              // Info
              const DonyStatusBanner(
                type: DonyStatusBannerType.info,
                icon: Icons.info_outline_rounded,
                message:
                    'Vos informations d\'entreprise seront visibles sur votre profil public.',
              ).animate().fadeIn(delay: 140.ms),
              const SizedBox(height: DonySpacing.xl),

              // Company name field
              DonyTextField(
                controller: companyNameCtrl,
                label: 'Nom de l\'entreprise',
                hint: 'Ma Société SAS',
                prefixIcon: Icons.business_rounded,
                keyboardType: TextInputType.text,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Le nom de l\'entreprise est requis';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 180.ms),
              const SizedBox(height: DonySpacing.md),

              // SIRET field
              DonyTextField(
                controller: siretCtrl,
                label: 'Numéro SIRET',
                hint: '12345678901234',
                prefixIcon: Icons.tag_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Le numéro SIRET est requis';
                  }
                  final digits = v.trim().replaceAll(' ', '');
                  if (digits.length != 14 ||
                      !RegExp(r'^\d+$').hasMatch(digits)) {
                    return 'Le SIRET doit contenir exactement 14 chiffres';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 220.ms),
              const SizedBox(height: DonySpacing.xl),

              // Error message from BLoC
              if (errorMessage != null) ...[
                DonyStatusBanner(
                  type: DonyStatusBannerType.error,
                  message: errorMessage!,
                ).animate().fadeIn(),
                const SizedBox(height: DonySpacing.lg),
              ],

              // Submit button
              DonyButton(
                label: 'Activer le compte PRO',
                icon: Icons.verified_rounded,
                onPressed: isLoading ? null : onSubmit,
                isLoading: isLoading,
              ).animate().fadeIn(delay: 260.ms),
            ],
          ).animate().slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

// ── Composants partagés ───────────────────────────────────────────────────────

class _ProChip extends StatelessWidget {
  const _ProChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, color: cs.primary, size: 12),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
