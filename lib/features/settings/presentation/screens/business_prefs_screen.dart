import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BusinessPrefsScreen extends StatefulWidget {
  const BusinessPrefsScreen({super.key});

  @override
  State<BusinessPrefsScreen> createState() => _BusinessPrefsScreenState();
}

class _BusinessPrefsScreenState extends State<BusinessPrefsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BusinessPrefsBloc>().add(const BusinessPrefsSyncRequested());
  }

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
            if (state.errorMessage != null) ...[
              _ErrorBanner(message: state.errorMessage!),
              const SizedBox(height: DonySpacing.lg),
            ],
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
            const SizedBox(height: DonySpacing.lg),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                if (authState is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }
                if (!authState.user.isTraveler) {
                  return const SizedBox.shrink();
                }
                return _TravelerSection(state: state);
              },
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
    DonyBottomSheet.show(
      context,
      title: 'Devise d\'affichage',
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
              trailing: current == code
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                context.read<BusinessPrefsBloc>().add(CurrencyChanged(code));
                context.pop();
              },
            ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(DonyRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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

// ── Traveler section ──────────────────────────────────────────────────────────

class _TravelerSection extends StatefulWidget {
  const _TravelerSection({required this.state});

  final BusinessPrefsState state;

  @override
  State<_TravelerSection> createState() => _TravelerSectionState();
}

class _TravelerSectionState extends State<_TravelerSection> {
  late final TextEditingController _delayController;

  @override
  void initState() {
    super.initState();
    _delayController = TextEditingController(
      text: widget.state.responseDelayHours != null
          ? '${widget.state.responseDelayHours}'
          : '',
    );
  }

  @override
  void didUpdateWidget(_TravelerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newHours = widget.state.responseDelayHours;
    final oldHours = oldWidget.state.responseDelayHours;
    if (newHours != oldHours) {
      final newText = newHours != null ? '$newHours' : '';
      if (_delayController.text != newText) {
        _delayController.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = widget.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with badge
        Padding(
          padding: const EdgeInsets.fromLTRB(
              DonySpacing.xs, 0, DonySpacing.xs, DonySpacing.sm),
          child: Row(
            children: [
              Text(
                'MES TRAJETS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(DonyRadius.full),
                ),
                child: Text(
                  'Voyageur',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card container
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Poids par défaut ──────────────────────────────────────────
              DonyListTile(
                icon: Icons.inventory_2_outlined,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Poids par défaut',
                subtitle: 'Pré-remplit vos annonces',
                trailing: Text(
                  '${state.defaultPackageWeightKg} kg',
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                showDivider: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
                child: Slider(
                  value: state.defaultPackageWeightKg.toDouble(),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: cs.primary,
                  onChanged: (v) => context
                      .read<BusinessPrefsBloc>()
                      .add(DefaultWeightChanged(v.round())),
                ),
              ),
              Divider(height: 1, color: cs.outline),

              // ── Prix minimum ──────────────────────────────────────────────
              DonyListTile(
                icon: Icons.euro_outlined,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Prix minimum',
                subtitle: '0 € = aucun filtre',
                trailing: Text(
                  state.minBidPriceEur == 0
                      ? 'Aucun'
                      : '${state.minBidPriceEur} €',
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                showDivider: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base, 0, DonySpacing.base, DonySpacing.sm),
                child: Slider(
                  value: state.minBidPriceEur.toDouble(),
                  max: 50,
                  divisions: 50,
                  activeColor: cs.primary,
                  onChanged: (v) => context
                      .read<BusinessPrefsBloc>()
                      .add(MinBidPriceChanged(v.round())),
                ),
              ),
              Divider(height: 1, color: cs.outline),

              // ── Mode de contact ───────────────────────────────────────────
              DonyListTile(
                icon: Icons.phone_outlined,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Mode de contact',
                showDivider: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base, 0, DonySpacing.base, DonySpacing.base),
                child: SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'call', label: Text('Appel')),
                    ButtonSegment(value: 'message', label: Text('Message')),
                    ButtonSegment(value: 'both', label: Text('Les deux')),
                  ],
                  selected: state.contactMode != null
                      ? {state.contactMode!}
                      : const <String>{},
                  onSelectionChanged: (s) => context
                      .read<BusinessPrefsBloc>()
                      .add(ContactModeChanged(s.isEmpty ? null : s.first)),
                ),
              ),
              Divider(height: 1, color: cs.outline),

              // ── Délai de réponse ──────────────────────────────────────────
              DonyListTile(
                icon: Icons.timer_outlined,
                iconColor: cs.primary,
                iconBgColor: cs.primaryContainer,
                label: 'Délai de réponse',
                showDivider: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DonySpacing.base, 0, DonySpacing.base, DonySpacing.base),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: DonySpacing.xs,
                        runSpacing: DonySpacing.xs,
                        children: [
                          for (final h in [1, 2, 6, 24])
                            ChoiceChip(
                              label: Text('${h}h'),
                              selected: state.responseDelayHours == h,
                              onSelected: (selected) {
                                context.read<BusinessPrefsBloc>().add(
                                      ResponseDelayChanged(selected ? h : null),
                                    );
                                if (selected) {
                                  _delayController.text = '$h';
                                } else {
                                  _delayController.clear();
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        controller: _delayController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'ex. 3',
                          suffixText: 'h',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: DonySpacing.sm,
                            vertical: DonySpacing.sm,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(DonyRadius.md),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isEmpty) {
                            context
                                .read<BusinessPrefsBloc>()
                                .add(const ResponseDelayChanged(null));
                          } else {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed >= 1) {
                              context
                                  .read<BusinessPrefsBloc>()
                                  .add(ResponseDelayChanged(parsed));
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 280.ms, curve: Curves.easeOutCubic);
  }
}
