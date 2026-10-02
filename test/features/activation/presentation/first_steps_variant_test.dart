import 'package:dony/features/activation/data/models/activation_status.dart';
import 'package:dony/features/activation/presentation/widgets/first_steps_personalized.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('variantes', () {
    expect(firstStepsVariant(const ActivationStatus()), 'unknown');
    expect(
      firstStepsVariant(
        const ActivationStatus(
          intent: UserIntent.sender,
          total: 2,
          kind: OpportunityKind.trips,
        ),
      ),
      'sender_full',
    );
    expect(
      firstStepsVariant(const ActivationStatus(intent: UserIntent.sender)),
      'sender_empty',
    );
    expect(
      firstStepsVariant(
        const ActivationStatus(
          intent: UserIntent.both,
          total: 1,
          kind: OpportunityKind.trips,
        ),
      ),
      'both_full',
    );
    expect(
      firstStepsVariant(const ActivationStatus(intent: UserIntent.both)),
      'both_empty',
    );
    expect(
      firstStepsVariant(
        const ActivationStatus(
          intent: UserIntent.traveler,
          total: 4,
          kind: OpportunityKind.packages,
        ),
      ),
      'traveler_full',
    );
    expect(
      firstStepsVariant(const ActivationStatus(intent: UserIntent.traveler)),
      'traveler_empty',
    );
  });
}
