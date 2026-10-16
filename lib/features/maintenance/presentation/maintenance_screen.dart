import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/maintenance/bloc/maintenance_state.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Écran unique de l'application pendant la maintenance. Posé par
/// [MaintenanceGate] au-dessus de toute la navigation, sous `Localizations`
/// mais hors du `Navigator` : pas d'app bar, pas de retour, pas de scarabée.
/// Il se referme seul dès que l'administrateur rouvre l'application.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    required this.state,
    required this.onRetry,
    super.key,
  });

  final MaintenanceState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final cs = theme.colorScheme;
    final l = context.l10n;
    final message = state.message?.trim();
    final end = state.estimatedEndAt;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyMascotteAnimated(
                  type: DonyMascotteType.attente,
                  size: DonyMascotteSize.lg,
                ),
                const SizedBox(height: DonySpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    l.maintenanceTitle,
                    style: tt.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: DonySpacing.sm),
                Text(
                  message == null || message.isEmpty
                      ? l.maintenanceDefaultMessage
                      : message,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                if (end != null) ...[
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    l.maintenanceEstimatedEnd(
                      DateFormat.Hm(l.localeName).format(end.toLocal()),
                    ),
                    key: const Key('maintenance-estimated-end'),
                    style: tt.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: DonySpacing.xxl),
                DonyButton(
                  label: l.maintenanceRetry,
                  variant: DonyButtonVariant.secondary,
                  isLoading: state.checking,
                  onPressed: state.checking ? null : onRetry,
                ),
                const SizedBox(height: DonySpacing.md),
                Text(
                  l.maintenanceAutoReopen,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
