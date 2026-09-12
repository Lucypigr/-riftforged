import { Game } from './game/Game.js';
import { enableIsoMode2 } from './game/IsoMode2.js';

const canvas=document.querySelector('#game');
const game=new Game(canvas);
enableIsoMode2(game);
