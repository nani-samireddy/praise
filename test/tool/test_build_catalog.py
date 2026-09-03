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
            self.assertEqual(manifest["deltaFromVersion"], 5)
            self.assertEqual(manifest["deltaUrl"], "delta-v5-v6.json")

            delta = json.loads((output / manifest["deltaUrl"]).read_text())
            self.assertEqual(delta["fromVersion"], 5)
            self.assertEqual(delta["toVersion"], 6)
            self.assertEqual(delta["deletes"], [])
            self.assertEqual(
                delta["upserts"],
                [
                    {
                        "id": "csv-0001",
                        "title": "Title One",
                        "englishTitle": None,
                        "body": "Body Two",
                        "englishBody": None,
                        "author": None,
                    }
                ],
            )

    def test_delta_records_deleted_songs(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            source = workspace / "songs.csv"
            output = workspace / "catalog"
            id_map = workspace / "catalog_id_map.json"
            bundle = workspace / "songs.bundle.json"

            _write_csv(source, body="Body One", second_song=True)
            _run_build(source, output, id_map, bundle, "--version", "5")
            _write_csv(source, body="Body One", second_song=False)
            _run_build(source, output, id_map, bundle, "--auto-version")

            manifest = json.loads((output / "manifest.json").read_text())
            delta = json.loads((output / manifest["deltaUrl"]).read_text())
            self.assertEqual(delta["upserts"], [])
            self.assertEqual(delta["deletes"], ["csv-0002"])

    def test_prefers_structured_lyrics_over_original_lyrics(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            source = workspace / "songs.csv"
            output = workspace / "catalog"
            id_map = workspace / "catalog_id_map.json"
            bundle = workspace / "songs.bundle.json"
            structured_body = "[Repeat x2]\\nLine\\n[/Repeat]"
            with source.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(
                    handle,
                    fieldnames=[
                        "ID",
                        "TELUGU TITLE",
                        "TELUGU ORIGINAL SONG",
                        "TELUGU STRUCTURED SONG",
                        "ENGLISH TITLE",
                        "ENGLISH ORIGINAL SONG",
                        "ENGLISH STRUCTURED SONG",
                    ],
                )
                writer.writeheader()
                writer.writerow(
                    {
                        "ID": "song-1",
                        "TELUGU TITLE": "Title One",
                        "TELUGU ORIGINAL SONG": "Original",
                        "TELUGU STRUCTURED SONG": structured_body,
                        "ENGLISH TITLE": "",
                        "ENGLISH ORIGINAL SONG": "",
                        "ENGLISH STRUCTURED SONG": "",
                    }
                )
            _run_build(source, output, id_map, bundle, "--version", "5")
            songs = json.loads((output / "songs.json").read_text())
            self.assertEqual(songs[0]["body"], structured_body)


def _write_csv(path: Path, *, body: str, second_song: bool = False) -> None:
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
        if second_song:
            writer.writerow(
                {
                    "ID": "song-2",
                    "TELUGU TITLE": "Title Two",
                    "TELUGU SONG": "Body Two",
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
