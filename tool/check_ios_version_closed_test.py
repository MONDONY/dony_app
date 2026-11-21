import unittest

import check_ios_version_closed as c


def v(state, key="appStoreState"):
    return {"attributes": {key: state}}


class CheckIosVersionClosedTest(unittest.TestCase):
    def test_pubspec_version_sans_numero_de_build(self):
        self.assertEqual(c.pubspec_version("name: x\nversion: 1.0.10+87\n"), "1.0.10")

    def test_pubspec_sans_version(self):
        with self.assertRaises(ValueError):
            c.pubspec_version("name: x\n")

    def test_version_en_review_ou_approuvee_est_fermee(self):
        for s in ("WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "READY_FOR_SALE"):
            self.assertEqual(c.closed_state([v(s)]), s)

    def test_nouvel_etat_appVersionState_reconnu(self):
        self.assertEqual(c.closed_state([v("WAITING_FOR_REVIEW", "appVersionState")]), "WAITING_FOR_REVIEW")

    def test_version_en_preparation_ou_rejetee_reste_ouverte(self):
        for s in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"):
            self.assertIsNone(c.closed_state([v(s)]))

    def test_aucune_version_apple_reste_ouverte(self):
        self.assertIsNone(c.closed_state([]))

    def test_une_ancienne_version_fermee_parmi_d_autres_suffit(self):
        self.assertEqual(c.closed_state([v("PREPARE_FOR_SUBMISSION"), v("READY_FOR_SALE")]), "READY_FOR_SALE")


if __name__ == "__main__":
    unittest.main()
