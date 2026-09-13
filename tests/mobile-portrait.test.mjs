import test from 'node:test';
import assert from 'node:assert/strict';
import { cameraZoomForView } from '../src/game/IsoMode2.js';

test('portrait phones use a pulled-back world camera',()=>{
  assert.equal(cameraZoomForView({w:390,h:844}),.72);
});

test('landscape keeps the default camera zoom',()=>{
  assert.equal(cameraZoomForView({w:844,h:390}),1);
});

test('portrait camera exposes substantially more horizontal world span',()=>{
  const visibleWorldSpan=390/cameraZoomForView({w:390,h:844});
  assert.ok(visibleWorldSpan>=540);
});
