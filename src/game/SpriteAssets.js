const ASSETS={
  hero:'./assets/sprites/hero.png',
  husk:'./assets/sprites/husk.png',
  skitter:'./assets/sprites/skitter.png',
  brute:'./assets/sprites/brute.png',
  boss:'./assets/sprites/boss.png'
};

function colorDistance(a,b){
  const dr=a[0]-b[0],dg=a[1]-b[1],db=a[2]-b[2];
  return Math.sqrt(dr*dr+dg*dg+db*db);
}

function preprocessSprite(img){
  const c=document.createElement('canvas');
  c.width=img.naturalWidth;
  c.height=img.naturalHeight;
  const ctx=c.getContext('2d',{willReadFrequently:true});
  ctx.drawImage(img,0,0);

  let data;
  try{data=ctx.getImageData(0,0,c.width,c.height);}catch{return img;}
  const p=data.data;
  const sample=(x,y)=>{
    const i=(y*c.width+x)*4;
    return [p[i],p[i+1],p[i+2]];
  };
  const corners=[sample(0,0),sample(c.width-1,0),sample(0,c.height-1),sample(c.width-1,c.height-1)];

  let hasNativeAlpha=false;
  for(let i=3;i<p.length;i+=4){
    if(p[i]<250){hasNativeAlpha=true;break;}
  }
  if(hasNativeAlpha)return c;

  // AI generated sprites sometimes arrive with a dark studio backdrop instead of alpha.
  // Remove only border-connected, dark/near-corner pixels so red capes and bright metal survive.
  const seen=new Uint8Array(c.width*c.height);
  const queue=[];
  const push=(x,y)=>{
    if(x<0||y<0||x>=c.width||y>=c.height)return;
    const q=y*c.width+x;
    if(seen[q])return;
    seen[q]=1;queue.push(q);
  };
  for(let x=0;x<c.width;x++){push(x,0);push(x,c.height-1);}
  for(let y=0;y<c.height;y++){push(0,y);push(c.width-1,y);}

  while(queue.length){
    const q=queue.pop(),x=q%c.width,y=(q/c.width)|0,i=q*4;
    const rgb=[p[i],p[i+1],p[i+2]];
    const max=Math.max(...rgb),min=Math.min(...rgb);
    const nearest=Math.min(...corners.map(k=>colorDistance(rgb,k)));
    const dark=max<68;
    const cornerLike=nearest<72 && max<135;
    const muted=(max-min)<24 && max<95;
    if(!(dark||cornerLike||muted))continue;
    p[i+3]=0;
    push(x+1,y);push(x-1,y);push(x,y+1);push(x,y-1);
  }

  ctx.putImageData(data,0,0);
  return c;
}

export function loadSpriteAssets(){
  const images={},processed={},ready={};
  for(const [key,src] of Object.entries(ASSETS)){
    const img=new Image();
    ready[key]=false;
    img.onload=()=>{
      processed[key]=preprocessSprite(img);
      ready[key]=true;
    };
    img.onerror=()=>{ready[key]=false;};
    img.src=src;
    images[key]=img;
  }
  return {images,processed,ready};
}

export function actorSpriteKey(actor,kind){
  if(kind==='player')return 'hero';
  if(actor.boss)return 'boss';
  if(actor.type==='skitter')return 'skitter';
  if(actor.type==='brute')return 'brute';
  return 'husk';
}
