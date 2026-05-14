import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const List<String> _reasons = [
  'Vol annulé',
  'Urgence personnelle',
  'Problème de santé',
  'Changement d\'itinéraire',
  'Autre',
];

class CancellationScreen extends StatefulWidget {
  final String announcementId;
  const CancellationScreen({super.key, required this.announcementId});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_selectedReason == null) {
      return null;
    }
    if (_selectedReason == 'Autre' && _otherCtrl.text.trim().isNotEmpty) {
      return _otherCtrl.text.trim();
    }
    return _selectedReason;
  }

  void _confirm(BuildContext context) {
    final reason = _finalReason;
    if (reason == null) {
      DonySnackbar.show(
        context,
        message: 'Veuillez sélectionner une raison',
        type: DonySnackbarType.error,
      );
      return;
    }

    final bloc = context.read<CancellationBloc>();
    DonyDialog.show(
      context,
      title: 'Confirmer l\'annulation',
      message:
          'Cette action annulera votre trajet et remboursera automatiquement tous les expéditeurs concernés.',
      variant: DonyDialogVariant.destructive,
      icon: Icons.warning_amber_rounded,
    ).then((confirmed) {
      if (confirmed == true) {
        bloc.add(CancellationTripRequested(
          announcementId: widget.announcementId,
          reason: reason,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocListener<CancellationBloc, CancellationState>(
      listener: (context, state) {
        if (state is CancellationSuccess) {
          // Le voyageur revient sur sa liste "Mes trajets" après l'annulation.
          // L'écran "Alternatives disponibles" (RematchSearchScreen) est
          // destiné aux expéditeurs concernés et sera atteint via leur
          // notification FCM — pas par le voyageur lui-même.
          final n = state.cancellation.affectedBidsCount;
          DonySnackbar.show(
            context,
            message: n > 0
                ? 'Trajet annulé · $n expéditeur${n > 1 ? 's' : ''} '
                    'remboursé${n > 1 ? 's' : ''}'
                : 'Trajet annulé',
            type: DonySnackbarType.success,
          );
          context.go('/announcements');
        } else if (state is CancellationError) {
          ErrorPresenter.show(context, state.error);
        }
      },
      child: Scaffold(
        appBar: const DonyAppBar(title: 'Annuler le trajet'),
        body: Builder(builder: (context) {
          final h = DonyLayout.hPadding(context);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(h, DonySpacing.xl, h, 100),
            child: DonyLayout.constrained(
              context,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WarningBanner(cs: cs, tt: tt),
                  const SizedBox(height: DonySpacing.xl),
                  Text(
                    'Raison de l\'annulation',
                    style: tt.titleMedium?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: DonySpacing.md),
                  DonyRadioGroup<String>(
                    value: _selectedReason,
                    onChanged: (v) => setState(() => _selectedReason = v),
                    options: _reasons
                        .map((r) => DonyRadioOption(value: r, label: r))
                        .toList(),
                  ),
                  if (_selectedReason == 'Autre') ...[
                    const SizedBox(height: DonySpacing.md),
                    DonyTextField(
                      controller: _otherCtrl,
                      label: 'Précisez...',
                      hint: 'Décrivez votre raison',
                    ),
                  ],
                ],
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, curve: Curves.easeOutCubic),
            ),
          );
        }),
        bottomNavigationBar: _BottomBar(onConfirm: () => _confirm(context)),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  const _WarningBanner({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
              const SizedBox(width: DonySpacing.sm),
              Text(
                'Attention',
                style: tt.titleMedium?.copyWith(color: cs.error),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            'Cette annulation affectera tous les expéditeurs liés à ce trajet. Leurs remboursements seront traités automatiquement.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onConfirm;
  const _BottomBar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return Container(
          color: Theme.of(context).colorScheme.surface,
          padding: EdgeInsets.fromLTRB(
            DonySpacing.lg,
            DonySpacing.base,
            DonySpacing.lg,
            MediaQuery.of(context).padding.bottom + DonySpacing.base,
          ),
          child: DonyButton(
            label: 'Confirmer l\'annulation',
            onPressed: isLoading ? null : onConfirm,
            variant: DonyButtonVariant.destructive,
            isLoading: isLoading,
          ),
        );
      },
    );
  }
}
