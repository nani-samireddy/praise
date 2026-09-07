import {plainLyrics} from './chords.js';
export function parse(text) {
  if (/\[\/?Repeat(?:\s|:|\])/i.test(text)) throw Error('Paste the original lyrics with (2) or ||cue|| markers, rather than app markup.');
  const blocks = []; let lines = []; let label = '';
  const flush = (count = 1) => { if(lines.length) { blocks.push({label, text:lines.join('\n'), count}); lines=[]; label=''; } };
  for (let line of text.replace(/\r/g,'').split('\n')) {
    line=line.trim().replace(/[\t \u00a0]+/g,' ').replace(/^\*\*(.*?)\*\*$/, '$1');
    if (!line) { flush(); continue; }
    const heading = line.replace(/^\[|\]$/g,'').replace(/:$/, '');
    const aliases = {'పల్లవి':'Chorus','చరణం':'Verse','chorus':'Chorus','bridge':'Bridge','pre-chorus':'Pre-Chorus','ending':'Ending'};
    const recognized=aliases[heading.toLowerCase()] || (/^verse(?:\s+\d+)?$/i.test(heading) ? heading.replace(/^verse/i,'Verse') : null);
    if (recognized) { flush(); label=recognized; continue; }
    for(const piece of line.split(/(\|\|[^|]+\|\|)/)) {
      if (!piece.trim()) continue;
      if(piece.startsWith('||')) { flush(); blocks.push({cue:piece.slice(2,-2).trim()}); continue; }
      const match=piece.trim().match(/\s*(?:\(([2-9]|1[0-2])\)|[xX×*]\s*([2-9]|1[0-2]))$/);
      const lyric=match ? piece.trim().slice(0,match.index).trim() : piece.trim();
      if(lyric) lines.push(lyric);
      if(match) flush(Number(match[1]||match[2]));
    }
  }
  flush();
  if(label) blocks.push({label,text:'',count:1});
  return blocks;
}
export function serialize(blocks, structured=false, keepChords=false) {
  return blocks.map(b=> {
    if ('cue' in b) return structured ? `[Repeat: ${b.cue}]` : `||${b.cue}||`;
    const text=(keepChords ? b.text : plainLyrics(b.text)).trim(); const heading=b.label ? `[${b.label}]\n` : '';
    return heading+(b.count>1 ? (structured ? `[Repeat ×${b.count}]\n${text}\n[/Repeat]` : `${text} (${b.count})`) : text);
  }).join('\n\n');
}
