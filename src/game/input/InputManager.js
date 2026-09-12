export class InputManager{
  constructor(canvas){
    this.keys=new Set();this.mouse={x:0,y:0,down:false};this.move={x:0,y:0};this.attack=false;this.dash=false;
    addEventListener('keydown',e=>{this.keys.add(e.code);if(['Space','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.code))e.preventDefault();if(e.code==='ShiftLeft'||e.code==='ShiftRight')this.dash=true;});
    addEventListener('keyup',e=>this.keys.delete(e.code));
    canvas.addEventListener('pointermove',e=>{this.mouse.x=e.clientX;this.mouse.y=e.clientY;});
    canvas.addEventListener('pointerdown',e=>{if(e.pointerType==='mouse'&&e.button===0){this.mouse.down=true;this.attack=true;}});
    addEventListener('pointerup',e=>{if(e.pointerType==='mouse'){this.mouse.down=false;this.attack=false;}});
    this.bindMobile();
  }
  bindMobile(){
    const joy=document.querySelector('#joystick'),knob=document.querySelector('#joystickKnob');
    if(joy){let active=null;const update=e=>{const r=joy.getBoundingClientRect();let dx=e.clientX-(r.left+r.width/2),dy=e.clientY-(r.top+r.height/2);const len=Math.hypot(dx,dy)||1;const max=36;if(len>max){dx=dx/len*max;dy=dy/len*max;}this.move={x:dx/max,y:dy/max};knob.style.transform=`translate(${dx}px,${dy}px)`;};joy.addEventListener('pointerdown',e=>{active=e.pointerId;joy.setPointerCapture(active);update(e)});joy.addEventListener('pointermove',e=>{if(e.pointerId===active)update(e)});const end=e=>{if(e.pointerId===active){active=null;this.move={x:0,y:0};knob.style.transform=''}};joy.addEventListener('pointerup',end);joy.addEventListener('pointercancel',end);}
    const a=document.querySelector('#attackButton');if(a){a.addEventListener('pointerdown',e=>{e.preventDefault();this.attack=true});a.addEventListener('pointerup',()=>this.attack=false);a.addEventListener('pointercancel',()=>this.attack=false)}
    const d=document.querySelector('#dashButton');if(d)d.addEventListener('pointerdown',e=>{e.preventDefault();this.dash=true});
  }
  movement(){let x=this.move.x,y=this.move.y;if(this.keys.has('KeyA')||this.keys.has('ArrowLeft'))x-=1;if(this.keys.has('KeyD')||this.keys.has('ArrowRight'))x+=1;if(this.keys.has('KeyW')||this.keys.has('ArrowUp'))y-=1;if(this.keys.has('KeyS')||this.keys.has('ArrowDown'))y+=1;const l=Math.hypot(x,y);return l>1?{x:x/l,y:y/l}:{x,y};}
  consumeDash(){const d=this.dash;this.dash=false;return d;}
}
