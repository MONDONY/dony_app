import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BusinessPrefsScreen extends StatelessWidget {
  const BusinessPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const DonyAppBar(title: 'Préférences'),
      body: BlocBuilder<BusinessPrefsBloc, BusinessPrefsState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg, DonySpacing.lg, DonySpacing.lg, DonySpacing.huge),
          children: [
            _SectionLabel('UNITÉS', cs: cs),
            DonyListSection(tiles: [
              DonyListTile(
                icon: Icons.monitor_weight_outlined,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Unité de poids',
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'lbs', label: Text('lbs')),
                  ],
                  selected: {state.weightUnit},
                  onSelectionChanged: (s) => context
                      .read<BusinessPrefsBloc>()
                      .add(WeightUnitChanged(s.first)),
                ),
              ),
            ]),
            const SizedBox(height: DonySpacing.lg),
            _SectionLabel('DEVISE', cs: cs),
            DonyListSection(tiles: [
              DonyListTile(
                icon: Icons.euro_rounded,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Devise d\'affichage',
                trailing: Text(
                  state.currencyCode,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                onTap: () => _showCurrencyPicker(context, state.currencyCode),
              ),
            ]),
            const SizedBox(height: DonySpacing.lg),
            _SectionLabel('GÉOLOCALISATION', cs: cs),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(DonyRadius.card),
                border: Border.all(color: cs.outline),
              ),
              padding: const EdgeInsets.all(DonySpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Rayon de pickup',
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${state.pickupRadiusKm} km',
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                  Slider(
                    value: state.pickupRadiusKm.toDouble(),
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: cs.primary,
                    onChanged: (v) => context
                        .read<BusinessPrefsBloc>()
                        .add(PickupRadiusChanged(v.round())),
                  ),
                ],
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, String current) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (code, label) in [
              ('EUR', 'Euro (€)'),
              ('XOF', 'Franc CFA Ouest (XOF)'),
              ('XAF', 'Franc CFA Centre (XAF)'),
            ])
              ListTile(
                title: Text(label),
                trailing: current == code ? const Icon(Icons.check) : null,
                onTap: () {
                  context
                      .read<BusinessPrefsBloc>()
                      .add(CurrencyChanged(code));
                  Navigator.pop(sheetCtx);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.cs});
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs, 0, DonySpacing.xs, DonySpacing.sm),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.2,
            )),
      );
}
