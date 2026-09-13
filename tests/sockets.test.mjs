import test from 'node:test';
import assert from 'node:assert/strict';
import { createSocketsFromLayout, describeSocketLayout, rollSocketLayout, socketCount } from '../src/game/systems/SocketSystem.js';

test('socket layouts create linked groups and unlinked singles',()=>{const sockets=createSocketsFromLayout([3,1,2]);assert.equal(sockets.length,6);assert.deepEqual(sockets.map(s=>s.linkGroup),[0,0,0,null,2,2]);});
test('layout description is human readable',()=>assert.equal(describeSocketLayout([4,1,2]),'4連 + 1孔 + 2連'));
test('legendary socket rolls stay within four to six sockets',()=>{for(const r of [0,.2,.49,.74,.99]){let i=0;const seq=[r,.9];const layout=rollSocketLayout('legendary',()=>seq[i++%seq.length]);assert.ok(socketCount(layout)>=4&&socketCount(layout)<=6);}});
test('common socket rolls stay within two to three sockets',()=>{for(const r of [0,.49,.99]){let i=0;const seq=[r,.4];const layout=rollSocketLayout('common',()=>seq[i++%seq.length]);assert.ok(socketCount(layout)>=2&&socketCount(layout)<=3);}});
