import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.import_sheet_catalog import convert_rows, write_output


class ImportSheetCatalogTest(unittest.TestCase):
    def test_converts_only_publishable_rows(self):
        rows = convert_rows(
            "source_id,title,english_title,body,english_body,author,status\n"
            "song-1,Title One,English One,Body One,English Body,Author,approved\n"
            "song-2,Draft Song,,Draft Body,,,draft\n"
            "song-3,Title Three,,Body Three,,,published\n"
        )

        self.assertEqual(
            rows,
            [
                {
                    "ID": "song-1",
                    "TELUGU TITLE": "Title One",
                    "TELUGU ORIGINAL SONG": "Body One",
                    "TELUGU STRUCTURED SONG": "Body One",
                    "ENGLISH TITLE": "English One",
                    "ENGLISH ORIGINAL SONG": "English Body",
                    "ENGLISH STRUCTURED SONG": "English Body",
                    "AUTHOR": "Author",
                    "MALE VIDEO URL": "",
                    "FEMALE VIDEO URL": "",
                },
                {
                    "ID": "song-3",
                    "TELUGU TITLE": "Title Three",
                    "TELUGU ORIGINAL SONG": "Body Three",
                    "TELUGU STRUCTURED SONG": "Body Three",
                    "ENGLISH TITLE": "",
                    "ENGLISH ORIGINAL SONG": "",
                    "ENGLISH STRUCTURED SONG": "",
                    "AUTHOR": "",
                    "MALE VIDEO URL": "",
                    "FEMALE VIDEO URL": "",
                },
            ],
        )

    def test_accepts_headers_with_spaces_and_case(self):
        rows = convert_rows(
            "Source ID,Title,English Title,Body,English Body,Author,Status,Male Video Url,Female Video Url\n"
            "song-1,Title One,,Body One,,,Approved\n"
        )

        self.assertEqual(rows[0]["ID"], "song-1")

    def test_prefers_structured_lyrics_and_preserves_original_lyrics(self):
        rows = convert_rows(
            "source_id,title,english_title,original_song,structured_song,original_english_song,structured_english_song,author,status\n"
            "song-1,Title One,,Original,\"[Repeat ×2]\nLine\n[/Repeat]\",,,Author,approved\n"
        )

        self.assertEqual(rows[0]["TELUGU ORIGINAL SONG"], "Original")
        self.assertEqual(
            rows[0]["TELUGU STRUCTURED SONG"], "[Repeat ×2]\nLine\n[/Repeat]"
        )

    def test_rejects_missing_required_columns(self):
        with self.assertRaisesRegex(ValueError, "missing columns"):
            convert_rows("source_id,title,status\nsong-1,Title,approved\n")

    def test_rejects_duplicate_publishable_source_id(self):
        with self.assertRaisesRegex(ValueError, "repeats source_id"):
            convert_rows(
                "source_id,title,english_title,body,english_body,author,status\n"
                "song-1,Title One,,Body One,,,approved\n"
                "song-1,Title Two,,Body Two,,,published\n"
            )

    def test_writes_build_catalog_shape(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "songs.normalized.csv"
            write_output(
                path,
                [
                    {
                        "ID": "song-1",
                        "TELUGU TITLE": "Title",
                        "TELUGU ORIGINAL SONG": "Body",
                        "TELUGU STRUCTURED SONG": "Body",
                        "ENGLISH TITLE": "",
                        "ENGLISH ORIGINAL SONG": "",
                        "ENGLISH STRUCTURED SONG": "",
                        "AUTHOR": "",
                        "MALE VIDEO URL": "",
                        "FEMALE VIDEO URL": "",
                    }
                ],
            )

            with path.open("r", encoding="utf-8", newline="") as handle:
                reader = csv.DictReader(handle)
                self.assertEqual(
                    reader.fieldnames,
                    [
                        "ID",
                        "TELUGU TITLE",
                        "TELUGU ORIGINAL SONG",
                        "TELUGU STRUCTURED SONG",
                        "ENGLISH TITLE",
                        "ENGLISH ORIGINAL SONG",
                        "ENGLISH STRUCTURED SONG",
                        "AUTHOR",
                        "MALE VIDEO URL",
                        "FEMALE VIDEO URL",
                    ],
                )


if __name__ == "__main__":
    unittest.main()
