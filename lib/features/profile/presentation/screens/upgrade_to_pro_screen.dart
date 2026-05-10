import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/profile/bloc/upgrade_to_pro_bloc.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// UpgradeToProScreen — uses StatefulWidget ONLY for TextEditingController
/// lifecycle. All business state (loading, error, success) is managed by
/// UpgradeToProBloc — no setState.
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

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocListener<UpgradeToProBloc, UpgradeToProState>(
      listener: (context, state) {
        if (state is UpgradeToProSuccess) {
          // Rafraîchit le UserModel dans AuthBloc pour que isProAccount
          // soit à jour partout dans l'app dès le retour au profil.
          context.read<AuthBloc>().add(const AuthCheckRequested());
          DonySnackbar.show(
            context,
            message: 'Compte PRO activé',
            type: DonySnackbarType.success,
          );
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: BlocBuilder<UpgradeToProBloc, UpgradeToProState>(
        builder: (context, state) {
          final isLoading = state is UpgradeToProLoading;
          final errorMessage = state is UpgradeToProError
              ? ErrorPresenter.resolve(state.error).message
              : null;

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
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero section
                    DonyIconContainer(
                      icon: Icons.business_center_rounded,
                      size: DonyIconContainerSize.xl,
                      borderRadius: DonyRadius.xl,
                      backgroundColor: cs.warningLight,
                      iconColor: cs.warning,
                    ).animate().fadeIn(duration: 260.ms),
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
                      controller: _companyNameCtrl,
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
                      controller: _siretCtrl,
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
                        message: errorMessage,
                      ).animate().fadeIn(),
                      const SizedBox(height: DonySpacing.lg),
                    ],

                    // Submit button
                    DonyButton(
                      label: 'Activer le compte PRO',
                      icon: Icons.verified_rounded,
                      onPressed: isLoading ? null : () => _submit(context),
                      isLoading: isLoading,
                    ).animate().fadeIn(delay: 260.ms),
                  ],
                ).animate().slideY(begin: 0.04, curve: Curves.easeOutCubic),
              ),
            ),
          );
        },
      ),
    );
  }
}
