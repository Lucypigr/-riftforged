import { GEM_BY_ID, GEM_COLORS } from '../data/gems.js';

const TAU=Math.PI*2,ISO_X=.72,ISO_Y=.36;
const project=(game,x,y)=>({x:game.view.w/2+((x-game.player.x)-(y-game.player.y))*ISO_X,y:game.view.h/2+((x-game.player.x)+(y-game.player.y))*ISO_Y});

export function mountGemUI(game,handlers){
  if(document.querySelector('#gemOverlay'))return;
  const css=document.createElement('link');css.rel='stylesheet';css.href='./src/game/ui/gems.css';css.id='gem-ui-css';document.head.appendChild(css);
  const button=document.createElement('button');button.id='gemButton';button.className='gem-button';button.textContent='寶石';document.body.appendChild(button);
  const overlay=document.createElement('section');overlay.id='gemOverlay';overlay.className='overlay hidden';overlay.innerHTML=`<div class="gem-panel"><div class="gem-head"><div><p class="eyebrow">RIFT SOCKET MATRIX</p><h2>裂隙寶石</h2></div><button id="closeGemOverlay">✕</button></div><p class="gem-help">孔洞與連線現在由武器／護甲決定。切換孔洞裝備會把已安裝寶石安全退回寶石背包；點背包寶石，再點孔洞即可安裝。只有同一連線組的相容輔助寶石會強化主動技能；光環不需連線。</p><div class="socket-source"><div><span class="eyebrow">目前孔洞裝備</span><strong id="socketSourceName">裂隙基座</strong></div><span id="socketSourceLayout">4連</span></div><div class="socket-gear"><div class="socket-title"><span>可用孔洞裝備</span><span>武器／護甲</span></div><div id="socketGearGrid" class="socket-gear-grid"></div></div><div class="gem-layout"><div class="socket-box"><div class="socket-title"><span>裝備孔洞</span><span>觸控可用</span></div><div id="socketRows"></div><div id="gemStatus" class="gem-status"></div></div><div class="gem-stash"><div class="socket-title"><span>寶石背包</span><span id="gemCount">0</span></div><div id="gemStashGrid" class="gem-stash-grid"></div></div></div></div>`;document.body.appendChild(overlay);
  button.onclick=()=>toggleGemOverlay(game,true,handlers);overlay.querySelector('#closeGemOverlay').onclick=()=>toggleGemOverlay(game,false,handlers);
  renderGemUI(game,handlers);updateSkillbar(game,handlers.buildLoadout);
}

function toggleGemOverlay(game,open,handlers){
  const overlay=document.querySelector('#gemOverlay');if(!overlay)return;
  if(open){renderGemUI(game,handlers);overlay.classList.remove('hidden');game.paused=true;}
  else{overlay.classList.add('hidden');if(game.ui.choice.classList.contains('hidden')&&game.ui.death.classList.contains('hidden')&&game.ui.inv.classList.contains('hidden'))game.paused=false;}
}

function renderSocketGear(game,handlers){
  const grid=document.querySelector('#socketGearGrid'),name=document.querySelector('#socketSourceName'),layout=document.querySelector('#socketSourceLayout');if(!grid)return;
  name.textContent=game.gemState.socketSourceName||'裂隙基座';layout.textContent=handlers.describeLayout(game.gemState.socketLayout);
  const items=game.player.inventory.filter(item=>item.socketLayout?.length);
  grid.innerHTML='';
  if(!items.length){grid.innerHTML='<div class="socket-gear-empty">尚未取得有孔洞的武器或護甲。起始裂隙基座提供 4 連。</div>';return;}
  for(const item of items){const b=document.createElement('button');b.className='socket-gear-card'+(game.gemState.socketSourceId===item.id?' equipped':'');b.style.setProperty('--rarity',item.color);b.innerHTML=`<strong>${item.name}</strong><span>${handlers.describeLayout(item.socketLayout)}</span><small>${game.gemState.socketSourceId===item.id?'目前使用':'點擊套用孔洞'}</small>`;b.onclick=()=>{handlers.equipFrame(game.gemState,item);renderGemUI(game,handlers);updateSkillbar(game,handlers.buildLoadout);};grid.appendChild(b);}
}

export function renderGemUI(game,handlers){
  const rows=document.querySelector('#socketRows'),stash=document.querySelector('#gemStashGrid'),count=document.querySelector('#gemCount'),status=document.querySelector('#gemStatus');if(!rows||!stash)return;
  renderSocketGear(game,handlers);
  rows.innerHTML='';
  const groups=[];for(const socket of game.gemState.sockets)if(!groups.includes(socket.linkGroup))groups.push(socket.linkGroup);
  for(const group of groups){
    const sockets=game.gemState.sockets.filter(s=>s.linkGroup===group);if(!sockets.length)continue;
    const row=document.createElement('div');row.className='socket-row';
    sockets.forEach((socket,i)=>{if(i&&group!=null){const l=document.createElement('span');l.className='socket-link';row.appendChild(l);}const gem=GEM_BY_ID[socket.gemId];const b=document.createElement('button');b.className='gem-socket'+(game.gemState.activeSocketId===socket.id?' active-socket':'');b.title=gem?.name||'空孔洞';
      if(gem){const color=GEM_COLORS[gem.color];b.style.setProperty('--gem',color);b.innerHTML=`<span class="gem-core" style="background:${color}22;color:${color};border:2px solid ${color}">${gem.icon}</span><small>${gem.name}</small>`;}else b.innerHTML='<span class="gem-core" style="color:#625d54;border:2px solid #48443e">○</span><small>空孔</small>';
      b.onclick=()=>{const selected=game.gemState.selectedGemId;if(selected){handlers.install(game.gemState,socket.id,selected,game.gemState.selectedStashIndex);game.gemState.selectedGemId=null;game.gemState.selectedStashIndex=null;}else if(gem?.kind==='active'&&game.gemState.activeSocketId!==socket.id)game.gemState.activeSocketId=socket.id;else if(gem)handlers.remove(game.gemState,socket.id);renderGemUI(game,handlers);updateSkillbar(game,handlers.buildLoadout);};row.appendChild(b);});
    rows.appendChild(row);
  }
  stash.innerHTML='';count.textContent=`${game.gemState.stash.length} 顆`;
  game.gemState.stash.forEach((gemId,index)=>{const gem=GEM_BY_ID[gemId];if(!gem)return;const b=document.createElement('button');b.className='gem-card'+(game.gemState.selectedStashIndex===index?' selected':'');b.style.setProperty('--gem',GEM_COLORS[gem.color]);b.innerHTML=`<span class="gem-kind">${gem.kind}</span><b>${gem.icon} ${gem.name}</b><small>${gem.text}</small>`;b.onclick=()=>{const same=game.gemState.selectedStashIndex===index;game.gemState.selectedGemId=same?null:gemId;game.gemState.selectedStashIndex=same?null:index;renderGemUI(game,handlers);};stash.appendChild(b);});
  const loadout=handlers.buildLoadout(game.gemState);status.textContent=loadout.active?`目前主動：${loadout.active.name}｜有效輔助：${loadout.supports.map(g=>g.name).join('、')||'無'}｜光環：${loadout.auras.map(g=>g.name).join('、')||'無'}`:'目前沒有主動寶石，角色無法使用寶石技能。';
}

export function updateSkillbar(game,buildLoadout){const loadout=buildLoadout(game.gemState),slot=document.querySelector('.skillbar .skill-slot');if(!slot)return;const title=slot.querySelector('b'),small=slot.querySelector('small');if(title)title.textContent=loadout.active?.name||'未裝技能寶石';if(small)small.textContent=loadout.active?`${loadout.supports.length} 連線輔助`:'寶石';}
export function toastGem(game,gem){const n=document.createElement('div');n.className='loot-toast';n.style.setProperty('--rarity',GEM_COLORS[gem.color]);n.innerHTML=`<b style="color:${GEM_COLORS[gem.color]}">寶石</b> · ${gem.name}`;game.ui.feed.prepend(n);while(game.ui.feed.children.length>5)game.ui.feed.lastElementChild.remove();setTimeout(()=>n.remove(),4200);}

export function drawGemVisuals(game){const c=game.ctx;for(const q of game.projectiles){if(!q.gemColor)continue;const s=project(game,q.x,q.y);c.save();c.globalAlpha=.72;c.shadowBlur=18;c.shadowColor=q.gemColor;c.fillStyle=q.gemColor;c.beginPath();c.arc(s.x,s.y-34,3.5,0,TAU);c.fill();c.restore();}for(const drop of game.gemDrops){const gem=GEM_BY_ID[drop.gemId],color=GEM_COLORS[gem.color],s=project(game,drop.x,drop.y),pulse=1+Math.sin(drop.pulse)*.12;c.save();c.translate(s.x,s.y);c.scale(pulse,pulse);c.globalAlpha=.18;c.fillStyle=color;c.beginPath();c.moveTo(-11,2);c.lineTo(-24,-92);c.lineTo(24,-92);c.lineTo(11,2);c.fill();c.globalAlpha=1;c.shadowBlur=24;c.shadowColor=color;c.fillStyle='#0d0f12';c.strokeStyle=color;c.lineWidth=3;c.beginPath();c.moveTo(0,-26);c.lineTo(11,-16);c.lineTo(7,-2);c.lineTo(-7,-2);c.lineTo(-11,-16);c.closePath();c.fill();c.stroke();c.fillStyle=color;c.font='900 12px system-ui';c.textAlign='center';c.fillText(gem.icon,0,-10);c.restore();}}
