import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.repeat_blocks import apply, scan


class RepeatBlocksTest(unittest.TestCase):
    def test_scan_and_apply_preserves_original_lyrics(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            source = workspace / "songs.csv"
            review = workspace / "review.csv"
            output = workspace / "updated.csv"
            body = "Line one ×2\nLine two ×2\nLine one ×2\nLine two ×2"
            _write_source(source, body)

            self.assertEqual(scan(source, review), 1)
            with review.open("r", encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(rows[0]["repeat_count"], "4")
            self.assertEqual(rows[0]["decision"], "pending")
            rows[0]["decision"] = "approved"
            with review.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)

            self.assertEqual(apply(source, review, output, overwrite=False), 1)
            with output.open("r", encoding="utf-8", newline="") as handle:
                updated = next(csv.DictReader(handle))
            self.assertEqual(updated["TELUGU ORIGINAL SONG"], body)
            self.assertEqual(
                updated["TELUGU STRUCTURED SONG"],
                "[Repeat ×4]\nLine one\nLine two\n[/Repeat]",
            )


def _write_source(path: Path, body: str) -> None:
    fields = [
        "ID",
        "TELUGU TITLE",
        "TELUGU ORIGINAL SONG",
        "TELUGU STRUCTURED SONG",
        "ENGLISH TITLE",
        "ENGLISH ORIGINAL SONG",
        "ENGLISH STRUCTURED SONG",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerow(
            {
                "ID": "song-1",
                "TELUGU TITLE": "Song One",
                "TELUGU ORIGINAL SONG": body,
                "TELUGU STRUCTURED SONG": body,
                "ENGLISH TITLE": "",
                "ENGLISH ORIGINAL SONG": "",
                "ENGLISH STRUCTURED SONG": "",
            }
        )


if __name__ == "__main__":
    unittest.main()
