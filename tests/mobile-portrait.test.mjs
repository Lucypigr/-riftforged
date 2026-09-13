import test from 'node:test';
import assert from 'node:assert/strict';
import { actorVisualScale } from '../src/game/UprightSprites.js';

test('portrait phones render the player smaller',()=>{
  assert.equal(actorVisualScale({w:390,h:844},'player'),.78);
});

test('landscape keeps the default player size',()=>{
  assert.equal(actorVisualScale({w:844,h:390},'player'),1);
});

test('portrait scaling does not shrink enemies',()=>{
  assert.equal(actorVisualScale({w:390,h:844},'enemy'),1);
});
