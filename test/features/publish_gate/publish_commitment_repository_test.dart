import 'package:dony/features/publish_gate/data/models/publish_commitments.dart';
import 'package:dony/features/publish_gate/data/repositories/publish_commitment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_dio.dart';

void main() {
  test('fetch lit les deux rôles et la version en vigueur', () async {
    final api = RecordingApi()
      ..on('GET', '/auth/me/publish-commitments', {
        'currentVersion': '2026-10',
        'traveler': {
          'acceptedVersion': '2026-10',
          'acceptedAt': '2026-10-13T10:00:00Z',
          'required': false,
        },
        'sender': {'required': true},
      });

    final c = await PublishCommitmentRepository(api.client).fetch();

    expect(c.currentVersion, '2026-10');
    expect(c.of(PublishCommitmentRole.traveler).required, isFalse);
    expect(c.traveler.acceptedVersion, '2026-10');
    expect(c.of(PublishCommitmentRole.sender).required, isTrue);
    expect(c, isNot(equals(null)));
  });

  test('statut absent ou illisible : acceptation requise', () {
    expect(PublishCommitmentStatus.fromJson(null).required, isTrue);
    expect(PublishCommitmentStatus.fromJson(const {}).required, isTrue);
  });

  test('accept envoie le rôle et la version', () async {
    final api = RecordingApi();

    await PublishCommitmentRepository(
      api.client,
    ).accept(PublishCommitmentRole.sender, '2026-10');

    expect(api.last.method, 'PUT');
    expect(api.last.path, '/auth/me/publish-commitments');
    expect(api.last.data, {'role': 'SENDER', 'version': '2026-10'});
  });
}
