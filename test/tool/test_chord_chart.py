import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.chord_chart import ChordChartError, parse_arrangement_text


class ChordChartTest(unittest.TestCase):
    def test_parses_inline_telugu_chords_into_lyric_segments(self):
        arrangement = parse_arrangement_text(
            "[Verse 1]\n[D]నీ ప్రేమ [G]నన్ను నడి[A]పించెను",
            arrangement_id="default-d",
            name="Default D",
            language="primary",
            key="D",
        )

        line = arrangement["sections"][0]["lines"][0]
        self.assertEqual(line["text"], "నీ ప్రేమ నన్ను నడిపించెను")
        self.assertEqual(
            line["segments"],
            [
                {"text": "నీ ప్రేమ ", "chord": "D"},
                {"text": "నన్ను నడి", "chord": "G"},
                {"text": "పించెను", "chord": "A"},
            ],
        )

    def test_preserves_lyrics_only_lines(self):
        arrangement = parse_arrangement_text(
            "[Chorus]\nPlain lyric line",
            arrangement_id="default-c",
            name="Default C",
            language="english",
            key="C",
        )

        line = arrangement["sections"][0]["lines"][0]
        self.assertEqual(
            line,
            {"text": "Plain lyric line", "segments": [{"text": "Plain lyric line"}]},
        )

    def test_rejects_invalid_chord(self):
        with self.assertRaises(ChordChartError):
            parse_arrangement_text(
                "[H]Invalid root",
                arrangement_id="default",
                name="Default",
                language="primary",
                key="C",
            )

    def test_rejects_invalid_metadata(self):
        with self.assertRaises(ChordChartError):
            parse_arrangement_text(
                "[C]Line",
                arrangement_id="Default",
                name="Default",
                language="primary",
                key="C",
            )


if __name__ == "__main__":
    unittest.main()
