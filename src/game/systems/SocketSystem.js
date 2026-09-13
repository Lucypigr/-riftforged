const LAYOUTS_BY_COUNT = {
  2: [[2],[1,1]],
  3: [[3],[2,1]],
  4: [[4],[3,1],[2,2]],
  5: [[5],[4,1],[3,2]],
  6: [[6],[5,1],[4,2],[3,3]],
};

const SOCKET_RANGE = {
  common:[2,3],
  magic:[2,4],
  rare:[3,5],
  legendary:[4,6],
};

export const STARTER_SOCKET_LAYOUT=[4];

export function rollSocketLayout(rarity='common',rng=Math.random){
  const [min,max]=SOCKET_RANGE[rarity]||SOCKET_RANGE.common;
  const count=min+Math.floor(rng()*(max-min+1));
  const variants=LAYOUTS_BY_COUNT[count]||[[count]];
  const pick=Math.min(variants.length-1,Math.floor(rng()*variants.length));
  return [...variants[pick]];
}

export function createSocketsFromLayout(layout=STARTER_SOCKET_LAYOUT){
  const sockets=[];
  let id=0;
  layout.forEach((size,groupIndex)=>{
    const linkGroup=size>1?groupIndex:null;
    for(let i=0;i<size;i++)sockets.push({id:`s${id++}`,linkGroup,gemId:null});
  });
  return sockets;
}

export function describeSocketLayout(layout=[]){
  if(!layout.length)return '無孔洞';
  return layout.map(size=>size>1?`${size}連`:`1孔`).join(' + ');
}

export function socketCount(layout=[]){return layout.reduce((sum,size)=>sum+size,0);}
