import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/referral/bloc/referral_bloc.dart';
import 'package:dony/features/referral/bloc/referral_event.dart';
import 'package:dony/features/referral/bloc/referral_state.dart';
import 'package:dony/features/referral/data/models/referral_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReferralBloc>().add(const ReferralLoadRequested());
    });
  }

  Widget _buildBody(ReferralState state) {
    if (state is ReferralLoading || state is ReferralInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is ReferralError) {
      return _ErrorView(message: state.error.message);
    }
    if (state is ReferralLoaded) {
      return _LoadedBody(info: state.info);
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReferralBloc, ReferralState>(
      listener: (context, state) {
        // No specific listener actions needed — snackbar for copy is handled inline
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Parrainage',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            centerTitle: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          body: _buildBody(state),
          bottomNavigationBar: state is ReferralLoaded
              ? _ShareButton(info: state.info)
              : null,
        );
      },
    );
  }
}

// ─── Loaded body ─────────────────────────────────────────────────────────────

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.xl,
        DonySpacing.lg,
        100, // space for sticky bottom button
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero gradient card
          _HeroCard().animate().fadeIn(duration: 300.ms),

          const SizedBox(height: DonySpacing.xl),

          // Code box
          _CodeBox(code: info.code)
              .animate()
              .fadeIn(delay: 100.ms, duration: 300.ms),

          const SizedBox(height: DonySpacing.xl),

          // Stats row
          Row(
            children: [
              _StatBox(
                label: 'Invités',
                value: info.totalInvited.toString(),
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatBox(
                label: 'Inscrits',
                value: info.signedUp.toString(),
              ),
              const SizedBox(width: DonySpacing.sm),
              _StatBox(
                label: 'Récompensés',
                value: info.rewarded.toString(),
              ),
            ],
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          if (info.totalEarnedCents > 0) ...[
            const SizedBox(height: DonySpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: DonySpacing.base,
                horizontal: DonySpacing.base,
              ),
              decoration: BoxDecoration(
                color: cs.successLight,
                borderRadius: BorderRadius.circular(DonyRadius.card),
              ),
              child: Text(
                '💰 Tu as gagné ${(info.totalEarnedCents / 100).toStringAsFixed(0)} € grâce au parrainage',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
          ],
        ],
      ),
    );
  }
}

// ─── Hero card ───────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DonyColors.referralGreen, DonyColors.referralGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            'Invite et gagne 5 €',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Tu reçois 5 € de crédit dès la première livraison de ton invité.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Code box ────────────────────────────────────────────────────────────────

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    const green50 = DonyColors.referralGreen50;
    const greenAccent = DonyColors.referralGreenAccent;
    const greenDark = DonyColors.referralGreenDark;
    const greenPrimary = DonyColors.referralGreen;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.xl),
      decoration: BoxDecoration(
        color: green50,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Ton code de parrainage',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: DonySpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: greenDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(width: DonySpacing.md),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    DonySnackbar.show(
                      context,
                      message: 'Code copié !',
                      type: DonySnackbarType.success,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(DonySpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                    border: Border.all(color: greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: greenPrimary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat box ────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: DonySpacing.base,
          horizontal: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: DonySpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Share button (sticky bottom) ────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.info});
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.base,
        ),
        child: FilledButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: const Text('Partager mon code'),
          style: FilledButton.styleFrom(
            backgroundColor: DonyColors.referralGreen,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DonyRadius.lg),
            ),
          ),
          onPressed: () => Share.share(
            'Salut ! Utilise mon code dony : ${info.code} et reçois ton 1er envoi avec 5€ de réduction. ${info.shareUrl}',
          ),
        ),
      ),
    );
  }
}

// ─── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DonyMascotteAnimated(
              type: DonyMascotteType.assis,
              size: DonyMascotteSize.lg,
            ),
            const SizedBox(height: DonySpacing.base),
            Text(
              'Une erreur est survenue',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.xl),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: DonyColors.referralGreen,
              ),
              onPressed: () => context
                  .read<ReferralBloc>()
                  .add(const ReferralLoadRequested()),
            ),
          ],
        ),
      ),
    );
  }
}
