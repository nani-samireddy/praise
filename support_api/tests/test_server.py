import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from server import RateLimiter, SubmissionError, build_issue, create_github_issue


class _Response:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def read(self):
        return json.dumps(self.value).encode("utf-8")


class SupportApiTests(unittest.TestCase):
    def test_builds_song_request_and_neutralizes_mentions(self):
        issue = build_issue(
            {
                "kind": "song_request",
                "title": "New song",
                "lyricsOrSource": "Please ask @someone",
            }
        )

        self.assertEqual(issue["title"], "[Song request] New song")
        self.assertIn("@\u200bsomeone", issue["body"])
        self.assertIn("Submitted anonymously", issue["body"])

    def test_requires_correction_details(self):
        with self.assertRaises(SubmissionError):
            build_issue(
                {
                    "kind": "song_correction",
                    "songId": "one",
                    "songTitle": "Song",
                    "correction": "",
                }
            )

    def test_rate_limiter_releases_entries_after_window(self):
        limiter = RateLimiter(limit=2, window_seconds=10)

        self.assertTrue(limiter.allow("client", now=0))
        self.assertTrue(limiter.allow("client", now=1))
        self.assertFalse(limiter.allow("client", now=2))
        self.assertTrue(limiter.allow("client", now=11))

    def test_creates_issue_with_token_only_on_server(self):
        captured = {}

        def opener(request, timeout):
            captured["authorization"] = request.headers["Authorization"]
            captured["timeout"] = timeout
            return _Response(
                {"number": 42, "html_url": "https://github.com/example/issues/42"}
            )

        result = create_github_issue(
            {"title": "Title", "body": "Body"},
            token="server-secret",
            repository="owner/repo",
            opener=opener,
        )

        self.assertEqual(result["number"], 42)
        self.assertEqual(captured["authorization"], "Bearer server-secret")
        self.assertEqual(captured["timeout"], 20)


if __name__ == "__main__":
    unittest.main()
