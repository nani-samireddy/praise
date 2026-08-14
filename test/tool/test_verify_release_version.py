import unittest

from tool.verify_release_version import verify


class VerifyReleaseVersionTest(unittest.TestCase):
    def test_accepts_matching_release(self) -> None:
        self.assertEqual(verify("v1.2.3", "version: 1.2.3+17\n"), ("1.2.3", 17))

    def test_rejects_version_mismatch(self) -> None:
        with self.assertRaisesRegex(ValueError, "does not match"):
            verify("v1.2.4", "version: 1.2.3+17\n")

    def test_rejects_prerelease_tag(self) -> None:
        with self.assertRaisesRegex(ValueError, "exact format"):
            verify("v1.2.3-rc.1", "version: 1.2.3+17\n")


if __name__ == "__main__":
    unittest.main()
