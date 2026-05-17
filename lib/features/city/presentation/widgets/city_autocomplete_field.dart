import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Champ de saisie avec autocomplétion de ville.
///
/// Les suggestions sont rendues **dans le flux scrollable** (Column enfant),
/// jamais via Overlay/OverlayEntry. Elles poussent le contenu vers le bas
/// et ne sont donc jamais masquées par un bouton sticky.
///
/// [fieldKey] est transmis au [TextField] interne — indispensable pour les
/// tests (finders stables) et pour distinguer départ vs arrivée.
class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialValue,
    this.prefixIcon,
    this.fieldKey,
    this.requiredLabel = false,
  });

  final String label;
  final void Function(CityModel city) onSelected;
  final String? initialValue;
  final Widget? prefixIcon;

  /// Key stable transmise au [TextField] interne.
  final Key? fieldKey;

  /// Si true, affiche un astérisque rouge (`cs.error`) après le label
  /// via `InputDecoration.label` (RichText) — même rendu que [DonyTextField.requiredLabel].
  final bool requiredLabel;

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _ensureVisibleTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
    if (_focusNode.hasFocus) {
      // Après le frame suivant, le clavier est en cours d'ouverture et le champ
      // peut être partiellement masqué — on le ramène dans la zone visible.
      // Un Timer annulable est utilisé pour attendre que les viewInsets du
      // clavier Android soient complètement stabilisés (≈ 300 ms) avant de
      // scroller — évite un scroll à la mauvaise position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureVisibleTimer?.cancel();
        _ensureVisibleTimer = Timer(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          Scrollable.maybeOf(context)?.position.ensureVisible(
            context.findRenderObject()!,
            alignment: 0.1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _ensureVisibleTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCitySelected(CityModel city) {
    _controller.text = city.name;
    _focusNode.unfocus();
    context.read<CitySearchBloc>().add(const CitySearchCleared());
    widget.onSelected(city);
  }

  /// Construit le widget label (avec astérisque rouge si [requiredLabel]).
  ///
  /// Délègue à [buildRequiredLabel] (design system partagé).
  Widget? _buildLabel(BuildContext context) =>
      buildRequiredLabel(context, widget.label, isRequired: widget.requiredLabel);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelWidget = _buildLabel(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Champ texte — dans un conteneur card (remplace CaFieldCard) ───
        ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: Container(
            color: cs.surface,
            child: TextField(
              key: widget.fieldKey,
              controller: _controller,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontSize: 15,
                color: cs.onSurface,
              ),
              decoration: InputDecoration(
                // Si requiredLabel, label widget (RichText) ; sinon labelText.
                label: labelWidget,
                labelText: labelWidget == null ? widget.label : null,
                prefixIcon: widget.prefixIcon,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          context
                              .read<CitySearchBloc>()
                              .add(const CitySearchCleared());
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
                context
                    .read<CitySearchBloc>()
                    .add(CitySearchQueryChanged(value));
              },
            ),
          ),
        ),
        // ── Suggestions — dans le flux scrollable (jamais en Overlay) ─────
        // Les suggestions poussent le contenu vers le bas : pas de masquage
        // par le bouton sticky "Continuer".
        BlocBuilder<CitySearchBloc, CitySearchState>(
          builder: (ctx, state) {
            if (state is CitySearchLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
                child: LinearProgressIndicator(
                  color: cs.primary,
                ),
              );
            }
            if (state is CitySearchLoaded && state.cities.isNotEmpty) {
              return _ResultList(
                cities: state.cities,
                onTap: _onCitySelected,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.cities, required this.onTap});

  final List<CityModel> cities;
  final void Function(CityModel) onTap;

  /// Hauteur max visible : ~4 suggestions. Au-delà la liste scrolle en interne.
  static const double _maxHeight = 224.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ConstrainedBox borne la hauteur à ~4 items — au-delà la liste scrolle.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: cities.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: cs.outline),
          itemBuilder: (ctx, i) {
            final city = cities[i];
            return ListTile(
              dense: true,
              leading: Icon(
                DonyIcons.mapPin,
                color: cs.primary,
                size: 20,
              ),
              title: Text(
                city.name,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                city.countryName,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              onTap: () => onTap(city),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
          },
        ),
      ),
    );
  }
}
