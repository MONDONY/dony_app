import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoleSelectionBottomSheet extends StatefulWidget {
  const RoleSelectionBottomSheet({
    super.key,
    this.canContinueNotifier,
    this.onSubmitReady,
  });

  final ValueNotifier<bool>? canContinueNotifier;
  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final canContinueNotifier = ValueNotifier<bool>(false);
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      isDismissible: false,
      title: 'Comment utiliser dony ?',
      subtitle: 'Vous pouvez cumuler les deux rôles',
      wrapper: (child) => BlocProvider.value(value: authBloc, child: child),
      stickyBottom: ValueListenableBuilder<bool>(
        valueListenable: canContinueNotifier,
        builder: (ctx, canContinue, _) => BlocBuilder<AuthBloc, AuthState>(
          builder: (ctx, state) {
            final isLoading = state is AuthLoading;
            return DonyButton(
              label: 'Créer mon compte',
              isLoading: isLoading,
              onPressed: (canContinue && !isLoading) ? () => submit?.call() : null,
            );
          },
        ),
      ),
      child: RoleSelectionBottomSheet(
        canContinueNotifier: canContinueNotifier,
        onSubmitReady: (fn) => submit = fn,
      ),
    ).whenComplete(canContinueNotifier.dispose);
  }

  @override
  State<RoleSelectionBottomSheet> createState() =>
      _RoleSelectionBottomSheetState();
}

class _RoleSelectionBottomSheetState extends State<RoleSelectionBottomSheet> {
  bool _isSender = false;
  bool _isTraveler = false;

  bool get _canContinue => _isSender || _isTraveler;

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_submit);
  }

  void _setRole({bool? sender, bool? traveler}) {
    setState(() {
      if (sender != null) _isSender = sender;
      if (traveler != null) _isTraveler = traveler;
    });
    widget.canContinueNotifier?.value = _canContinue;
  }

  void _submit() {
    if (!_canContinue) return;
    final roles = <String>[];
    if (_isSender) roles.add('SENDER');
    if (_isTraveler) roles.add('TRAVELER');
    context.read<AuthBloc>().add(AuthRegisterRequested(roles));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pop();
        } else if (state is AuthError) {
          DonySnackbar.show(context,
              message: state.message, type: DonySnackbarType.error);
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RoleCard(
              icon: Icons.inventory_2_rounded,
              title: 'Expéditeur',
              subtitle: "J'envoie des colis à ma famille en Afrique",
              selected: _isSender,
              cs: cs,
              tt: tt,
              onTap: () => _setRole(sender: !_isSender),
            ),
            const SizedBox(height: DonySpacing.base),
            _RoleCard(
              icon: Icons.flight_rounded,
              title: 'Voyageur',
              subtitle: 'Je voyage vers l\'Afrique et j\'ai de l\'espace',
              selected: _isTraveler,
              cs: cs,
              tt: tt,
              onTap: () => _setRole(traveler: !_isTraveler),
            ),
            const SizedBox(height: DonySpacing.xl),
          ],
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? cs.primary : cs.onSurfaceVariant, size: 24),
            const SizedBox(width: DonySpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(
                      color: selected ? cs.primary : cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xs),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 24)
                  .animate()
                  .scale(duration: 200.ms, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
