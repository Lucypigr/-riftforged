import { Game } from './game/Game.js';
import { enableIsoMode } from './game/IsoMode.js';

const canvas=document.querySelector('#game');
const game=new Game(canvas);
enableIsoMode(game);
