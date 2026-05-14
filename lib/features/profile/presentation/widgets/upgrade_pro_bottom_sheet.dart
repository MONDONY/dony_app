import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UpgradeProBottomSheet extends StatefulWidget {
  const UpgradeProBottomSheet({
    super.key,
    required this.authBloc,
    required this.user,
    this.onSubmitReady,
  });

  final AuthBloc authBloc;
  final UserModel user;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(BuildContext context, {required UserModel user}) {
    final authBloc = context.read<AuthBloc>();
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      title: user.isProAccount ? 'Mon profil PRO' : 'Passer en Professionnel',
      subtitle: user.isProAccount
          ? null
          : 'Badge Pro · Volume + · Priorité de matching',
      wrapper: (child) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => UpgradeToProBloc(getIt<ProfileRepository>())),
          BlocProvider.value(value: authBloc),
        ],
        child: child,
      ),
      stickyBottom: BlocBuilder<UpgradeToProBloc, UpgradeToProState>(
        builder: (ctx, state) {
          final isLoading = state is UpgradeToProLoading;
          if (user.isProAccount) {
            return DonyButton(
              label: 'Désactiver le compte PRO',
              variant: DonyButtonVariant.secondary,
              isLoading: isLoading,
              onPressed: isLoading ? null : () => submit?.call(),
            );
          }
          return DonyButton(
            label: 'Activer le compte PRO',
            isLoading: isLoading,
            onPressed: isLoading ? null : () => submit?.call(),
          );
        },
      ),
      child: UpgradeProBottomSheet(
        authBloc: authBloc,
        user: user,
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<UpgradeProBottomSheet> createState() => _UpgradeProBottomSheetState();
}

class _UpgradeProBottomSheetState extends State<UpgradeProBottomSheet> {
  late final TextEditingController _companyCtrl;
  late final TextEditingController _siretCtrl;

  @override
  void initState() {
    super.initState();
    _companyCtrl = TextEditingController(text: widget.user.companyName ?? '');
    _siretCtrl = TextEditingController(text: widget.user.siret ?? '');
    widget.onSubmitReady?.call(
      widget.user.isProAccount ? _confirmDowngradeSubmit : _submitUpgrade,
    );
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  void _submitUpgrade() {
    final company = _companyCtrl.text.trim();
    final siret = _siretCtrl.text.trim().replaceAll(' ', '');
    if (company.isEmpty) {
      DonySnackbar.show(
        context,
        message: "Le nom de l'entreprise est requis",
        type: DonySnackbarType.error,
      );
      return;
    }
    if (siret.length != 14 || !RegExp(r'^\d+$').hasMatch(siret)) {
      DonySnackbar.show(
        context,
        message: 'Le SIRET doit comporter 14 chiffres',
        type: DonySnackbarType.error,
      );
      return;
    }
    context.read<UpgradeToProBloc>().add(UpgradeToProSubmitted(
          companyName: company,
          siret: siret,
        ));
  }

  Future<void> _confirmDowngradeSubmit() async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Désactiver le compte PRO',
      message:
          'Votre badge PRO et vos avantages seront supprimés. Cette action est irréversible.',
      confirmLabel: 'Désactiver',
      cancelLabel: 'Annuler',
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed == true && mounted) {
      context.read<UpgradeToProBloc>().add(const DowngradeRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UpgradeToProBloc, UpgradeToProState>(
      listener: (context, state) {
        if (state is UpgradeToProSuccess) {
          widget.authBloc.add(const AuthCheckRequested());
          Navigator.of(context, rootNavigator: true).pop();
          if (context.mounted) {
            DonySnackbar.show(
              context,
              message: 'Compte PRO activé !',
              type: DonySnackbarType.success,
            );
          }
        } else if (state is DowngradeSuccess) {
          widget.authBloc.add(const AuthCheckRequested());
          Navigator.of(context, rootNavigator: true).pop();
          if (context.mounted) {
            DonySnackbar.show(
              context,
              message: 'Compte PRO désactivé.',
              type: DonySnackbarType.success,
            );
          }
        } else if (state is UpgradeToProError) {
          ErrorPresenter.show(context, state.error);
        } else if (state is DowngradeError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) {
        final isLoading = state is UpgradeToProLoading;

        if (widget.user.isProAccount) {
          return _ProActiveView(user: widget.user);
        }

        return _UpgradeFormView(
          companyCtrl: _companyCtrl,
          siretCtrl: _siretCtrl,
          isLoading: isLoading,
          state: state,
        );
      },
    );
  }
}

// ── Vue compte PRO actif ──────────────────────────────────────────────────────

class _ProActiveView extends StatelessWidget {
  const _ProActiveView({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Badge PRO actif ───────────────────────────────────────────
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
        ),
        const SizedBox(height: DonySpacing.xl),

        // ── Infos entreprise ──────────────────────────────────────────
        if (user.companyName != null || user.siret != null) ...[
          Text(
            'INFORMATIONS ENTREPRISE',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          if (user.companyName != null)
            _InfoRow(
              icon: Icons.business_rounded,
              label: "Nom de l'entreprise",
              value: user.companyName!,
            ),
          if (user.companyName != null && user.siret != null)
            const SizedBox(height: DonySpacing.sm),
          if (user.siret != null)
            _InfoRow(
              icon: Icons.tag_rounded,
              label: 'SIRET',
              value: _formatSiret(user.siret!),
            ),
          const SizedBox(height: DonySpacing.xl),
        ],

        // ── Avantages ─────────────────────────────────────────────────
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
        ),
        const SizedBox(height: DonySpacing.xxl),
      ],
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

// ── Vue formulaire d'upgrade ──────────────────────────────────────────────────

class _UpgradeFormView extends StatelessWidget {
  const _UpgradeFormView({
    required this.companyCtrl,
    required this.siretCtrl,
    required this.isLoading,
    required this.state,
  });

  final TextEditingController companyCtrl;
  final TextEditingController siretCtrl;
  final bool isLoading;
  final UpgradeToProState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Avantages PRO ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: const Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            children: [
              _ProChip(label: 'Badge Pro'),
              _ProChip(label: 'Volume illimité'),
              _ProChip(label: 'Priorité matching'),
              _ProChip(label: 'Support dédié'),
            ],
          ),
        ),
        const SizedBox(height: DonySpacing.xl),

        // ── Champ entreprise ──────────────────────────────────────────
        DonyTextField(
          controller: companyCtrl,
          label: "Nom de l'entreprise",
          hint: 'SARL Diallo Transport',
          prefixIcon: Icons.business_rounded,
          keyboardType: TextInputType.text,
          enabled: !isLoading,
        ),
        const SizedBox(height: DonySpacing.sm),

        // ── Champ SIRET ───────────────────────────────────────────────
        DonyTextField(
          controller: siretCtrl,
          label: 'SIRET',
          hint: '123 456 789 00010',
          prefixIcon: Icons.tag_rounded,
          keyboardType: TextInputType.number,
          enabled: !isLoading,
        ),
        const SizedBox(height: DonySpacing.xl),

        // ── Erreur BLoC ───────────────────────────────────────────────
        if (state is UpgradeToProError) ...[
          DonyStatusBanner(
            type: DonyStatusBannerType.error,
            message: ErrorPresenter.resolve(
                    (state as UpgradeToProError).error)
                .message,
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        const SizedBox(height: DonySpacing.xl),
      ],
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
