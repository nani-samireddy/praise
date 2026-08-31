import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class BuildCatalogTest(unittest.TestCase):
    def test_auto_version_reuses_version_for_unchanged_content(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            source = workspace / "songs.csv"
            output = workspace / "catalog"
            id_map = workspace / "catalog_id_map.json"
            bundle = workspace / "songs.bundle.json"

            _write_csv(source, body="Body One")
            _run_build(source, output, id_map, bundle, "--version", "5")
            _run_build(source, output, id_map, bundle, "--auto-version")

            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(manifest["catalogVersion"], 5)

    def test_auto_version_increments_version_for_changed_content(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            source = workspace / "songs.csv"
            output = workspace / "catalog"
            id_map = workspace / "catalog_id_map.json"
            bundle = workspace / "songs.bundle.json"

            _write_csv(source, body="Body One")
            _run_build(source, output, id_map, bundle, "--version", "5")
            _write_csv(source, body="Body Two")
            _run_build(source, output, id_map, bundle, "--auto-version")

            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(manifest["catalogVersion"], 6)


def _write_csv(path: Path, *, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "ID",
                "TELUGU TITLE",
                "TELUGU SONG",
                "ENGLISH TITLE",
                "ENGLISH SONG",
            ],
        )
        writer.writeheader()
        writer.writerow(
            {
                "ID": "song-1",
                "TELUGU TITLE": "Title One",
                "TELUGU SONG": body,
                "ENGLISH TITLE": "",
                "ENGLISH SONG": "",
            }
        )


def _run_build(
    source: Path,
    output: Path,
    id_map: Path,
    bundle: Path,
    *version_args: str,
) -> None:
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "tool" / "build_catalog.py"),
            "--input",
            str(source),
            "--output",
            str(output),
            "--id-map",
            str(id_map),
            "--bundle-output",
            str(bundle),
            *version_args,
        ],
        check=True,
        cwd=ROOT,
    )


if __name__ == "__main__":
    unittest.main()
