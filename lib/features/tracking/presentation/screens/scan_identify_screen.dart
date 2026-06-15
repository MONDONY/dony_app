import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _etapeLabels = <String, (String, String?, String?)>{
  'DEPART': ('Départ', null, 'plane-takeoff'),
  'TRANSIT': ('Transit', 'arrow-left-right', null),
  'ARRIVEE': ('Arrivée', null, 'plane-landing'),
};

class ScanIdentifyScreen extends StatefulWidget {
  const ScanIdentifyScreen({
    super.key,
    this.etape,
    this.focusNumber = false,
  });

  final String? etape;
  final bool focusNumber;

  @override
  State<ScanIdentifyScreen> createState() => _ScanIdentifyScreenState();
}

class _ScanIdentifyScreenState extends State<ScanIdentifyScreen> {
  late final TextEditingController _numberCtrl;
  late final FocusNode _numberFocus;
  final ValueNotifier<bool> _hasInput = ValueNotifier(false);
  String? _selectedEtape;

  @override
  void initState() {
    super.initState();
    _selectedEtape = widget.etape;
    _numberCtrl = TextEditingController();
    _numberFocus = FocusNode();
    _numberCtrl.addListener(() {
      _hasInput.value = _numberCtrl.text.trim().isNotEmpty;
    });
    if (widget.focusNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _numberFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _numberFocus.dispose();
    _hasInput.dispose();
    super.dispose();
  }

  Future<void> _openQrPicker() async {
    final bidId = await context.push<String?>('/tracking/scan/qr-picker');
    if (!mounted || bidId == null) return;

    String? etape = _selectedEtape;
    if (etape == null) {
      etape = await _showEtapePicker();
      if (!mounted || etape == null) return;
      _selectedEtape = etape;
    }

    if (!mounted) return;
    await context.push<void>(
      '/tracking/scan/photo',
      extra: <String, dynamic>{
        'bidId': bidId,
        'etape': etape,
        'packageLabel': bidId.substring(0, 8),
      },
    );
  }

  Future<String?> _showEtapePicker() {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EtapePickerSheet(),
    );
  }

  Future<void> _handleSearchLoaded(TrackingSearchLoaded state) async {
    String? etape = _selectedEtape;
    if (etape == null) {
      etape = await _showEtapePicker();
      if (!mounted || etape == null) return;
      _selectedEtape = etape;
    }
    if (!mounted) return;
    await context.push<void>(
      '/tracking/scan/photo',
      extra: <String, dynamic>{
        'bidId': state.result.bidId,
        'etape': etape,
        'packageLabel': state.result.trackingNumber,
      },
    );
  }

  void _submitNumber() {
    final number = _numberCtrl.text.trim().toUpperCase();
    if (number.isEmpty) return;
    context.read<TrackingBloc>().add(TrackingSearchRequested(number));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final etapeLabel = _selectedEtape != null ? _etapeLabels[_selectedEtape!] : null;

    return BlocConsumer<TrackingBloc, TrackingState>(
      listener: (context, state) {
        if (state is TrackingSearchLoaded) {
          _handleSearchLoaded(state);
        }
      },
      builder: (context, state) {
        final isLoading = state is TrackingSearchLoading;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            title: Text('Identifier le colis', style: tt.headlineLarge),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: cs.outline),
            ),
            actions: [
              if (etapeLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: DonySpacing.base),
                  child: Chip(
                    avatar: switch (etapeLabel.$3) {
                      'plane-takeoff' => const DonyEmoji.planeTakeoff(size: 14),
                      'plane-landing' => const DonyEmoji.planeLanding(size: 14),
                      _ => DonyIcon(etapeLabel.$2!, size: 14, color: cs.primary),
                    },
                    label: Text(etapeLabel.$1),
                    labelStyle: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: cs.primaryContainer,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.xs,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // QR scanner button
                GestureDetector(
                  onTap: isLoading ? null : _openQrPicker,
                  child: Container(
                    padding: const EdgeInsets.all(DonySpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(DonyRadius.card),
                    ),
                    child: Column(
                      children: [
                        DonyIcon('scan-line',
                            size: 36, color: cs.onPrimary),
                        const SizedBox(height: DonySpacing.sm),
                        Text(
                          'Ouvrir le scanner QR',
                          style: tt.titleMedium?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        Text(
                          'Pointez vers le QR du colis',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: DonySpacing.base),

                // OU divider
                Row(children: [
                  Expanded(child: Divider(color: cs.outline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.sm,
                    ),
                    child: Text(
                      'OU',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: cs.outline)),
                ]),

                const SizedBox(height: DonySpacing.base),

                // Number field
                TextField(
                  controller: _numberCtrl,
                  focusNode: _numberFocus,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.characters,
                  keyboardType: TextInputType.visiblePassword,
                  style: tt.titleLarge?.copyWith(letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: 'DON-XXXXXX',
                    hintStyle: tt.titleLarge?.copyWith(
                      letterSpacing: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                    prefixIcon: const DonyEmoji.parcel(size: 24),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                      borderSide: BorderSide(color: cs.primary, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: DonySpacing.xl),

                // Submit button
                ValueListenableBuilder<bool>(
                  valueListenable: _hasInput,
                  builder: (context, hasInput, _) => ElevatedButton(
                    onPressed: (hasInput && !isLoading) ? _submitNumber : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      disabledBackgroundColor: cs.surfaceContainerHighest,
                      disabledForegroundColor: cs.onSurfaceVariant,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: DonySpacing.base,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DonyRadius.lg),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : Text('Identifier →', style: tt.labelLarge),
                  ),
                ),

                if (state is TrackingSearchError) ...[
                  const SizedBox(height: DonySpacing.md),
                  Text(
                    'Numéro introuvable. Vérifiez et réessayez.',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EtapePickerSheet extends StatelessWidget {
  const _EtapePickerSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DonyRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        MediaQuery.of(context).padding.bottom + DonySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
            ),
          ),
          Text('Quelle étape ?', style: tt.headlineMedium),
          const SizedBox(height: DonySpacing.base),
          for (final entry in _etapeLabels.entries)
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: switch (entry.value.$3) {
                  'plane-takeoff' => const DonyEmoji.planeTakeoff(size: 24),
                  'plane-landing' => const DonyEmoji.planeLanding(size: 24),
                  _ => DonyIcon(entry.value.$2!, color: cs.primary),
                },
                title: Text(
                  entry.value.$1,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                onTap: () => context.pop(entry.key),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
