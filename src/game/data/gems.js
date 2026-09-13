export const GEM_COLORS = {
  red: '#ef6658',
  green: '#53d49a',
  blue: '#65a9ff',
};

export const GEMS = [
  { id:'crimson_bolt', color:'red', kind:'active', icon:'◆', name:'緋紅裂矢', text:'主動寶石：發射高傷害裂矢。', tags:['projectile'], active:{ damageMultiplier:1.12, projectileSpeedMultiplier:1, projectileColor:'#ff8b68' } },
  { id:'verdant_volley', color:'green', kind:'active', icon:'✦', name:'翠綠疾矢', text:'主動寶石：傷害較低，但額外發射 1 枚投射物。', tags:['projectile'], active:{ damageMultiplier:.86, extraProjectiles:1, projectileSpeedMultiplier:1.12, projectileColor:'#71e7ab' } },
  { id:'azure_lance', color:'blue', kind:'active', icon:'◇', name:'蒼藍霜槍', text:'主動寶石：投射物較快，天生穿透 1 名敵人。', tags:['projectile'], active:{ damageMultiplier:.98, extraPierce:1, projectileSpeedMultiplier:1.2, projectileColor:'#83bdff' } },
  { id:'crimson_force', color:'red', kind:'support', icon:'⬢', name:'緋紅猛攻', text:'連線輔助：更多傷害，但略微降低攻速。', tags:['projectile'], support:{ damageMultiplier:1.32, attackRateMultiplier:1.08 } },
  { id:'verdant_chain', color:'green', kind:'support', icon:'⌁', name:'翠綠連鎖', text:'連線輔助：命中後跳向附近敵人 1 次。', tags:['projectile'], support:{ extraChain:1, damageMultiplier:.9 } },
  { id:'verdant_multishot', color:'green', kind:'support', icon:'⋔', name:'翠綠多重', text:'連線輔助：額外發射 2 枚投射物。', tags:['projectile'], support:{ extraProjectiles:2, damageMultiplier:.84 } },
  { id:'azure_pierce', color:'blue', kind:'support', icon:'➶', name:'蒼藍穿透', text:'連線輔助：額外穿透 2 名敵人。', tags:['projectile'], support:{ extraPierce:2, damageMultiplier:.94 } },
  { id:'azure_haste', color:'blue', kind:'support', icon:'↯', name:'蒼藍迅捷', text:'連線輔助：攻擊更快，但單次傷害稍低。', tags:['projectile'], support:{ attackRateMultiplier:.82, damageMultiplier:.92 } },
  { id:'crimson_aura', color:'red', kind:'aura', icon:'●', name:'緋紅生息', text:'光環寶石：每秒回復 1.4% 最大生命。', aura:{ regenMaxHpPerSecond:.014 } },
  { id:'verdant_aura', color:'green', kind:'aura', icon:'●', name:'翠綠狩獵', text:'光環寶石：攻擊速度提高 10%。', aura:{ attackRateMultiplier:.9 } },
  { id:'azure_aura', color:'blue', kind:'aura', icon:'●', name:'蒼藍專注', text:'光環寶石：暴擊率提高 6%。', aura:{ critBonus:.06 } },
];

export const GEM_BY_ID = Object.fromEntries(GEMS.map(gem => [gem.id, gem]));

export function rollGem(random = Math.random) {
  const r=random();
  const kind=r<.34?'active':r<.8?'support':'aura';
  const pool=GEMS.filter(gem=>gem.kind===kind);
  return pool[Math.floor(random()*pool.length)%pool.length];
}
