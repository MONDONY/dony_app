part of 'accessibility_bloc.dart';

class AccessibilityState extends Equatable {
  final String textScale;
  final bool highContrast;
  final bool reduceAnimations;

  const AccessibilityState({
    this.textScale = 'normal',
    this.highContrast = false,
    this.reduceAnimations = false,
  });

  AccessibilityState copyWith({
    String? textScale,
    bool? highContrast,
    bool? reduceAnimations,
  }) =>
      AccessibilityState(
        textScale: textScale ?? this.textScale,
        highContrast: highContrast ?? this.highContrast,
        reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      );

  @override
  List<Object?> get props => [textScale, highContrast, reduceAnimations];
}
