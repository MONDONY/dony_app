import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_signup_cubit.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_form.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_frequency_chips.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Case « Je suis GP » sous l'intention de l'inscription : cochée, elle
/// demande la fréquence (obligatoire) et le nom commercial (facultatif).
/// Aucun justificatif ici : il s'ajoute plus tard depuis le profil.
class GpProSignupSection extends StatefulWidget {
  const GpProSignupSection({super.key});

  @override
  State<GpProSignupSection> createState() => _GpProSignupSectionState();
}

class _GpProSignupSectionState extends State<GpProSignupSection> {
  // Repart de la saisie du cubit : la section disparaît quand l'intention
  // repasse sur « Expéditeur » puis revient.
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: context.read<GpProSignupCubit>().state.commercialName,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cubit = context.read<GpProSignupCubit>();
    return BlocBuilder<GpProSignupCubit, GpProSignupState>(
      buildWhen: (p, c) => p.checked != c.checked || p.frequency != c.frequency,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DonyCheckbox(
            key: const Key('gp-pro-signup-checkbox'),
            label: l.gpProSignupCheckbox,
            value: state.checked,
            onChanged: (v) => cubit.toggle(v ?? false),
          ),
          if (state.checked) ...[
            const SizedBox(height: DonySpacing.sm),
            Text(
              l.gpProFrequencyLabel,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: DonySpacing.sm),
            GpProFrequencyChips(
              selected: state.frequency,
              onChanged: cubit.selectFrequency,
            ),
            const SizedBox(height: DonySpacing.base),
            TextField(
              key: const Key('gp-pro-signup-name'),
              controller: _name,
              maxLength: GpProForm.maxCommercialName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: cubit.setCommercialName,
              decoration: InputDecoration(
                labelText: l.gpProCommercialNameLabel,
              ),
            ),
            Text(
              l.gpProSignupDocsHint,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
