import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:dony/features/settings/presentation/widgets/pin_confirm_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DonyAppBar(title: context.l10n.devicesTitle),
      body: BlocBuilder<ConnectedDevicesBloc, ConnectedDevicesState>(
        builder: (context, state) {
          if (state is ConnectedDevicesLoading) {
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.lg,
                DonySpacing.huge,
              ),
              itemCount: 3,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: DonySpacing.md),
              itemBuilder: (_, _) => const DonyUserCardSkeleton(),
            );
          }
          if (state is ConnectedDevicesError) {
            return _ErrorView(
              failure: state.failure,
              onRetry: () => context.read<ConnectedDevicesBloc>().add(
                const DevicesLoadRequested(),
              ),
            );
          }
          if (state is ConnectedDevicesLoaded) {
            return _DeviceList(devices: state.devices);
          }
          if (state is DeviceRevoking) {
            return const Center(child: CircularProgressIndicator());
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices});

  final List<DeviceModel> devices;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final others = devices.where((d) => !d.isCurrent).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.lg,
        DonySpacing.huge,
      ),
      children: [
        Text(
          context.l10n.devicesSignedInCount(devices.length),
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        ...devices.asMap().entries.map(
          (entry) => _DeviceTile(device: entry.value)
              .animate()
              .fadeIn(delay: (entry.key * 60).ms)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.xl),
          DonyButton(
            label: context.l10n.devicesRevokeAllOthers,
            variant: DonyButtonVariant.destructive,
            onPressed: () => _confirmAndRevokeAll(context),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmAndRevokeAll(BuildContext context) async {
    final confirmed = await PinConfirmBottomSheet.show(
      context,
      authService: getIt<LocalAuthService>(),
    );
    if (confirmed == true && context.mounted) {
      context.read<ConnectedDevicesBloc>().add(
        const AllOthersRevokeRequested(),
      );
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final DeviceModel device;

  String get _platformIcon => switch (device.platform) {
    'ios' => '\u{1F34E}',
    'android' => '\u{1F916}',
    'web' => '\u{1F4BB}',
    _ => '\u{1F4F1}',
  };

  String _formatDate(BuildContext context, DateTime date) {
    final l = context.l10n;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 5) {
      return l.devicesActiveNow;
    }
    if (diff.inHours < 1) {
      return l.devicesAgoMinutes(diff.inMinutes);
    }
    if (diff.inDays < 1) {
      return l.devicesAgoHours(diff.inHours);
    }
    if (diff.inDays == 1) {
      return l.devicesAgoYesterday;
    }
    return l.devicesAgoDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: DonySpacing.sm),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: device.isCurrent
            ? cs.primaryContainer.withValues(alpha: 0.3)
            : cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(
          color: device.isCurrent
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Text(_platformIcon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.deviceName.isEmpty
                            ? context.l10n.devicesUnknown
                            : device.deviceName,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isCurrent) ...[
                      const SizedBox(width: DonySpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DonySpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(DonyRadius.xs),
                        ),
                        child: Text(
                          context.l10n.devicesThisDevice,
                          style: tt.labelSmall?.copyWith(color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  _formatDate(context, device.lastSeenAt),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => _confirmAndRevoke(context),
              child: Text(context.l10n.devicesRevoke),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRevoke(BuildContext context) async {
    final confirmed = await PinConfirmBottomSheet.show(
      context,
      authService: getIt<LocalAuthService>(),
    );
    if (confirmed == true && context.mounted) {
      context.read<ConnectedDevicesBloc>().add(
        DeviceRevokeRequested(device.deviceId),
      );
    }
  }
}

/// Texte affiché pour chaque catégorie d'échec du bloc : le bloc ne porte
/// qu'un code, cette extension de présentation choisit le texte traduit.
extension _DevicesFailureLabel on DevicesFailure {
  String label(AppLocalizations l) => switch (this) {
    DevicesFailure.load => l.devicesLoadError,
    DevicesFailure.revoke => l.devicesRevokeError,
    DevicesFailure.revokeAll => l.devicesRevokeAllError,
  };
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure, required this.onRetry});

  final DevicesFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DonySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon('wifi-off', size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.md),
            Text(
              failure.label(context.l10n),
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(label: context.l10n.commonRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
