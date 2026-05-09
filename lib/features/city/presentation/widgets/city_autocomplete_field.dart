import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class CityAutocompleteField extends StatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialValue,
    this.prefixIcon,
  });

  final String label;
  final void Function(CityModel city) onSelected;
  final String? initialValue;
  final Widget? prefixIcon;

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() => _showResults = _focusNode.hasFocus);
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
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
        BlocBuilder<CitySearchBloc, CitySearchState>(
          builder: (ctx, state) {
            if (state is CitySearchLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cities.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: cs.outline),
        itemBuilder: (ctx, i) {
          final city = cities[i];
          return ListTile(
            dense: true,
            leading: Icon(
              Icons.location_on_outlined,
              color: cs.primary,
              size: 20,
            ),
            title: Text(
              city.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            subtitle: Text(
              city.countryName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            onTap: () => onTap(city),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
        },
      ),
    );
  }
}
