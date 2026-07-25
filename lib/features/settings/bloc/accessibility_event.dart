part of 'accessibility_bloc.dart';

abstract class AccessibilityEvent extends Equatable {
  const AccessibilityEvent();
  @override
  List<Object?> get props => [];
}

class FollowSystemTextScaleToggled extends AccessibilityEvent {
  const FollowSystemTextScaleToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class TextScaleFactorChanged extends AccessibilityEvent {
  const TextScaleFactorChanged(this.value);
  final double value;
  @override
  List<Object?> get props => [value];
}

class HighContrastModeChanged extends AccessibilityEvent {
  const HighContrastModeChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class ReduceMotionModeChanged extends AccessibilityEvent {
  const ReduceMotionModeChanged(this.value);
  final String value;
  @override
  List<Object?> get props => [value];
}

class BoldTextToggled extends AccessibilityEvent {
  const BoldTextToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class UnderlineLinksToggled extends AccessibilityEvent {
  const UnderlineLinksToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class ReinforceLabelsToggled extends AccessibilityEvent {
  const ReinforceLabelsToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class PersistentMessagesToggled extends AccessibilityEvent {
  const PersistentMessagesToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class ConfirmImportantActionsToggled extends AccessibilityEvent {
  const ConfirmImportantActionsToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}

class AccessibilityResetRequested extends AccessibilityEvent {
  const AccessibilityResetRequested();
}
