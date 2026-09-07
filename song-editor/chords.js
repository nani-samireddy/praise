export const chordPattern = /^[A-G][#b]?(?:maj|min|dim|aug|sus2|sus4|m)?(?:13|11|9|7|6|5|4|2)?(?:\/[A-G][#b]?)?$/;

// Inline markers travel with their lyrics when phrases are edited or split.
export function chordParts(line) {
  const parts = []; let position = 0; let pending = '';
  for (const match of line.matchAll(/\[([^\]]+)\]/g)) {
    if (!chordPattern.test(match[1])) continue;
    const text = line.slice(position, match.index);
    if (text || pending) parts.push({text, chord: pending});
    pending = match[1]; position = match.index + match[0].length;
  }
  parts.push({text: line.slice(position), chord: pending});
  return parts;
}
export function plainLyrics(text) {
  return text.split('\n').map(line => chordParts(line).map(p => p.text).join('')).join('\n');
}
export function insertChord(text, cursor, chord) {
  if (!chordPattern.test(chord)) throw Error('Use a chord such as D, F#m, Bb, Asus4 or D/F#.');
  // Snap before a complete grapheme so Telugu vowel signs cannot be separated.
  const segmenter = new Intl.Segmenter(undefined, {granularity:'grapheme'});
  let at = text.length;
  for (const item of segmenter.segment(text)) {
    if (cursor < item.index + item.segment.length) { at = item.index; break; }
  }
  const open = text.lastIndexOf('[', at);
  const close = text.indexOf(']', open);
  if (open >= 0 && close >= at && chordPattern.test(text.slice(open+1,close))) {
    return text.slice(0,open)+`[${chord}]`+text.slice(close+1);
  }
  return text.slice(0,at)+`[${chord}]`+text.slice(at);
}

export function addRepeatToSelection(text, start, end, count) {
  if (!Number.isInteger(count) || count < 2 || count > 12) throw Error('Choose a repeat count from 2 to 12.');
  if (start === end) throw Error('Select the lyric lines to repeat first.');
  const selected = text.slice(start, end).trim();
  if (!selected) throw Error('Select the lyric lines to repeat first.');
  return text.slice(0, start) + `[Repeat:${count}]\n${selected}\n[/Repeat:${count}]` + text.slice(end);
}
