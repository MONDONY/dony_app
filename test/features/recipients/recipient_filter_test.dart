import 'package:dony/features/recipients/data/models/recipient.dart';
import 'package:dony/features/recipients/data/recipient_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const _ndeye = Recipient(
  id: 'r-1',
  fullName: 'Ndèye Fall',
  relationship: 'Mère',
  phoneE164: '+221771234567',
  city: 'Dakar',
  country: 'SN',
);

const _awa = Recipient(
  id: 'r-2',
  fullName: 'Awa Koné',
  relationship: 'Cousine',
  phoneE164: '+22507891234',
  city: 'Abidjan',
  country: 'CI',
);

const _moussa = Recipient(
  id: 'r-3',
  fullName: 'Moussa Traoré',
  phoneE164: '+22370001122',
  city: 'Bamako',
  country: 'ML',
);

const _all = [_ndeye, _awa, _moussa];

void main() {
  group('filterRecipients', () {
    test('returns all recipients when query is empty', () {
      expect(filterRecipients(_all, ''), _all);
    });

    test('returns all recipients when query is whitespace only', () {
      expect(filterRecipients(_all, '   '), _all);
    });

    test('matches on full name substring, case-insensitive', () {
      expect(filterRecipients(_all, 'awa'), [_awa]);
      expect(filterRecipients(_all, 'AWA'), [_awa]);
    });

    test('matches accented name with unaccented query (accent-folding)', () {
      expect(filterRecipients(_all, 'ndeye'), [_ndeye]);
    });

    test('matches accented query with accented name', () {
      expect(filterRecipients(_all, 'ndèye'), [_ndeye]);
    });

    test('matches on relationship, folding accents', () {
      expect(filterRecipients(_all, 'mère'), [_ndeye]);
      expect(filterRecipients(_all, 'mere'), [_ndeye]);
      expect(filterRecipients(_all, 'cousine'), [_awa]);
    });

    test('matches on city', () {
      expect(filterRecipients(_all, 'bamako'), [_moussa]);
    });

    test('matches on phone number', () {
      expect(filterRecipients(_all, '221771234567'), [_ndeye]);
    });

    test('returns empty list when nothing matches', () {
      expect(filterRecipients(_all, 'zzz-no-match'), isEmpty);
    });

    test('trims surrounding whitespace before matching', () {
      expect(filterRecipients(_all, '  awa  '), [_awa]);
    });
  });
}
