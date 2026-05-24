import 'package:dony/core/storage/hive_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'accessibility_event.dart';
part 'accessibility_state.dart';

class AccessibilityBloc extends Bloc<AccessibilityEvent, AccessibilityState> {
  final Box _box;

  AccessibilityBloc(this._box)
      : super(AccessibilityState(
          textScale:
              _box.get(HiveService.kTextScale, defaultValue: 'normal') as String,
          highContrast:
              _box.get(HiveService.kHighContrast, defaultValue: false) as bool,
          reduceAnimations:
              _box.get(HiveService.kReduceAnimations, defaultValue: false)
                  as bool,
        )) {
    on<TextScaleChanged>((e, emit) {
      _box.put(HiveService.kTextScale, e.scale);
      emit(state.copyWith(textScale: e.scale));
    });
    on<HighContrastToggled>((e, emit) {
      final next = !state.highContrast;
      _box.put(HiveService.kHighContrast, next);
      emit(state.copyWith(highContrast: next));
    });
    on<ReduceAnimationsToggled>((e, emit) {
      final next = !state.reduceAnimations;
      _box.put(HiveService.kReduceAnimations, next);
      emit(state.copyWith(reduceAnimations: next));
    });
  }
}
