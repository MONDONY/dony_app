import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final _ctrl = TextEditingController();
  final _isNotEmpty = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => _isNotEmpty.value = _ctrl.text.trim().isNotEmpty);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _isNotEmpty.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      return;
    }
    context.read<ReferralBloc>().add(ReferralRedeemRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: (context, state) {
        if (state is ReferralRedeemError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      builder: (context, state) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: DonyLayout.constrained(
            context,
            Padding(
              padding: EdgeInsets.symmetric(horizontal: h),
              child: state is ReferralRedeemed
                  ? _SuccessView(onContinue: () => context.go('/home'))
                  : _FormView(
                      ctrl: _ctrl,
                      isNotEmpty: _isNotEmpty,
                      isLoading: state is ReferralRedeemLoading,
                      onApply: _apply,
                      onSkip: () => context.go('/home'),
                      bottom: bottom,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form view ─────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    required this.ctrl,
    required this.isNotEmpty,
    required this.isLoading,
    required this.onApply,
    required this.onSkip,
    required this.bottom,
  });

  final TextEditingController ctrl;
  final ValueNotifier<bool> isNotEmpty;
  final bool isLoading;
  final VoidCallback onApply;
  final VoidCallback onSkip;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: DonySpacing.md),
        const Align(
          alignment: Alignment.centerRight,
          child: DonyStepPill(current: 4, total: 4, label: 'Parrainage'),
        ),
        // Zone haute scrollable : mascotte + textes se centrent ou scrollent
        // (clavier ouvert / gros text scale) ; le champ + boutons restent en bas.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DonyMascotteAnimated(type: DonyMascotteType.joyeux),
                    const SizedBox(height: DonySpacing.lg),
                    Text(
                      'Tu as été invité par un ami ?',
                      style: tt.headlineLarge?.copyWith(color: cs.onSurface),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      'Entre son code pour qu\'il soit récompensé à ta première livraison.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
        DonyTextField(
          controller: ctrl,
          label: 'Code parrain',
          hint: 'Ex : JEAN0234',
        ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
        const SizedBox(height: DonySpacing.xl),
        ValueListenableBuilder<bool>(
          valueListenable: isNotEmpty,
          builder: (context, hasText, _) => DonyButton(
            label: 'Appliquer le code',
            isLoading: isLoading,
            onPressed: hasText && !isLoading ? onApply : null,
          ),
        ),
        const SizedBox(height: DonySpacing.base),
        TextButton(
          onPressed: isLoading ? null : onSkip,
          child: Text(
            'Passer pour l\'instant',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        SizedBox(height: DonySpacing.xl + bottom),
      ],
    );
  }
}

// ── Success view ──────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const DonyMascotteAnimated(
                      type: DonyMascotteType.joyeux,
                      size: DonyMascotteSize.lg,
                      withGlow: true,
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.5, 0.5),
                    ),
                    const SizedBox(height: DonySpacing.lg),
                    Text(
                      'Code appliqué !',
                      style: tt.headlineLarge?.copyWith(
                        color: cs.success,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                    const SizedBox(height: DonySpacing.sm),
                    Text(
                      'Ton ami sera récompensé dès que tu complètes ta première livraison.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
        DonyButton(
          label: 'Continuer vers l\'accueil',
          onPressed: onContinue,
          variant: DonyButtonVariant.success,
        ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
        const SizedBox(height: DonySpacing.xl),
      ],
    );
  }
}
