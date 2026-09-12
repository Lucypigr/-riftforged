import test from 'node:test';
import assert from 'node:assert/strict';
import { rollItem, itemPower, weightedRarity } from '../src/game/systems/LootSystem.js';

test('forced legendary produces three unique affixes',()=>{
  let seq=[0,0,.1,.2,.3,.4,.5,.6,.7,.8],i=0;const rng=()=>seq[i++%seq.length];
  const item=rollItem(5,rng,'legendary');
  assert.equal(item.rarity,'legendary');
  assert.equal(item.affixes.length,3);
  assert.equal(new Set(item.affixes.map(a=>a.stat)).size,3);
});

test('item power is positive',()=>assert.ok(itemPower(rollItem(1,()=>.5,'rare'))>0));
test('rarity boundaries work',()=>{assert.equal(weightedRarity(()=>0),'common');assert.equal(weightedRarity(()=>.99),'legendary')});
