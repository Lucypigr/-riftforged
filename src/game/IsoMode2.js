import { CONFIG } from './config.js';

const TAU = Math.PI * 2;
const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));
const ISO_X = .72;
const ISO_Y = .36;

export function cameraZoomForView(view){
  const portrait=view?.h>view?.w*1.08;
  return portrait?.72:1;
}

function seedProps(){
  const props=[];
  const fixed=[
    [270,260,'brazier'],[520,360,'pillar'],[820,250,'rubble'],[1220,310,'brazier'],[1540,420,'banner'],
    [1780,300,'pillar'],[360,880,'rubble'],[680,1050,'brazier'],[980,930,'statue'],[1430,990,'pillar'],
    [1760,930,'brazier'],[1880,650,'banner'],[520,650,'brazier'],[1180,700,'rubble']
  ];
  for(const [x,y,type] of fixed) props.push({x,y,type,scale:.8+((x+y)%37)/80});
  for(let i=0;i<26;i++) props.push({x:160+(i*173)%1880,y:150+(i*257)%1100,type:i%3===0?'rubble':'grass',scale:.75+(i%5)*.08});
  return props;
}

function project(game,x,y){
  const dx=x-game.player.x;
  const dy=y-game.player.y;
  return {x:game.view.w/2+(dx-dy)*ISO_X,y:game.view.h/2+(dx+dy)*ISO_Y};
}

export function enableIsoMode2(game){
  const rawMove=game.input.movement.bind(game.input);
  game.input.movement=()=>{const m=rawMove();const k=Math.SQRT1_2;return{x:(m.x+m.y)*k,y:(m.y-m.x)*k};};
  const props=seedProps();

  game.draw=function(){
    const c=this.ctx,w=this.view.w,h=this.view.h,zoom=cameraZoomForView(this.view);
    const shakeX=(Math.random()-.5)*this.camera.shake,shakeY=(Math.random()-.5)*this.camera.shake;
    c.clearRect(0,0,w,h);c.fillStyle='#080a0d';c.fillRect(0,0,w,h);

    c.save();
    c.translate(w/2+shakeX,h/2+shakeY);
    c.scale(zoom,zoom);
    c.transform(ISO_X,ISO_Y,-ISO_X,ISO_Y,0,0);
    c.translate(-this.player.x,-this.player.y);
    drawIsoGround(c);
    c.restore();

    c.save();c.translate(shakeX,shakeY);c.translate(w/2,h/2);c.scale(zoom,zoom);c.translate(-w/2,-h/2);
    const renderables=[];
    for(const p of props)renderables.push({depth:p.x+p.y,kind:'prop',obj:p});
    for(const e of this.enemies)renderables.push({depth:e.x+e.y,kind:'enemy',obj:e});
    for(const d of this.drops)renderables.push({depth:d.x+d.y,kind:'drop',obj:d});
    renderables.push({depth:this.player.x+this.player.y,kind:'player',obj:this.player});
    renderables.sort((a,b)=>a.depth-b.depth);
    for(const r of renderables){const s=project(this,r.obj.x,r.obj.y);if(r.kind==='prop')drawPropScreen(c,s.x,s.y,r.obj,this.time);else if(r.kind==='enemy')drawEnemyScreen(c,s.x,s.y,r.obj,this.time);else if(r.kind==='drop')drawDropScreen(c,s.x,s.y,r.obj);else drawPlayerScreen(c,s.x,s.y,r.obj);}
    for(const q of this.projectiles){const s=project(this,q.x,q.y);drawProjectileScreen(c,s.x,s.y);}
    drawFxScreen(c,this,project);c.restore();drawVignette(c,w,h);drawFog(c,w,h,this.time);
  };
}

function drawIsoGround(c){
  c.fillStyle='#242323';c.fillRect(0,0,CONFIG.world.width,CONFIG.world.height);
  const tile=96;
  for(let y=0;y<CONFIG.world.height;y+=tile){for(let x=0;x<CONFIG.world.width;x+=tile){const n=((x/tile)*13+(y/tile)*7)%5;c.fillStyle=['#393735','#343331','#302f2e','#3d3a37','#2d2d2c'][n];c.fillRect(x+2,y+2,tile-4,tile-4);c.strokeStyle='rgba(95,88,78,.38)';c.lineWidth=2;c.strokeRect(x+3,y+3,tile-6,tile-6);}}
  c.strokeStyle='rgba(31,26,23,.8)';c.lineWidth=10;c.strokeRect(28,28,CONFIG.world.width-56,CONFIG.world.height-56);
}

function shadow(c,x,y,rx,ry,a){c.fillStyle=`rgba(0,0,0,${a})`;c.beginPath();c.ellipse(x,y,rx,ry,0,0,TAU);c.fill();}

function drawPropScreen(c,x,y,p,time){
  c.save();c.translate(x,y);c.scale(p.scale,p.scale);
  if(p.type==='brazier'){shadow(c,0,7,22,8,.3);c.fillStyle='#23262a';c.fillRect(-9,-10,18,26);c.fillRect(-16,13,32,8);c.shadowBlur=24;c.shadowColor='#ff8c34';c.fillStyle='#ff9b39';c.beginPath();c.moveTo(-8,-8);c.quadraticCurveTo(-4,-29+Math.sin(time*8+p.x)*3,0,-48);c.quadraticCurveTo(8,-27,8,-8);c.fill();c.shadowBlur=0;}
  else if(p.type==='pillar'){shadow(c,0,8,28,10,.35);c.fillStyle='#47484a';c.fillRect(-14,-76,28,82);c.fillStyle='#69645d';c.fillRect(-21,-79,42,11);c.fillRect(-20,3,40,10);c.fillStyle='#2c2d2f';c.beginPath();c.moveTo(-14,-76);c.lineTo(6,-92);c.lineTo(19,-70);c.lineTo(8,-61);c.closePath();c.fill();}
  else if(p.type==='banner'){c.strokeStyle='#343536';c.lineWidth=5;c.beginPath();c.moveTo(0,-98);c.lineTo(0,15);c.stroke();c.fillStyle='#65151b';c.beginPath();c.moveTo(4,-91);c.lineTo(53,-82);c.lineTo(45,-21);c.lineTo(17,11);c.lineTo(4,5);c.closePath();c.fill();}
  else if(p.type==='statue'){shadow(c,0,8,32,10,.35);c.fillStyle='#55575a';c.beginPath();c.moveTo(0,-82);c.lineTo(20,-38);c.lineTo(17,20);c.lineTo(-17,20);c.lineTo(-20,-38);c.closePath();c.fill();c.fillRect(-30,20,60,20);}
  else if(p.type==='grass'){c.strokeStyle='rgba(92,109,72,.55)';c.lineWidth=2;for(let i=0;i<5;i++){c.beginPath();c.moveTo(i*3-6,3);c.lineTo(i*4-10,-8-(i%3)*5);c.stroke();}}
  else{shadow(c,0,4,22,7,.3);c.fillStyle='#4a4948';c.rotate((p.x%17)*.08);c.fillRect(-18,-8,36,16);c.fillStyle='#62615e';c.fillRect(-11,-5,22,5);}c.restore();
}

function drawPlayerScreen(c,x,y,p){
  c.save();c.translate(x,y);shadow(c,0,5,27,10,.42);
  c.fillStyle='#292e35';c.fillRect(-10,-20,8,22);c.fillRect(3,-20,8,22);c.fillStyle='#9299a0';c.fillRect(-11,-4,10,5);c.fillRect(2,-4,10,5);
  c.fillStyle='#67131b';c.beginPath();c.moveTo(-13,-58);c.lineTo(-29,-14);c.lineTo(-13,-4);c.lineTo(1,-29);c.lineTo(7,-55);c.closePath();c.fill();
  c.fillStyle='#303640';c.beginPath();c.moveTo(-15,-57);c.lineTo(14,-57);c.lineTo(19,-29);c.lineTo(8,-18);c.lineTo(-9,-18);c.lineTo(-19,-31);c.closePath();c.fill();
  c.fillStyle='#5a626d';c.fillRect(-9,-50,18,10);c.fillStyle='#b8aa86';c.fillRect(-2,-53,4,34);
  c.fillStyle='#464e59';c.beginPath();c.arc(-17,-49,9,0,TAU);c.fill();c.beginPath();c.arc(17,-49,9,0,TAU);c.fill();
  c.fillStyle='#414954';c.beginPath();c.arc(0,-73,13,0,TAU);c.fill();c.fillStyle='#a99c7f';c.beginPath();c.moveTo(-8,-72);c.lineTo(0,-88);c.lineTo(8,-72);c.lineTo(5,-63);c.lineTo(-5,-63);c.closePath();c.fill();
  c.fillStyle='#f0d69a';c.beginPath();c.arc(-4,-73,1.6,0,TAU);c.arc(4,-73,1.6,0,TAU);c.fill();
  c.save();c.translate(14,-41);c.rotate(-.58);c.strokeStyle='#c6b27a';c.lineWidth=5;c.beginPath();c.moveTo(0,0);c.lineTo(40,0);c.stroke();c.fillStyle='#ead28f';c.beginPath();c.moveTo(40,0);c.lineTo(58,-6);c.lineTo(54,5);c.closePath();c.fill();c.restore();c.restore();
}

function drawEnemyScreen(c,x,y,e){
  c.save();c.translate(x,y);const hit=e.hitFlash>0;shadow(c,0,4,e.radius*1.05,Math.max(7,e.radius*.35),.38);const s=e.boss?1.35:e.type==='brute'?1.12:e.type==='skitter'?.9:1;c.scale(s,s);
  if(e.type==='skitter'){c.fillStyle=hit?'#d9a270':'#71452f';c.beginPath();c.ellipse(0,-15,e.radius*.9,e.radius*.5,0,0,TAU);c.fill();c.strokeStyle='#876548';c.lineWidth=2;for(let i=-1;i<=1;i++){c.beginPath();c.moveTo(-4,-13+i*3);c.lineTo(-e.radius-10,-2+i*8);c.stroke();c.beginPath();c.moveTo(4,-13+i*3);c.lineTo(e.radius+10,-2+i*8);c.stroke();}}
  else{c.fillStyle='#2c2b2b';c.fillRect(-9,-18,7,20);c.fillRect(3,-18,7,20);c.fillStyle=e.boss?(hit?'#c9b4e3':'#4d3468'):(hit?'#d7b1a6':e.type==='brute'?'#59434b':'#673b3b');c.beginPath();c.moveTo(-e.radius*.62,-50);c.lineTo(e.radius*.62,-50);c.lineTo(e.radius*.72,-20);c.lineTo(e.radius*.35,-10);c.lineTo(-e.radius*.35,-10);c.lineTo(-e.radius*.72,-20);c.closePath();c.fill();c.fillStyle=e.boss?'#c7b3d9':'#d1c3a4';c.beginPath();c.arc(0,-63,Math.max(7,e.radius*.24),0,TAU);c.fill();c.fillStyle=e.boss?'#f06cff':'#ff6159';c.beginPath();c.arc(-4,-64,2,0,TAU);c.arc(4,-64,2,0,TAU);c.fill();}
  if(e.state==='windup'){c.strokeStyle='#ff936f';c.lineWidth=3;c.beginPath();c.ellipse(0,2,e.radius+12,Math.max(8,(e.radius+12)*.35),0,0,TAU);c.stroke();}c.restore();
  if(e.hp<e.maxHp||e.boss){const w=e.boss?90:44;c.fillStyle='#16181a';c.fillRect(x-w/2,y-92,w,5);c.fillStyle=e.boss?'#8f66bd':'#b45149';c.fillRect(x-w/2,y-92,w*clamp(e.hp/e.maxHp,0,1),5);}
}

function drawDropScreen(c,x,y,d){c.save();c.translate(x,y);c.globalAlpha=.26;c.fillStyle=d.item.color;c.beginPath();c.moveTo(-8,0);c.lineTo(-18,-80);c.lineTo(18,-80);c.lineTo(8,0);c.fill();c.globalAlpha=1;c.strokeStyle=d.item.color;c.lineWidth=3;c.shadowBlur=20;c.shadowColor=d.item.color;c.strokeRect(-9,-12,18,18);c.shadowBlur=0;c.restore();}
function drawProjectileScreen(c,x,y){c.save();c.translate(x,y-34);c.shadowBlur=14;c.shadowColor='#f1c05d';c.fillStyle='#f5dfa2';c.beginPath();c.moveTo(12,0);c.lineTo(-7,5);c.lineTo(-2,0);c.lineTo(-7,-5);c.closePath();c.fill();c.shadowBlur=0;c.restore();}
function drawFxScreen(c,game,projectFn){for(const p of game.particles){const s=projectFn(game,p.x,p.y);c.globalAlpha=clamp(p.life/p.max,0,1);c.fillStyle=p.color;c.fillRect(s.x-p.size/2,s.y-28-p.size/2,p.size,p.size);}c.globalAlpha=1;for(const t of game.damageTexts){const s=projectFn(game,t.x,t.y);c.globalAlpha=clamp(t.life/.65,0,1);c.textAlign='center';c.font=`${t.crit?'800 20px':'700 15px'} system-ui`;c.fillStyle=t.player?'#e87068':t.crit?'#ffd86a':'#eee2bc';c.fillText(t.text,s.x,s.y-78);}c.globalAlpha=1;}
function drawVignette(c,w,h){const g=c.createRadialGradient(w/2,h/2,Math.min(w,h)*.22,w/2,h/2,Math.max(w,h)*.72);g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(.65,'rgba(0,0,0,.24)');g.addColorStop(1,'rgba(0,0,0,.72)');c.fillStyle=g;c.fillRect(0,0,w,h);}
function drawFog(c,w,h,time){c.save();for(let i=0;i<4;i++){const x=((time*18+i*270)%(w+360))-180,y=110+i*130;const g=c.createRadialGradient(x,y,20,x,y,150);g.addColorStop(0,'rgba(208,218,230,.07)');g.addColorStop(1,'rgba(208,218,230,0)');c.fillStyle=g;c.fillRect(x-170,y-110,340,220);}c.restore();}
