export const BASE_ITEMS = [
  {slot:'weapon',name:'鏽蝕短弩',base:{damage:5}},
  {slot:'weapon',name:'墓銀投矛',base:{damage:8}},
  {slot:'armor',name:'裂紋胸甲',base:{maxHp:18}},
  {slot:'armor',name:'黑曜護衣',base:{maxHp:12}},
  {slot:'charm',name:'封印骨符',base:{crit:.02}},
  {slot:'charm',name:'荒火墜飾',base:{damage:3}}
];
export const AFFIXES = [
  {name:'兇暴',stat:'damage',value:[3,8],format:v=>`+${v} 傷害`},
  {name:'迅捷',stat:'attackSpeed',value:[.04,.12],format:v=>`+${Math.round(v*100)}% 攻速`},
  {name:'精準',stat:'crit',value:[.03,.08],format:v=>`+${Math.round(v*100)}% 暴擊`},
  {name:'巨人',stat:'maxHp',value:[12,32],format:v=>`+${v} 最大生命`},
  {name:'掠奪',stat:'pickup',value:[18,55],format:v=>`+${v} 拾取距離`}
];
