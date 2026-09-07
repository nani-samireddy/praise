import {test} from 'node:test';import assert from 'node:assert/strict';
import {insertChord,chordParts} from './chords.js';import {parse,serialize} from './format.js';
test('Telugu insertion does not split vowel mark',()=>assert.equal(insertChord('నీ ప్రేమ',1,'D'),'[D]నీ ప్రేమ'));
test('replace existing chord and reject invalid',()=>{assert.equal(insertChord('[D]Love',1,'G/B'),'[G/B]Love');assert.throws(()=>insertChord('Love',0,'H'));});
test('lyrics exports omit chords while chart retains them',()=>{const b=parse('[D]నీ ప్రేమ [G]నన్ను (2)');assert.equal(serialize(b),'నీ ప్రేమ నన్ను (2)');assert.equal(serialize(b,false,true),'[D]నీ ప్రేమ [G]నన్ను (2)');assert.equal(chordParts(b[0].text)[1].chord,'G');});
