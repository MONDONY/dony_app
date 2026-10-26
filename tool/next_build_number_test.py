import unittest

import next_build_number as n


class NextBuildNumberTest(unittest.TestCase):
    def test_der_to_raw_pads_and_strips(self):
        r = bytes([0x00, 0x80]) + bytes(31)       # entier signé, zéro de tête à retirer
        s = bytes([0x01]) + bytes(5)               # court, à compléter à 32 octets
        der = bytes([0x30, 2 + len(r) + 2 + len(s), 0x02, len(r)]) + r + bytes([0x02, len(s)]) + s
        raw = n.der_to_raw(der)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[:32], r[1:])
        self.assertEqual(raw[32:], bytes(26) + s)

    def test_der_to_raw_rejects_garbage(self):
        with self.assertRaises(ValueError):
            n.der_to_raw(b"\x31\x00")

    def test_max_int_ignores_non_numeric(self):
        self.assertEqual(n.max_int(["153", "1008", "1.0.0", None, 7]), 1008)
        self.assertEqual(n.max_int([]), 0)


if __name__ == "__main__":
    unittest.main()
