import { loadSpriteAssets, actorSpriteKey } from './SpriteAssets.js';

const TAU=Math.PI*2;
const ISO_X=.72, ISO_Y=.36;
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));

export function actorVisualScale(view,kind){
  const portrait=view?.h>view?.w*1.08;
  return portrait&&kind==='player'?.78:1;
}

function project(game,x,y){
  const dx=x-game.player.x,dy=y-game.player.y;
  return{x:game.view.w/2+(dx-dy)*ISO_X,y:game.view.h/2+(dx+dy)*ISO_Y};
}
function shadow(c,x,y,rx,ry,a=.45){c.fillStyle=`rgba(0,0,0,${a})`;c.beginPath();c.ellipse(x,y,rx,ry,0,0,TAU);c.fill();}
function feet(c,x,y,scale=1){c.fillStyle='#17191c';c.beginPath();c.ellipse(x-8*scale,y-2,9*scale,4*scale,-.15,0,TAU);c.ellipse(x+8*scale,y-2,9*scale,4*scale,.15,0,TAU);c.fill();}

function drawImageActor(c,img,x,y,kind,actor,time,visualScale=1){
  const boss=kind==='enemy'&&actor.boss;
  const brute=kind==='enemy'&&actor.type==='brute';
  const skitter=kind==='enemy'&&actor.type==='skitter';
  const baseH=boss?190:brute?154:skitter?112:kind==='player'?156:138;
  const h=baseH*visualScale;
  const iw=img.naturalWidth||img.width||1,ih=img.naturalHeight||img.height||1;
  const ratio=iw/Math.max(1,ih);
  const maxW=(boss?150:kind==='player'?132:116)*visualScale;
  const w=Math.min(h*ratio,maxW);
  shadow(c,x,y+2,w*.28,8*visualScale,boss?.58:.48);
  const bob=kind==='player'?Math.sin(time*5)*1.2*visualScale:0;
  c.save();
  if(kind==='enemy'&&actor.hitFlash>0){c.globalAlpha=.62;c.filter='brightness(1.8) saturate(.5)';}
  c.drawImage(img,x-w/2,y-h+bob,w,h);
  c.restore();
}

function hero(c,x,y,p,time,visualScale=1){
  c.save();c.translate(Math.round(x),Math.round(y));c.scale(visualScale,visualScale);
  const bob=Math.sin(time*5)*1.2;
  shadow(c,0,2,31,9,.52);feet(c,0,0,1);c.translate(0,bob);
  c.fillStyle='#252a31';c.fillRect(-13,-34,10,31);c.fillRect(4,-34,10,31);
  c.fillStyle='#777e86';c.fillRect(-14,-11,11,7);c.fillRect(4,-11,11,7);
  c.fillStyle='#5f1119';c.beginPath();c.moveTo(-19,-78);c.lineTo(15,-75);c.lineTo(25,-25);c.lineTo(6,-12);c.lineTo(-23,-24);c.closePath();c.fill();
  c.fillStyle='#343b45';c.beginPath();c.moveTo(-19,-78);c.lineTo(18,-78);c.lineTo(23,-42);c.lineTo(13,-30);c.lineTo(-12,-30);c.lineTo(-23,-43);c.closePath();c.fill();
  c.fillStyle='#59626e';c.fillRect(-14,-70,28,12);c.fillStyle='#c1ad78';c.fillRect(-3,-73,6,43);
  c.fillStyle='#505966';c.beginPath();c.ellipse(-23,-67,13,9,-.25,0,TAU);c.ellipse(23,-67,13,9,.25,0,TAU);c.fill();
  c.fillStyle='#9b866b';c.fillRect(-6,-86,12,10);c.fillStyle='#414a56';c.beginPath();c.arc(0,-99,16,0,TAU);c.fill();
  c.fillStyle='#b7a47c';c.beginPath();c.moveTo(-11,-101);c.lineTo(0,-119);c.lineTo(11,-101);c.lineTo(8,-89);c.lineTo(-8,-89);c.closePath();c.fill();
  c.fillStyle='#f2d590';c.fillRect(-8,-100,5,2);c.fillRect(4,-100,5,2);
  c.save();c.translate(20,-56);c.rotate(-.42);c.strokeStyle='#8a7550';c.lineWidth=6;c.beginPath();c.moveTo(-3,0);c.lineTo(18,0);c.stroke();c.strokeStyle='#e4d19a';c.lineWidth=5;c.beginPath();c.moveTo(17,0);c.lineTo(62,0);c.stroke();c.fillStyle='#f4e5b2';c.beginPath();c.moveTo(62,0);c.lineTo(74,-6);c.lineTo(70,5);c.closePath();c.fill();c.restore();
  c.restore();
}

function humanoid(c,e){
  const boss=e.boss,brute=e.type==='brute',s=boss?1.35:brute?1.14:1;c.scale(s,s);
  shadow(c,0,2,28,8,.48);feet(c,0,0,1);c.fillStyle='#242426';c.fillRect(-12,-30,9,28);c.fillRect(4,-30,9,28);
  c.fillStyle=e.hitFlash>0?'#d7b1a6':boss?'#49305f':brute?'#594047':'#65383a';c.beginPath();c.moveTo(-20,-72);c.lineTo(20,-72);c.lineTo(24,-37);c.lineTo(12,-28);c.lineTo(-12,-28);c.lineTo(-24,-37);c.closePath();c.fill();
  c.fillStyle=boss?'#c6b0d9':'#bba98b';c.beginPath();c.arc(0,-88,boss?15:13,0,TAU);c.fill();c.fillStyle=boss?'#ff72ff':'#ff645d';c.fillRect(-8,-90,5,2);c.fillRect(4,-90,5,2);
}
function skitter(c,e){shadow(c,0,2,27,8,.45);c.strokeStyle='#7c5b42';c.lineWidth=5;for(const side of[-1,1])for(let i=0;i<3;i++){c.beginPath();c.moveTo(side*(7+i*3),-18-i*3);c.lineTo(side*(22+i*7),-5+i*2);c.stroke();}c.fillStyle=e.hitFlash>0?'#d8a273':'#71452f';c.beginPath();c.ellipse(0,-31,21,26,0,0,TAU);c.fill();c.fillStyle='#9a704e';c.beginPath();c.arc(0,-57,13,0,TAU);c.fill();}
function fallbackEnemy(c,x,y,e){c.save();c.translate(Math.round(x),Math.round(y));if(e.type==='skitter')skitter(c,e);else humanoid(c,e);c.restore();}
function healthBar(c,x,y,e){if(e.hp>=e.maxHp&&!e.boss)return;const w=e.boss?100:48,top=y-(e.boss?190:e.type==='brute'?154:e.type==='skitter'?112:138)-8;c.fillStyle='#111315';c.fillRect(x-w/2,top,w,6);c.fillStyle=e.boss?'#9b6bc5':'#b94d47';c.fillRect(x-w/2,top,w*clamp(e.hp/e.maxHp,0,1),6);}

export function enableUprightSprites(game){
  const sprites=loadSpriteAssets();
  const baseDraw=game.draw.bind(game);
  game.draw=function(){
    baseDraw();const c=this.ctx;
    const actors=[...this.enemies.map(e=>({kind:'enemy',o:e})),{kind:'player',o:this.player}].sort((a,b)=>(a.o.x+a.o.y)-(b.o.x+b.o.y));
    for(const a of actors){
      const s=project(this,a.o.x,a.o.y),visualScale=actorVisualScale(this.view,a.kind);
      c.save();c.globalAlpha=.94;c.fillStyle='#222322';c.beginPath();c.ellipse(s.x,s.y-28*visualScale,(a.kind==='player'?34:Math.max(28,a.o.radius*1.25))*visualScale,(a.kind==='player'?34:Math.max(30,a.o.radius*1.3))*visualScale,0,0,TAU);c.fill();c.restore();
      const key=actorSpriteKey(a.o,a.kind);
      const img=sprites.processed[key]||sprites.images[key];
      if(sprites.ready[key])drawImageActor(c,img,s.x,s.y,a.kind,a.o,this.time,visualScale);
      else if(a.kind==='player')hero(c,s.x,s.y,this.player,this.time,visualScale);else fallbackEnemy(c,s.x,s.y,a.o);
      if(a.kind==='enemy')healthBar(c,s.x,s.y,a.o);
    }
  };
}
