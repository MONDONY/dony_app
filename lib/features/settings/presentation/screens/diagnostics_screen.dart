import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/settings/bloc/diagnostics_bloc.dart';
import 'package:dony/features/settings/presentation/widgets/settings_flat_group.dart';
import 'package:dony/features/settings/presentation/widgets/settings_section_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DiagnosticsBloc>().add(const DiagnosticsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Diagnostics'),
      body: BlocBuilder<DiagnosticsBloc, DiagnosticsState>(
        builder: (context, state) =>
            ListView(
                  padding: const EdgeInsets.fromLTRB(
                    DonySpacing.lg,
                    DonySpacing.xl,
                    DonySpacing.lg,
                    DonySpacing.huge,
                  ),
                  children: [
                    // APPLICATION
                    const SettingsSectionHeader('APPLICATION'),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'info',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: 'Version',
                          trailing: Text(
                            state.appVersion != null
                                ? 'v${state.appVersion} (${state.buildNumber})'
                                : '-',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xl),

                    // CONNECTIVITE
                    const SettingsSectionHeader('CONNECTIVITÉ'),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'wifi',
                          iconColor: _pingIconColor(state, cs),
                          iconBgColor: _pingIconBg(state, cs),
                          label: 'Statut API',
                          trailing: state.isPinging
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                )
                              : Text(
                                  _pingLabel(state),
                                  style: tt.labelMedium?.copyWith(
                                    color: _pingTextColor(state, cs),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          showDivider: false,
                          onTap: state.isPinging
                              ? null
                              : () => context.read<DiagnosticsBloc>().add(
                                  const ApiPingRequested(),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DonySpacing.xl),

                    // SUPPORT
                    const SettingsSectionHeader('SUPPORT'),
                    SettingsFlatGroup(
                      children: [
                        DonyListTile(
                          iconAsset: 'bug',
                          iconColor: cs.primary,
                          iconBgColor: cs.primaryContainer,
                          label: 'Signaler un bug',
                          onTap: () => context.push(
                            '/settings/report-incident',
                            extra: {'targetType': IncidentTargetType.app},
                          ),
                        ),
                        DonyListTile(
                          iconAsset: 'copy',
                          iconColor: cs.onSurfaceVariant,
                          iconBgColor: cs.surfaceContainerHighest,
                          label: 'Copier mon ID utilisateur',
                          subtitle: 'Utile pour le support',
                          showDivider: false,
                          onTap: () => _copyUserId(context),
                        ),
                      ],
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
      ),
    );
  }

  // Helpers couleur ping

  Color _pingIconColor(DiagnosticsState state, ColorScheme cs) =>
      switch (state.apiOk) {
        true => cs.success,
        false => cs.error,
        null => cs.onSurfaceVariant,
      };

  Color _pingIconBg(DiagnosticsState state, ColorScheme cs) =>
      switch (state.apiOk) {
        true => cs.successLight,
        false => cs.errorContainer,
        null => cs.surfaceContainerHighest,
      };

  Color _pingTextColor(DiagnosticsState state, ColorScheme cs) =>
      switch (state.apiOk) {
        true => cs.success,
        false => cs.error,
        null => cs.onSurfaceVariant,
      };

  String _pingLabel(DiagnosticsState state) => switch (state.apiOk) {
    true => 'En ligne',
    false => 'Hors ligne',
    null => 'Tester',
  };

  // Actions

  Future<void> _copyUserId(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await Clipboard.setData(ClipboardData(text: uid));
    if (!context.mounted) {
      return;
    }
    DonySnackbar.show(
      context,
      message: 'ID copie dans le presse-papier',
      type: DonySnackbarType.success,
    );
  }
}
