import 'dart:async';

import 'package:dony/core/currency/country_picker.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/profile_basics_cubit.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';
import 'package:dony/features/auth/presentation/widgets/auth_flow_chrome.dart';
import 'package:dony/features/referral/data/pending_referral_redeemer.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Écran facultatif « Faisons connaissance », juste après le code de
/// vérification et avant les premiers pas (`firstStepsRoute`).
///
/// Hors du préfixe `/onboarding`, que le routeur traite comme public : cet
/// écran suppose un compte connecté.
const String profileBasicsRoute = '/auth/profile-basics';

/// Prénom, nom et pays de résidence sur un seul écran, rien d'obligatoire.
///
/// [initialCountryCode] est le pays déduit du numéro du compte
/// (`countryFromPhone`), lu par le routeur. Il n'est qu'affiché : rien n'est
/// écrit tant que l'utilisateur ne touche pas « Continuer ».
class ProfileBasicsScreen extends StatefulWidget {
  const ProfileBasicsScreen({
    super.key,
    this.initialCountryCode,
    this.redeemer,
  });

  final String? initialCountryCode;

  /// Applique le code parrain venu d'un lien d'invitation, une seule fois à
  /// l'ouverture. `null` : rien à appliquer.
  final PendingReferralRedeemer? redeemer;

  @override
  State<ProfileBasicsScreen> createState() => _ProfileBasicsScreenState();
}

class _ProfileBasicsScreenState extends State<ProfileBasicsScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  late final _country = ValueNotifier<String?>(widget.initialCountryCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileBasicsCubit>().trackViewed();
      unawaited(_applyReferral());
    });
  }

  Future<void> _applyReferral() async {
    final outcome = await widget.redeemer?.apply();
    if (outcome == PendingReferralOutcome.applied && mounted) {
      DonySnackbar.show(
        context,
        message: context.l10n.referralAutoAppliedMessage,
        type: DonySnackbarType.success,
      );
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _country.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<ProfileBasicsCubit>().submit(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      countryCode: _country.value,
    );
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(
      context,
      title: context.l10n.profileBasicsCountryLabel,
      selectedCode: _country.value,
    );
    if (picked != null && mounted) _country.value = picked;
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final l = context.l10n;

    return BlocConsumer<ProfileBasicsCubit, ProfileBasicsState>(
      listener: (context, state) {
        if (state is ProfileBasicsSuccess) {
          if (state.refreshProfile) {
            context.read<AuthBloc>().add(const AuthProfileRefreshRequested());
          }
          context.go(firstStepsRoute);
        } else if (state is ProfileBasicsError) {
          DonySnackbar.show(
            context,
            message: l.profileBasicsSaveError,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state is ProfileBasicsSaving;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const AuthFlowBackground(),
              SafeArea(
                child: DonyLayout.constrained(
                  context,
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      h,
                      DonySpacing.base,
                      h,
                      DonySpacing.base + bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthFlowHeader.plain(),
                        const SizedBox(height: DonySpacing.md),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: DonyBadge(
                                    label: l.profileBasicsEyebrow,
                                  ),
                                ),
                                const SizedBox(height: DonySpacing.sm),
                                AuthIntroCard.compact(
                                      iconAsset: 'user',
                                      title: l.profileBasicsTitle,
                                      body: l.profileBasicsBody,
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: 0.04),
                                const SizedBox(height: DonySpacing.md),
                                _ProfileFields(
                                  firstNameCtrl: _firstNameCtrl,
                                  lastNameCtrl: _lastNameCtrl,
                                  country: _country,
                                  prefilledCountry: widget.initialCountryCode,
                                  isSaving: isSaving,
                                  onPickCountry: _pickCountry,
                                ).animate().fadeIn(
                                  delay: 120.ms,
                                  duration: 300.ms,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AuthFlowActions(
                          primary: DonyButton(
                            key: const Key('profile-basics-continue'),
                            label: l.commonContinue,
                            iconAsset: 'arrow-right',
                            isLoading: isSaving,
                            onPressed: isSaving ? null : _submit,
                          ),
                          skipEnabled: !isSaving,
                          onSkip: () =>
                              context.read<ProfileBasicsCubit>().skip(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileFields extends StatelessWidget {
  const _ProfileFields({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.country,
    required this.prefilledCountry,
    required this.isSaving,
    required this.onPickCountry,
  });

  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final ValueNotifier<String?> country;
  final String? prefilledCountry;
  final bool isSaving;
  final VoidCallback onPickCountry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return DonyCard(
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DonyTextField(
                  key: const Key('profile-basics-first-name'),
                  controller: firstNameCtrl,
                  enabled: !isSaving,
                  textInputAction: TextInputAction.next,
                  label: l.profileBasicsFirstNameLabel,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: DonyTextField(
                  key: const Key('profile-basics-last-name'),
                  controller: lastNameCtrl,
                  enabled: !isSaving,
                  textInputAction: TextInputAction.done,
                  label: l.profileBasicsLastNameLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.base),
          ValueListenableBuilder<String?>(
            valueListenable: country,
            builder: (context, code, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DonyTextField.tappable(
                  key: const Key('profile-basics-country'),
                  label: l.profileBasicsCountryLabel,
                  value: code == null ? null : countryName(l, code),
                  prefixWidget: DonyIcon('globe', size: 20, color: cs.primary),
                  trailing: DonyIcon(
                    'chevron-down',
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: isSaving ? null : onPickCountry,
                ),
                if (code != null && code == prefilledCountry) ...[
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    l.profileBasicsCountryPrefilledHint,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
