import unittest

from tool.verify_release_version import verify


class VerifyReleaseVersionTest(unittest.TestCase):
    def test_accepts_matching_release(self) -> None:
        self.assertEqual(verify("app-v1.2.3", "version: 1.2.3+17\n"), ("1.2.3", 17))

    def test_accepts_matching_internal_release(self) -> None:
        self.assertEqual(
            verify("app-v1.2.3-internal.1", "version: 1.2.3-internal.1+17\n"),
            ("1.2.3-internal.1", 17),
        )

    def test_accepts_matching_beta_release(self) -> None:
        self.assertEqual(
            verify("app-v1.2.3-beta.2", "version: 1.2.3-beta.2+18\n"),
            ("1.2.3-beta.2", 18),
        )

    def test_rejects_version_mismatch(self) -> None:
        with self.assertRaisesRegex(ValueError, "does not match"):
            verify("app-v1.2.4", "version: 1.2.3+17\n")

    def test_rejects_unsupported_prerelease_tag(self) -> None:
        with self.assertRaisesRegex(ValueError, "internal.N"):
            verify("app-v1.2.3-candidate.1", "version: 1.2.3-candidate.1+17\n")


if __name__ == "__main__":
    unittest.main()
