import {test} from 'node:test';import assert from 'node:assert/strict';import {parse,serialize} from './format.js';
test('heading excluded from repeat and Telugu preserved',()=>{assert.equal(serialize(parse('పల్లవి\nఅన్ని వేళల ఆరాధన\nకన్న తండ్రి నీకే మహిమ (4)'),true),'[Chorus]\n[Repeat:4]\nఅన్ని వేళల ఆరాధన\nకన్న తండ్రి నీకే మహిమ\n[/Repeat:4]');});
test('two markers make independent phrases',()=>{const b=parse('One\nTwo (2)\nThree\nFour (3) ||One||');assert.equal(b.length,3);assert.equal(b[0].count,2);assert.equal(b[1].count,3);assert.equal(b[2].cue,'One');});
test('normalized round trip',()=>{const b=parse('Verse 1\nA\nB (2)\n\nC (3)');assert.deepEqual(parse(serialize(b)),b);});
test('duplicates kept and structured input rejected',()=>{assert.equal(parse('A\nA')[0].text,'A\nA');assert.throws(()=>parse('[Repeat ×2]\nA\n[/Repeat]'));});
