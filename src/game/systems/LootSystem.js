import { BASE_ITEMS, AFFIXES } from '../data/items.js';

export const RARITIES = {
  common:{name:'普通',color:'#b8b3a6',affixes:0,weight:60},
  magic:{name:'魔法',color:'#5d96d6',affixes:1,weight:28},
  rare:{name:'稀有',color:'#d8b552',affixes:2,weight:10},
  legendary:{name:'傳說',color:'#c96c32',affixes:3,weight:2}
};

export function weightedRarity(rng=Math.random){
  const roll=rng()*100; let acc=0;
  for(const [key,r] of Object.entries(RARITIES)){acc+=r.weight;if(roll<=acc)return key;}
  return 'common';
}

export function rollItem(level=1,rng=Math.random,forcedRarity=null){
  const rarity=forcedRarity || weightedRarity(rng);
  const base=BASE_ITEMS[Math.floor(rng()*BASE_ITEMS.length)];
  const count=RARITIES[rarity].affixes;
  const pool=[...AFFIXES];
  const affixes=[];
  for(let i=0;i<count&&pool.length;i++){
    const idx=Math.floor(rng()*pool.length); const a=pool.splice(idx,1)[0];
    const min=a.value[0],max=a.value[1];
    const raw=min+(max-min)*rng();
    const value=Number.isInteger(min)&&Number.isInteger(max)?Math.round(raw):Math.round(raw*100)/100;
    affixes.push({...a,value,text:a.format(value)});
  }
  const prefix=affixes[0]?.name ? `${affixes[0].name}的` : '';
  return {id:`${Date.now()}-${Math.floor(rng()*1e7)}`,level,slot:base.slot,baseName:base.name,name:`${prefix}${base.name}`,rarity,color:RARITIES[rarity].color,base:structuredClone(base.base),affixes};
}

export function itemPower(item){
  let p=0;
  for(const v of Object.values(item.base)) p+=typeof v==='number'?v:0;
  for(const a of item.affixes) p += a.stat==='crit'||a.stat==='attackSpeed'?a.value*100:a.value;
  return Math.round(p*10)/10;
}
