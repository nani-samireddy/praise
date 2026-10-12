# Product TODO

## Song page controls panel — implemented

- [x] Collapsible song-specific controls, closed initially so lyrics stay dominant.
- [x] Lyrics display, text size, and repeat expansion; contextual chord display,
  transpose, capo shapes and harmony; independent metronome practice.
- [x] Gate musical controls on both local feature preferences and usable song
  content. A preference enables a tool; it does not supply an arrangement.
- [x] Chords without a declared key can shift by semitones; explain the missing
  key instead of claiming a known original/target key.
- [x] Reject malformed arrangement fields and fall back to ordinary song lyrics
  when no readable structured lyrics exist.
- [x] Label toggles and transpose steps explicitly, expose expanded/checked
  states to accessibility services, and retain Material touch targets.
- [x] Keep existing share/report/edit/delete actions in their current workflows.

## Content publication — separate remaining work

Only **two bundled arrangement records** were found for the **1,374-song**
catalogue in the 12 October 2026 audit. Chords, keys, capo and harmony are
available only where usable metadata exists; they are not catalogue-wide.

- [ ] Align editor, bundle and remote publication with one arrangement schema.
- [ ] Associate arrangements with lyric revisions and invalidate stale structures
  during sync. Current remote publication does not deliver arrangements.
- [ ] Publish additional reviewed arrangements and harmony parts.

## Device validation — pending

- [ ] Verify TalkBack focus/announcements, Telugu wrapping, contrast, 200% text,
  landscape and one-handed controls on actual Android hardware.
- [ ] Measure metronome timing under load and lifecycle behavior on device.
