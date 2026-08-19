from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from tool.verify_android_artifacts import ABIS, LIBRARIES, verify


def create_archive(path: Path, prefix: str, missing: str | None = None) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        for abi in ABIS:
            for library in LIBRARIES:
                name = f"{prefix}{abi}/{library}"
                if name != missing:
                    archive.writestr(name, b"native-binary")


class VerifyAndroidArtifactsTest(unittest.TestCase):
    def test_accepts_complete_archives(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "app.apk"
            aab = root / "app.aab"
            create_archive(apk, "lib/")
            create_archive(aab, "base/lib/")

            verify(apk, aab)

    def test_rejects_missing_native_library(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "app.apk"
            aab = root / "app.aab"
            create_archive(apk, "lib/")
            missing = "base/lib/arm64-v8a/libapp.so"
            create_archive(aab, "base/lib/", missing=missing)

            with self.assertRaisesRegex(ValueError, "libapp.so"):
                verify(apk, aab)

    def test_rejects_invalid_archive(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "app.apk"
            aab = root / "app.aab"
            apk.write_text("not an APK", encoding="utf-8")
            create_archive(aab, "base/lib/")

            with self.assertRaisesRegex(ValueError, "valid ZIP"):
                verify(apk, aab)


if __name__ == "__main__":
    unittest.main()
