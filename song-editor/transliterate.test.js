import {test} from 'node:test';import assert from 'node:assert/strict';import {transliterate} from './transliterate.js';
test('Telugu lyrics and conjuncts',()=>assert.equal(transliterate('అన్ని వేళల ఆరాధన\nకన్న తండ్రి నీకే మహిమ'),'anni velala aaraadhana\nkanna tandri neeke mahima'));
test('preserves chords markers English and spacing',()=>assert.equal(transliterate('[Chorus]\n[D/F#]నీ ప్రేమ (2)\n\n||ప్రేమ|| Hello'),'[Chorus]\n[D/F#]nee prema (2)\n\n||prema|| Hello'));
test('digits and independent vowels',()=>assert.equal(transliterate('ఆ ఈ ఊ ౨'),'aa ee oo 2'));
