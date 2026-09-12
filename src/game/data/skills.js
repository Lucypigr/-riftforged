export const SKILLS = [
  { id:'fury', icon:'⚔', name:'飢渴之刃', text:'基礎傷害 +25%。', apply:p=>p.damage*=1.25 },
  { id:'haste', icon:'✦', name:'獵殺節奏', text:'攻擊速度 +20%。', apply:p=>p.attackRate*=.8 },
  { id:'vitality', icon:'♥', name:'血肉重鑄', text:'最大生命 +35，並立即回復 35。', apply:p=>{p.maxHp+=35;p.hp=Math.min(p.maxHp,p.hp+35)} },
  { id:'crit', icon:'◆', name:'致命裂痕', text:'暴擊率 +10%。', apply:p=>p.crit=Math.min(.75,p.crit+.1) },
  { id:'multishot', icon:'⋔', name:'分裂彈幕', text:'額外發射 2 枚投射物。', apply:p=>p.projectiles=Math.min(7,p.projectiles+2) },
  { id:'pierce', icon:'➶', name:'穿魂', text:'投射物可多穿透 1 名敵人。', apply:p=>p.pierce+=1 },
  { id:'magnet', icon:'◎', name:'掠奪者本能', text:'拾取範圍 +60%。', apply:p=>p.pickupRadius*=1.6 },
  { id:'dash', icon:'↯', name:'虛空步', text:'閃避冷卻 -25%。', apply:p=>p.dashCooldown=Math.max(.35,p.dashCooldown*.75) },
  { id:'leech', icon:'☽', name:'赤色契約', text:'造成傷害時回復 2% 傷害量。', apply:p=>p.leech+=.02 }
];
