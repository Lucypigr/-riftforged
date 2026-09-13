import test from 'node:test';
import assert from 'node:assert/strict';
import { portraitExtraScaleForView, PORTRAIT_EXTRA_SCALE } from '../src/game/PortraitCamera.js';

test('portrait render applies an extra pullback layer',()=>{
  assert.equal(PORTRAIT_EXTRA_SCALE,.80);
  assert.equal(portraitExtraScaleForView({w:390,h:844}),.80);
});

test('landscape does not use the extra pullback layer',()=>{
  assert.equal(portraitExtraScaleForView({w:844,h:390}),1);
});
