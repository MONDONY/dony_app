import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:dony/features/settings/bloc/connected_devices_bloc.dart';
import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:dony/features/settings/presentation/widgets/pin_confirm_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Appareils connectés'),
      body: BlocBuilder<ConnectedDevicesBloc, ConnectedDevicesState>(
        builder: (context, state) {
          if (state is ConnectedDevicesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ConnectedDevicesError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<ConnectedDevicesBloc>()
                  .add(const DevicesLoadRequested()),
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
          'Tu es connecté sur ${devices.length} appareil(s)',
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
            label: 'Déconnecter tous les autres appareils',
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
      context
          .read<ConnectedDevicesBloc>()
          .add(const AllOthersRevokeRequested());
    }
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final DeviceModel device;

  String get _platformIcon => device.platform == 'ios' ? '\u{1F34E}' : '\u{1F916}';

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 5) {
      return 'Actif maintenant';
    }
    if (diff.inHours < 1) {
      return 'il y a ${diff.inMinutes} min';
    }
    if (diff.inDays < 1) {
      return 'il y a ${diff.inHours} h';
    }
    if (diff.inDays == 1) {
      return 'hier';
    }
    return 'il y a ${diff.inDays} jours';
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
                        device.deviceName,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                          'Cet appareil',
                          style:
                              tt.labelSmall?.copyWith(color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  _formatDate(device.lastSeenAt),
                  style:
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => _confirmAndRevoke(context),
              child: const Text('Révoquer'),
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
      context
          .read<ConnectedDevicesBloc>()
          .add(DeviceRevokeRequested(device.deviceId));
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
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
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: DonySpacing.md),
            Text(message, style: tt.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: DonySpacing.lg),
            DonyButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
