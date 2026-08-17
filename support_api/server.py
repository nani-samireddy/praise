"""Small stateless API that turns Praise feedback into GitHub issues."""

from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
from collections import defaultdict, deque
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable


MAX_REQUEST_BYTES = 16_384
GITHUB_API_VERSION = "2026-03-10"


class SubmissionError(Exception):
    def __init__(self, message: str, status: HTTPStatus = HTTPStatus.BAD_REQUEST):
        super().__init__(message)
        self.message = message
        self.status = status


class RateLimiter:
    def __init__(self, limit: int = 3, window_seconds: int = 3600):
        self.limit = limit
        self.window_seconds = window_seconds
        self._requests: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str, now: float | None = None) -> bool:
        timestamp = time.time() if now is None else now
        cutoff = timestamp - self.window_seconds
        with self._lock:
            requests = self._requests[key]
            while requests and requests[0] <= cutoff:
                requests.popleft()
            if len(requests) >= self.limit:
                return False
            requests.append(timestamp)
            return True


def build_issue(payload: object) -> dict[str, str]:
    if not isinstance(payload, dict):
        raise SubmissionError("The request body must be a JSON object.")
    kind = _required(payload, "kind", 40)
    if kind == "song_request":
        title = _required(payload, "title", 180)
        body = _markdown(
            "Song request",
            [
                ("Title", title),
                ("English title", _optional(payload, "englishTitle", 180)),
                ("Author or source", _optional(payload, "author", 240)),
                ("Lyrics or source link", _required(payload, "lyricsOrSource", 6000)),
                ("Additional notes", _optional(payload, "notes", 2000)),
            ],
        )
        return {"title": f"[Song request] {title}", "body": body}
    if kind == "problem_report":
        summary = _required(payload, "summary", 180)
        body = _markdown(
            "App problem report",
            [
                ("Summary", summary),
                ("What happened?", _required(payload, "description", 4000)),
                ("Steps to reproduce", _optional(payload, "steps", 2500)),
                ("Device details", _optional(payload, "deviceDetails", 500)),
            ],
        )
        return {"title": f"[Report] {summary}", "body": body}
    if kind == "song_correction":
        song_title = _required(payload, "songTitle", 180)
        body = _markdown(
            "Song correction",
            [
                ("Song title", song_title),
                ("English title", _optional(payload, "songEnglishTitle", 180)),
                ("Catalogue ID", _required(payload, "songId", 180)),
                ("What should be corrected?", _required(payload, "correction", 4000)),
                (
                    "Suggested correction or source",
                    _optional(payload, "suggestedCorrectionOrSource", 4000),
                ),
            ],
        )
        return {"title": f"[Song correction] {song_title}", "body": body}
    raise SubmissionError("Unsupported feedback type.")


def create_github_issue(
    issue: dict[str, str],
    *,
    token: str,
    repository: str,
    opener: Callable[..., object] = urllib.request.urlopen,
) -> dict[str, object]:
    if not token:
        raise SubmissionError(
            "The support service is not configured.",
            HTTPStatus.SERVICE_UNAVAILABLE,
        )
    parts = repository.split("/", 1)
    if len(parts) != 2 or not all(parts):
        raise SubmissionError(
            "The support repository is not configured.",
            HTTPStatus.SERVICE_UNAVAILABLE,
        )
    request = urllib.request.Request(
        f"https://api.github.com/repos/{parts[0]}/{parts[1]}/issues",
        data=json.dumps(issue).encode("utf-8"),
        method="POST",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "Praise-Support-API",
            "X-GitHub-Api-Version": GITHUB_API_VERSION,
        },
    )
    try:
        with opener(request, timeout=20) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code == HTTPStatus.UNPROCESSABLE_ENTITY:
            message = "GitHub rejected this submission. Please revise it and try again."
            status = HTTPStatus.BAD_REQUEST
        elif error.code in (HTTPStatus.FORBIDDEN, HTTPStatus.TOO_MANY_REQUESTS):
            message = "The support service is temporarily rate limited. Try again later."
            status = HTTPStatus.SERVICE_UNAVAILABLE
        else:
            message = "GitHub could not create the issue. Try again later."
            status = HTTPStatus.BAD_GATEWAY
        raise SubmissionError(message, status) from error
    except (OSError, ValueError) as error:
        raise SubmissionError(
            "GitHub could not be reached. Try again later.",
            HTTPStatus.BAD_GATEWAY,
        ) from error
    number = result.get("number") if isinstance(result, dict) else None
    url = result.get("html_url") if isinstance(result, dict) else None
    if not isinstance(number, int) or not isinstance(url, str):
        raise SubmissionError(
            "GitHub returned an invalid response.",
            HTTPStatus.BAD_GATEWAY,
        )
    return {"number": number, "url": url}


def _required(payload: dict[object, object], key: str, maximum: int) -> str:
    value = _optional(payload, key, maximum)
    if value is None:
        raise SubmissionError(f"{key} is required.")
    return value


def _optional(payload: dict[object, object], key: str, maximum: int) -> str | None:
    value = payload.get(key)
    if value is None:
        return None
    if not isinstance(value, str):
        raise SubmissionError(f"{key} must be text.")
    normalized = value.strip()
    if not normalized:
        return None
    if len(normalized) > maximum:
        raise SubmissionError(f"{key} is too long.")
    return normalized.replace("@", "@\u200b")


def _markdown(heading: str, fields: list[tuple[str, str | None]]) -> str:
    sections = [f"## {heading}"]
    for label, value in fields:
        if value is None:
            continue
        sections.extend((f"### {label}", value))
    sections.extend(("---", "Submitted anonymously from the Praise app."))
    return "\n\n".join(sections)


class PraiseSupportHandler(BaseHTTPRequestHandler):
    limiter = RateLimiter(
        limit=int(os.environ.get("RATE_LIMIT_PER_HOUR", "3")),
        window_seconds=3600,
    )

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path == "/health":
            self._json(HTTPStatus.OK, {"status": "ok"})
        else:
            self._json(HTTPStatus.NOT_FOUND, {"message": "Not found."})

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if self.path != "/v1/issues":
            self._json(HTTPStatus.NOT_FOUND, {"message": "Not found."})
            return
        client = self.headers.get("X-Forwarded-For", self.client_address[0])
        client = client.split(",", 1)[0].strip()
        if not self.limiter.allow(client):
            self._json(
                HTTPStatus.TOO_MANY_REQUESTS,
                {"message": "Too many submissions. Try again later."},
            )
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > MAX_REQUEST_BYTES:
                raise SubmissionError("The request is empty or too large.")
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            issue = build_issue(payload)
            result = create_github_issue(
                issue,
                token=os.environ.get("GITHUB_TOKEN", ""),
                repository=os.environ.get(
                    "GITHUB_REPOSITORY", "nani-samireddy/praise"
                ),
            )
            self._json(HTTPStatus.CREATED, result)
        except json.JSONDecodeError:
            self._json(HTTPStatus.BAD_REQUEST, {"message": "Invalid JSON."})
        except (UnicodeDecodeError, ValueError):
            self._json(HTTPStatus.BAD_REQUEST, {"message": "Invalid request."})
        except SubmissionError as error:
            self._json(error.status, {"message": error.message})

    def log_message(self, format: str, *args: object) -> None:
        # Request bodies can contain lyrics or user reports, so never log them.
        print(f"{self.address_string()} - {format % args}")

    def _json(self, status: HTTPStatus, value: dict[str, object]) -> None:
        body = json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(os.environ.get("PORT", "10000"))
    server = ThreadingHTTPServer(("0.0.0.0", port), PraiseSupportHandler)
    print(f"Praise support API listening on port {port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
