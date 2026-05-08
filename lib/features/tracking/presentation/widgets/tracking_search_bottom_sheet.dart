import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackingSearchBottomSheet extends StatefulWidget {
  const TrackingSearchBottomSheet({
    super.key,
    this.onSubmitReady,
  });

  final void Function(VoidCallback)? onSubmitReady;

  static Future<void> show(BuildContext context) {
    final trackingBloc = context.read<TrackingBloc>();
    VoidCallback? submit;
    return DonyBottomSheet.show(
      context,
      title: 'Rechercher un colis',
      subtitle: 'Format : DON-XXXXXX',
      wrapper: (child) => BlocProvider.value(value: trackingBloc, child: child),
      stickyBottom: BlocBuilder<TrackingBloc, TrackingState>(
        builder: (ctx, state) {
          final isLoading = state is TrackingSearchLoading;
          return DonyButton(
            label: 'Rechercher',
            icon: Icons.search_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : () => submit?.call(),
          );
        },
      ),
      child: TrackingSearchBottomSheet(
        onSubmitReady: (fn) => submit = fn,
      ),
    );
  }

  @override
  State<TrackingSearchBottomSheet> createState() => _TrackingSearchBottomSheetState();
}

class _TrackingSearchBottomSheetState extends State<TrackingSearchBottomSheet> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSubmitReady?.call(_search);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search() {
    final raw = _ctrl.text.trim().toUpperCase();
    if (raw.isEmpty) return;
    final normalized = raw.startsWith('DON-') ? raw : 'DON-$raw';
    context.read<TrackingBloc>().add(TrackingSearchRequested(normalized));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingSearchError) {
          DonySnackbar.show(
            context,
            message: state.message,
            type: DonySnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TrackingSearchLoading;
        return TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          enabled: !isLoading,
          decoration: InputDecoration(
            labelText: 'Numéro de suivi',
            hintText: 'DON-481234',
            prefixIcon: const Icon(Icons.qr_code_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              borderSide: BorderSide(color: cs.outline),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
          ),
        );
      },
    );
  }
}
