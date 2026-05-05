import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// UpgradeToProScreen handles upgrading a traveler account to PRO status.
/// Uses StatefulWidget only for form controllers; all API calls go via
/// ProfileRepository directly (no dedicated BLoC needed for a one-shot form).
class UpgradeToProScreen extends StatefulWidget {
  const UpgradeToProScreen({super.key});

  @override
  State<UpgradeToProScreen> createState() => _UpgradeToProScreenState();
}

class _UpgradeToProScreenState extends State<UpgradeToProScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await _showConfirmationDialog();
    if (!confirmed || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = getIt<ProfileRepository>();
      await repo.upgradeToPro(
        companyName: _companyNameCtrl.text.trim(),
        siret: _siretCtrl.text.trim(),
      );

      if (!mounted) return;
      DonySnackbar.show(
        context,
        message: 'Compte PRO activé',
        type: DonySnackbarType.success,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _errorMessage = msg.contains('409') ||
                msg.toLowerCase().contains('already')
            ? 'Un compte Stripe Connect existe déjà. Contactez le support.'
            : 'Une erreur est survenue. Veuillez réessayer.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final result = await DonyDialog.show(
      context,
      title: 'Confirmer le passage en PRO',
      message:
          'Ce choix est définitif tant que la recréation de compte Connect n\'est pas implémentée. Êtes-vous sûr ?',
      confirmLabel: 'Confirmer',
      cancelLabel: 'Annuler',
      variant: DonyDialogVariant.destructive,
      icon: Icons.warning_amber_rounded,
    );
    return result ?? false;
  }

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
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero section
              DonyIconContainer(
                icon: Icons.business_center_rounded,
                size: DonyIconContainerSize.xl,
                borderRadius: DonyRadius.xl,
                backgroundColor: DonyColors.warning50,
                iconColor: DonyColors.warning,
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

              // Warning
              const DonyStatusBanner(
                type: DonyStatusBannerType.warning,
                icon: Icons.warning_amber_rounded,
                message:
                    'Cette action est définitive. Tu ne pourras pas revenir au statut standard sans contacter le support.',
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

              // Error message
              if (_errorMessage != null) ...[
                DonyStatusBanner(
                  type: DonyStatusBannerType.error,
                  message: _errorMessage!,
                ).animate().fadeIn(),
                const SizedBox(height: DonySpacing.lg),
              ],

              // Submit button
              DonyButton(
                label: 'Activer le compte PRO',
                icon: Icons.verified_rounded,
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ).animate().fadeIn(delay: 260.ms),
            ],
          ).animate().slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}
