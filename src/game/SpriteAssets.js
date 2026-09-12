const ASSETS={
  hero:'./assets/sprites/hero.png',
  husk:'./assets/sprites/husk.png',
  skitter:'./assets/sprites/skitter.png',
  brute:'./assets/sprites/brute.png',
  boss:'./assets/sprites/boss.png'
};

export function loadSpriteAssets(){
  const images={};
  const ready={};
  for(const [key,src] of Object.entries(ASSETS)){
    const img=new Image();
    ready[key]=false;
    img.onload=()=>{ready[key]=true;};
    img.onerror=()=>{ready[key]=false;};
    img.src=src;
    images[key]=img;
  }
  return {images,ready};
}

export function actorSpriteKey(actor,kind){
  if(kind==='player')return 'hero';
  if(actor.boss)return 'boss';
  if(actor.type==='skitter')return 'skitter';
  if(actor.type==='brute')return 'brute';
  return 'husk';
}
