import test from 'node:test';
import assert from 'node:assert/strict';
import { portraitExtraScaleForView, PORTRAIT_EXTRA_SCALE } from '../src/game/PortraitCamera.js';

test('portrait render applies an extra pullback layer',()=>{
  assert.equal(PORTRAIT_EXTRA_SCALE,.70);
  assert.equal(portraitExtraScaleForView({w:390,h:844}),.70);
});

test('landscape does not use the extra pullback layer',()=>{
  assert.equal(portraitExtraScaleForView({w:844,h:390}),1);
});

test('portrait pullback is materially farther than the prior 0.80 layer',()=>{
  const oldSpan=390/.80;
  const newSpan=390/PORTRAIT_EXTRA_SCALE;
  assert.ok(newSpan>oldSpan*1.14);
});
