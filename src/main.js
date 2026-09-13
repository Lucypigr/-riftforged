import { Game } from './game/Game.js';
import { enableIsoMode2 } from './game/IsoMode2.js';
import { enableUprightSprites } from './game/UprightSprites.js';
import { enableGemSystem } from './game/systems/GemSystem.js';

const canvas=document.querySelector('#game');
const game=new Game(canvas);
enableIsoMode2(game);
enableUprightSprites(game);
enableGemSystem(game);
