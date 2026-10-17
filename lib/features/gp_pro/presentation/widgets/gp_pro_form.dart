import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_cubit.dart';
import 'package:dony/features/gp_pro/bloc/gp_pro_state.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_frequency_chips.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_pieces_section.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Formulaire de demande GP Pro : fréquence (obligatoire), nom commercial et
/// justificatifs (facultatifs), phrase RGPD.
///
/// Le bouton d'envoi vit dans la barre fixe de l'écran : il reçoit la
/// soumission par [onSubmitReady], le contrôleur du nom restant dans ce
/// `State` (jamais d'appel à `setState`).
class GpProForm extends StatefulWidget {
  const GpProForm({required this.onSubmitReady, super.key});

  final ValueChanged<VoidCallback> onSubmitReady;

  /// Longueur maximale du nom commercial (contrat back).
  static const maxCommercialName = 80;

  @override
  State<GpProForm> createState() => _GpProFormState();
}

class _GpProFormState extends State<GpProForm> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<GpProCubit>();
    widget.onSubmitReady(() => cubit.submit(commercialName: _name.text));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.gpProFrequencyLabel,
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.sm),
        BlocBuilder<GpProCubit, GpProCubitState>(
          buildWhen: (p, c) => p.frequency != c.frequency,
          builder: (context, state) => GpProFrequencyChips(
            selected: state.frequency,
            onChanged: context.read<GpProCubit>().selectFrequency,
          ),
        ),
        const SizedBox(height: DonySpacing.lg),
        TextField(
          controller: _name,
          maxLength: GpProForm.maxCommercialName,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: l.gpProCommercialNameLabel),
        ),
        const SizedBox(height: DonySpacing.base),
        const GpProPiecesSection(),
      ],
    );
  }
}
