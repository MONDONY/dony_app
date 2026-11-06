import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/presentation/flight_format.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Couleurs primitives intentionnelles : l'en-tête de l'écran est sombre dans
// les deux thèmes, comme un hero.
const _night = DonyColors.ink900;
const _white = DonyColors.neutral0;

/// Ouvre l'écran de choix des villes (`/flights/city`) et rend le trajet
/// choisi, `null` si rien n'a changé.
Future<FlightRoutePick?> pickFlightRoute(
  BuildContext context,
  FlightRoutePickerArgs args,
) => context.push<FlightRoutePick>('/flights/city', extra: args);

/// « Où allez-vous ? » : écran plein, en-tête sombre avec les champs départ
/// et destination reliés, liste blanche qui monte dessous (ma position,
/// villes récentes, villes de la diaspora, puis résultats de la frappe).
///
/// Choisir une ville remplit le champ actif ; si l'autre champ est vide il
/// devient actif, sinon l'écran se ferme sur le trajet complet.
class FlightCityPickerScreen extends StatelessWidget {
  const FlightCityPickerScreen({super.key, required this.args});

  final FlightRoutePickerArgs args;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<FlightRoutePickerCubit>(param1: args),
        ),
        BlocProvider(
          create: (_) =>
              getIt<FlightPlacesCubit>()..focusField(departure: args.departure),
        ),
      ],
      child: const _PickerView(),
    );
  }
}

class _PickerView extends StatefulWidget {
  const _PickerView();

  @override
  State<_PickerView> createState() => _PickerViewState();
}

/// `State` pour le seul contrôleur de saisie et son focus (aucun setState).
class _PickerViewState extends State<_PickerView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close(BuildContext context) {
    final state = context.read<FlightRoutePickerCubit>().state;
    context.pop(state.changed ? state.pick : null);
  }

  Future<void> _locate(BuildContext context) async {
    final places = context.read<FlightPlacesCubit>();
    final picker = context.read<FlightRoutePickerCubit>();
    final place = await places.locate();
    if (!context.mounted) return;
    if (place == null) {
      DonySnackbar.show(
        context,
        message: context.l10n.flightsPickerLocationFailed,
        type: DonySnackbarType.warning,
      );
      return;
    }
    picker.choose(place);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<FlightRoutePickerCubit, FlightRoutePickerState>(
          listenWhen: (a, b) => b.done && !a.done,
          listener: (context, state) => context.pop(state.pick),
        ),
        BlocListener<FlightRoutePickerCubit, FlightRoutePickerState>(
          listenWhen: (a, b) =>
              !b.done && a.departureActive != b.departureActive,
          listener: (context, state) {
            _controller.clear();
            context.read<FlightPlacesCubit>()
              ..termChanged('')
              ..focusField(departure: state.departureActive);
            _focus.requestFocus();
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close(context);
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: FlightStatusBar.of(context),
          child: Scaffold(
            backgroundColor: _night,
            resizeToAvoidBottomInset: true,
            // En-tête Yadony standard ; la bande de nuit des champs suit.
            appBar: DonyAppBar(
              title: l.flightsPickerTitle,
              centerTitle: true,
              onBack: () => _close(context),
              bottom: const PreferredSize(
                preferredSize: Size.zero,
                child: SizedBox.shrink(),
              ),
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DonySpacing.lg,
                      DonySpacing.lg,
                      DonySpacing.lg,
                      DonySpacing.xxl,
                    ),
                    child: _Fields(controller: _controller, focus: _focus),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(DonyRadius.sheet),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _CityList(onLocate: () => _locate(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Les deux champs empilés, reliés par un pointillé vertical ; le champ
/// actif est blanc, bordé de bleu, et porte la saisie.
class _Fields extends StatelessWidget {
  const _Fields({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<FlightRoutePickerCubit, FlightRoutePickerState>(
      builder: (context, state) {
        final picker = context.read<FlightRoutePickerCubit>();
        Widget field({required bool departure}) {
          final place = departure ? state.origin : state.destination;
          return _Field(
            key: Key(
              departure ? 'flight-city-origin' : 'flight-city-destination',
            ),
            icon: departure ? 'plane' : 'map-pin',
            active: state.departureActive == departure,
            value: place == null
                ? null
                : place.name == place.code
                ? place.code
                : '${place.code} · ${FlightFormat.placeName(l, place)}',
            hint: departure
                ? l.flightsPickerOriginHint
                : l.flightsPickerDestinationHint,
            controller: controller,
            focus: focus,
            onTap: () => picker.activate(departure: departure),
          );
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                field(departure: true),
                const SizedBox(height: DonySpacing.sm),
                field(departure: false),
              ],
            ),
            // Pointillé qui relie l'icône du départ à celle de la
            // destination, à travers l'espace entre les deux champs.
            const PositionedDirectional(
              start: DonySpacing.md + DonySpacing.xxs + 8,
              top: 52 - 14,
              child: IgnorePointer(child: _Dots(height: 36)),
            ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(2, height), painter: _DotsPainter());
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _white.withValues(alpha: 0.35);
    for (var y = 1.0; y < size.height; y += 4) {
      canvas.drawCircle(Offset(size.width / 2, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.icon,
    required this.active,
    required this.value,
    required this.hint,
    required this.controller,
    required this.focus,
    required this.onTap,
  });

  final String icon;
  final bool active;
  final String? value;
  final String hint;
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = tt.bodyLarge?.copyWith(fontSize: 15);

    final Widget content = active
        ? TextField(
            key: const Key('flight-city-field'),
            controller: controller,
            focusNode: focus,
            textInputAction: TextInputAction.search,
            cursorColor: cs.primary,
            style: text?.copyWith(color: DonyColors.ink800),
            onChanged: context.read<FlightPlacesCubit>().termChanged,
            // Champ nu : le cadre blanc bordé de bleu est celui du conteneur.
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: value ?? hint,
              hintStyle: text?.copyWith(color: DonyColors.neutral500),
            ),
          )
        : Text(
            value ?? hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text?.copyWith(
              color: _white.withValues(alpha: value == null ? 0.6 : 1),
            ),
          );

    return Semantics(
      button: !active,
      textField: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : onTap,
        child: AnimatedContainer(
          duration: DonyDuration.base,
          curve: DonyCurve.easeOut,
          height: 52,
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md + DonySpacing.xxs,
          ),
          decoration: BoxDecoration(
            // Primitives intentionnelles : champ blanc sur l'en-tête sombre,
            // dans les deux thèmes.
            color: active ? _white : _white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(
              color: active ? DonyColors.blue500 : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              DonyIcon(
                icon,
                size: 18,
                color: active ? DonyColors.blue500 : _white,
              ),
              const SizedBox(width: DonySpacing.md + DonySpacing.xxs),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surface blanche : ma position, récents, diaspora, puis résultats.
class _CityList extends StatelessWidget {
  const _CityList({required this.onLocate});

  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final picker = context.watch<FlightRoutePickerCubit>().state;
    final choose = context.read<FlightRoutePickerCubit>().choose;
    final departure = picker.departureActive;
    // Ville déjà choisie dans l'autre champ : jamais proposée ici.
    final other = departure ? picker.destination : picker.origin;

    return BlocBuilder<FlightPlacesCubit, FlightPlacesState>(
      builder: (context, state) {
        final children = <Widget>[];
        if (state.status == FlightPlacesStatus.suggestions) {
          if (departure && state.canLocate) {
            children.add(_GeoRow(locating: state.locating, onTap: onLocate));
          }
          final recent = state.recent
              .where((p) => p.code != other?.code)
              .toList();
          if (recent.isNotEmpty) {
            children.add(
              _Caption(
                departure
                    ? l.flightsPickerRecentOrigins
                    : l.flightsPickerRecentDestinations,
                first: children.isEmpty,
              ),
            );
            for (final p in recent) {
              children.add(
                _CityRow(
                  key: Key('flight-city-recent-${p.code}'),
                  place: p,
                  onTap: () => choose(p),
                ),
              );
            }
          }
          final recentCodes = recent.map((p) => p.code).toSet();
          final diaspora = state.places
              .where((p) => p.code != other?.code)
              .where((p) => !recentCodes.contains(p.code))
              .toList();
          children.add(
            _Caption(
              departure ? l.flightsCitySuggestions : l.flightsPickerDiaspora,
              first: children.isEmpty,
            ),
          );
          for (final p in diaspora) {
            children.add(
              _CityRow(
                key: Key('flight-city-${p.code}'),
                place: p,
                onTap: () => choose(p),
              ),
            );
          }
        } else if (state.status == FlightPlacesStatus.error) {
          children.add(
            _Message(ErrorPresenter.resolve(state.error, l10n: l).message),
          );
        } else if (state.status == FlightPlacesStatus.loaded &&
            state.places.isEmpty) {
          children.add(_Message(l.flightsCityNoResult));
        } else {
          children.add(_Caption(l.flightsCityResults, first: true));
          if (state.status == FlightPlacesStatus.loading) {
            for (var i = 0; i < 3; i++) {
              children.add(const _CityRowSkeleton());
            }
          } else {
            for (final p in state.places) {
              children.add(
                _CityRow(
                  key: Key('flight-city-${p.code}'),
                  place: p,
                  onTap: () => choose(p),
                ),
              );
            }
          }
        }

        return ListView(
          key: const Key('flight-city-list'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            DonySpacing.base + DonySpacing.xxs,
            DonySpacing.lg,
            DonySpacing.base + DonySpacing.xxs,
            DonySpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        );
      },
    );
  }
}

class _GeoRow extends StatelessWidget {
  const _GeoRow({required this.locating, required this.onTap});

  final bool locating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('flight-city-locate'),
        onTap: locating ? null : onTap,
        borderRadius: BorderRadius.circular(DonyRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget),
          child: Row(
            children: [
              if (locating)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                DonyIcon('locate-fixed', size: 20, color: cs.primary),
              const SizedBox(width: DonySpacing.sm + DonySpacing.xxs),
              Text(
                context.l10n.flightsPickerUseLocation,
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : DonySpacing.lg,
        bottom: DonySpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: tt.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.base),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Ligne de ville : drapeau, ville en gras, pays en gris, code IATA encadré.
class _CityRow extends StatelessWidget {
  const _CityRow({super.key, required this.place, required this.onTap});

  final FlightPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final flag = FlightFormat.flag(place.countryCode);
    final country = FlightFormat.country(l, place);

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: flag == null
                    ? null
                    : Text(
                        flag,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, height: 1),
                      ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    if (country != null)
                      Text(
                        country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Container(
                constraints: const BoxConstraints(minWidth: 46),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.sm,
                  vertical: DonySpacing.xs + 1,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DonyRadius.sm),
                  border: Border.all(color: cs.outline, width: 1.2),
                ),
                child: Text(
                  place.code,
                  textAlign: TextAlign.center,
                  style: tt.headlineSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    height: 1.2,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityRowSkeleton extends StatelessWidget {
  const _CityRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const DonyShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: DonySpacing.md),
        child: Row(
          children: [
            DonySkeletonBox(width: 28, height: 20, radius: DonyRadius.xs),
            SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DonySkeletonBox(width: 120, height: 14),
                  SizedBox(height: DonySpacing.xs),
                  DonySkeletonBox(width: 80, height: 10),
                ],
              ),
            ),
            DonySkeletonBox(width: 46, height: 26),
          ],
        ),
      ),
    );
  }
}
