part of 'accessibility_bloc.dart';

abstract class AccessibilityEvent extends Equatable {
  const AccessibilityEvent();
  @override
  List<Object?> get props => [];
}

class TextScaleChanged extends AccessibilityEvent {
  final String scale;
  const TextScaleChanged(this.scale);
  @override
  List<Object?> get props => [scale];
}

class HighContrastToggled extends AccessibilityEvent {
  const HighContrastToggled();
}

class ReduceAnimationsToggled extends AccessibilityEvent {
  const ReduceAnimationsToggled();
}
