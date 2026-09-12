import { CONFIG } from './config.js';

const TAU = Math.PI * 2;
const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));

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

export function enableIsoMode(game){
  const rawMove = game.input.movement.bind(game.input);
  game.input.movement = ()=>{
    const m=rawMove();
    const k=Math.SQRT1_2;
    return {x:(m.x+m.y)*k,y:(m.y-m.x)*k};
  };

  const props=seedProps();
  const oldDrawEnemyBar=game.drawEnemyBar?.bind(game);

  game.draw = function(){
    const c=this.ctx,w=this.view.w,h=this.view.h;
    const shakeX=(Math.random()-.5)*this.camera.shake;
    const shakeY=(Math.random()-.5)*this.camera.shake;
    c.clearRect(0,0,w,h);
    c.fillStyle='#080a0d';c.fillRect(0,0,w,h);

    c.save();
    c.translate(w/2+shakeX,h/2+shakeY);
    c.transform(.72,.36,-.72,.36,0,0);
    c.translate(-this.player.x,-this.player.y);
    drawIsoGround(c,this,props);

    const renderables=[];
    for(const p of props) renderables.push({y:p.y,kind:'prop',obj:p});
    for(const e of this.enemies) renderables.push({y:e.y,kind:'enemy',obj:e});
    for(const d of this.drops) renderables.push({y:d.y,kind:'drop',obj:d});
    renderables.push({y:this.player.y,kind:'player',obj:this.player});
    renderables.sort((a,b)=>a.y-b.y);

    for(const r of renderables){
      if(r.kind==='prop') drawProp(c,r.obj,this.time);
      else if(r.kind==='enemy') drawIsoEnemy(c,r.obj,this.time);
      else if(r.kind==='drop') drawIsoDrop(c,r.obj,this.time);
      else drawIsoPlayer(c,r.obj,this.time);
    }

    for(const q of this.projectiles) drawProjectile(c,q);
    drawFx(c,this);
    c.restore();

    drawVignette(c,w,h);
    drawFog(c,w,h,this.time);
  };

  game.drawEnemyBar = function(c,e){
    if(oldDrawEnemyBar) oldDrawEnemyBar(c,e);
  };
}

function drawIsoGround(c,game,props){
  c.fillStyle='#242323';
  c.fillRect(0,0,CONFIG.world.width,CONFIG.world.height);

  const tile=96;
  for(let y=0;y<CONFIG.world.height;y+=tile){
    for(let x=0;x<CONFIG.world.width;x+=tile){
      const n=((x/tile)*13+(y/tile)*7)%5;
      c.fillStyle=['#393735','#343331','#302f2e','#3d3a37','#2d2d2c'][n];
      c.fillRect(x+2,y+2,tile-4,tile-4);
      c.strokeStyle='rgba(95,88,78,.38)';c.lineWidth=2;c.strokeRect(x+3,y+3,tile-6,tile-6);
      if(n===1||n===4){
        c.strokeStyle='rgba(18,18,19,.45)';c.lineWidth=2;c.beginPath();
        c.moveTo(x+18,y+24);c.lineTo(x+54,y+45);c.lineTo(x+72,y+39);c.stroke();
      }
    }
  }

  for(let i=0;i<34;i++){
    const x=160+(i*281)%1880,y=110+(i*193)%1120;
    c.fillStyle='rgba(104,18,18,.16)';
    c.beginPath();c.ellipse(x,y,18+(i%4)*4,10+(i%3)*3,(i%5)*.3,0,TAU);c.fill();
  }

  c.strokeStyle='rgba(31,26,23,.8)';c.lineWidth=10;c.strokeRect(28,28,CONFIG.world.width-56,CONFIG.world.height-56);
}

function drawProp(c,p,time){
  c.save();c.translate(p.x,p.y);c.scale(p.scale,p.scale);
  if(p.type==='brazier'){
    c.fillStyle='#23262a';c.fillRect(-10,-8,20,26);c.fillRect(-18,14,36,8);
    const g=c.createRadialGradient(0,-28,2,0,-28,44);g.addColorStop(0,'rgba(255,230,145,.95)');g.addColorStop(.35,'rgba(255,138,46,.8)');g.addColorStop(1,'rgba(255,89,22,0)');
    c.fillStyle=g;c.beginPath();c.arc(0,-28,42,0,TAU);c.fill();
    c.fillStyle='#ff9b39';c.beginPath();c.moveTo(-8,-10);c.quadraticCurveTo(-4,-28+Math.sin(time*8+p.x)*4,0,-42);c.quadraticCurveTo(7,-25,8,-10);c.fill();
  }else if(p.type==='pillar'){
    c.fillStyle='#4a4947';c.fillRect(-18,-68,36,82);c.fillStyle='#66615a';c.fillRect(-25,-72,50,12);c.fillRect(-25,10,50,10);
    c.fillStyle='#2d2d2d';c.beginPath();c.moveTo(-18,-68);c.lineTo(6,-84);c.lineTo(20,-61);c.lineTo(8,-54);c.closePath();c.fill();
  }else if(p.type==='banner'){
    c.strokeStyle='#3b3938';c.lineWidth=6;c.beginPath();c.moveTo(0,-96);c.lineTo(0,28);c.stroke();
    c.fillStyle='#5d1519';c.beginPath();c.moveTo(4,-88);c.lineTo(58,-80);c.lineTo(46,-12);c.lineTo(18,18);c.lineTo(4,10);c.closePath();c.fill();
  }else if(p.type==='statue'){
    c.fillStyle='#55575a';c.beginPath();c.moveTo(0,-70);c.lineTo(22,-30);c.lineTo(18,28);c.lineTo(-18,28);c.lineTo(-22,-30);c.closePath();c.fill();
    c.fillRect(-32,28,64,20);
  }else if(p.type==='grass'){
    c.strokeStyle='rgba(92,109,72,.46)';c.lineWidth=2;
    for(let i=0;i<5;i++){c.beginPath();c.moveTo(i*3-6,4);c.lineTo(i*4-10,-8-(i%3)*5);c.stroke();}
  }else{
    c.fillStyle='#4a4948';c.rotate((p.x%17)*.08);c.fillRect(-18,-8,36,16);c.fillStyle='#62615e';c.fillRect(-11,-5,22,5);
  }
  c.restore();
}

function drawIsoPlayer(c,p,time){
  c.save();c.translate(p.x,p.y);c.rotate(p.facing||0);
  c.fillStyle='rgba(0,0,0,.38)';c.beginPath();c.ellipse(0,18,25,13,0,0,TAU);c.fill();
  c.fillStyle='#64131a';c.beginPath();c.moveTo(-8,2);c.lineTo(-30,18);c.lineTo(-18,36);c.lineTo(-2,18);c.closePath();c.fill();
  c.fillStyle='#30343a';c.beginPath();c.moveTo(-13,-10);c.lineTo(12,-10);c.lineTo(18,9);c.lineTo(0,25);c.lineTo(-17,9);c.closePath();c.fill();
  c.fillStyle='#7b766a';c.fillRect(-3,-5,6,26);
  c.fillStyle='#3e454e';c.beginPath();c.arc(0,-19,12,0,TAU);c.fill();
  c.fillStyle='#b5a98b';c.beginPath();c.moveTo(-7,-18);c.lineTo(0,-31);c.lineTo(7,-18);c.lineTo(4,-10);c.lineTo(-4,-10);c.closePath();c.fill();
  c.fillStyle='#e7d5a2';c.beginPath();c.arc(-3,-19,1.5,0,TAU);c.arc(3,-19,1.5,0,TAU);c.fill();
  c.strokeStyle='#d6c282';c.lineWidth=4;c.beginPath();c.moveTo(12,0);c.lineTo(54,0);c.stroke();
  c.fillStyle='#f2d88f';c.beginPath();c.moveTo(54,0);c.lineTo(66,-5);c.lineTo(66,5);c.closePath();c.fill();
  c.restore();
}

function drawIsoEnemy(c,e,time){
  c.save();c.translate(e.x,e.y);c.rotate(e.facing||0);
  c.fillStyle='rgba(0,0,0,.34)';c.beginPath();c.ellipse(0,e.radius*.72,e.radius*.9,e.radius*.42,0,0,TAU);c.fill();
  const hit=e.hitFlash>0;
  if(e.type==='skitter'){
    c.fillStyle=hit?'#d9a270':'#71452f';c.beginPath();c.ellipse(0,0,e.radius*.9,e.radius*.55,0,0,TAU);c.fill();
    c.strokeStyle='#876548';c.lineWidth=2;for(let i=-1;i<=1;i++){c.beginPath();c.moveTo(-5,i*5);c.lineTo(-e.radius-10,i*9-8);c.stroke();c.beginPath();c.moveTo(5,i*5);c.lineTo(e.radius+10,i*9+8);c.stroke();}
  }else{
    c.fillStyle=e.boss?(hit?'#c9b4e3':'#4d3468'):(hit?'#d7b1a6':e.type==='brute'?'#59434b':'#673b3b');
    c.beginPath();c.moveTo(-e.radius*.7,-e.radius*.2);c.lineTo(-e.radius*.3,-e.radius);c.lineTo(e.radius*.35,-e.radius);c.lineTo(e.radius*.75,-e.radius*.15);c.lineTo(e.radius*.48,e.radius*.9);c.lineTo(-e.radius*.48,e.radius*.9);c.closePath();c.fill();
    c.fillStyle='#d1c3a4';c.beginPath();c.arc(0,-e.radius*.68,Math.max(6,e.radius*.22),0,TAU);c.fill();
    c.fillStyle=e.boss?'#f06cff':'#ff6159';c.beginPath();c.arc(-4,-e.radius*.7,2,0,TAU);c.arc(4,-e.radius*.7,2,0,TAU);c.fill();
  }
  if(e.state==='windup'){c.strokeStyle='#ff936f';c.lineWidth=3;c.beginPath();c.arc(0,0,e.radius+10,0,TAU);c.stroke();}
  c.restore();

  if(e.hp<e.maxHp||e.boss){
    const w=e.boss?90:44;c.fillStyle='#16181a';c.fillRect(e.x-w/2,e.y-e.radius-18,w,5);c.fillStyle=e.boss?'#8f66bd':'#b45149';c.fillRect(e.x-w/2,e.y-e.radius-18,w*clamp(e.hp/e.maxHp,0,1),5);
  }
}

function drawIsoDrop(c,d,time){
  const bob=Math.sin(d.t*5)*4;
  c.save();c.translate(d.x,d.y+bob);
  c.strokeStyle=d.item.color;c.lineWidth=3;c.shadowBlur=20;c.shadowColor=d.item.color;c.strokeRect(-9,-9,18,18);c.shadowBlur=0;c.restore();
  c.save();c.globalAlpha=.28;c.fillStyle=d.item.color;c.beginPath();c.moveTo(d.x-10,d.y);c.lineTo(d.x-26,d.y-88);c.lineTo(d.x+26,d.y-88);c.lineTo(d.x+10,d.y);c.fill();c.restore();
}

function drawProjectile(c,q){
  c.save();c.translate(q.x,q.y);const a=Math.atan2(q.vy,q.vx);c.rotate(a);c.shadowBlur=14;c.shadowColor='#f1c05d';c.fillStyle='#f5dfa2';c.beginPath();c.moveTo(12,0);c.lineTo(-7,5);c.lineTo(-2,0);c.lineTo(-7,-5);c.closePath();c.fill();c.shadowBlur=0;c.restore();
}

function drawFx(c,game){
  for(const p of game.particles){c.globalAlpha=clamp(p.life/p.max,0,1);c.fillStyle=p.color;c.fillRect(p.x-p.size/2,p.y-p.size/2,p.size,p.size);}c.globalAlpha=1;
  for(const t of game.damageTexts){c.globalAlpha=clamp(t.life/.65,0,1);c.textAlign='center';c.font=`${t.crit?'800 20px':'700 15px'} system-ui`;c.fillStyle=t.player?'#e87068':t.crit?'#ffd86a':'#eee2bc';c.fillText(t.text,t.x,t.y);}c.globalAlpha=1;
}

function drawVignette(c,w,h){const g=c.createRadialGradient(w/2,h/2,Math.min(w,h)*.22,w/2,h/2,Math.max(w,h)*.72);g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(.65,'rgba(0,0,0,.24)');g.addColorStop(1,'rgba(0,0,0,.72)');c.fillStyle=g;c.fillRect(0,0,w,h);}

function drawFog(c,w,h,time){
  c.save();
  for(let i=0;i<4;i++){
    const x=((time*18+i*270)%(w+360))-180,y=110+i*130;
    const g=c.createRadialGradient(x,y,20,x,y,150);g.addColorStop(0,'rgba(208,218,230,.07)');g.addColorStop(1,'rgba(208,218,230,0)');
    c.fillStyle=g;c.fillRect(x-170,y-110,340,220);
  }
  c.restore();
}
