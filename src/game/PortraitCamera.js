export const PORTRAIT_EXTRA_SCALE = 0.70;

export function portraitExtraScaleForView(view){
  return view?.h > view?.w ? PORTRAIT_EXTRA_SCALE : 1;
}

export function enablePortraitCameraPullback(game){
  const baseDraw = game.draw.bind(game);
  const buffer = document.createElement('canvas');
  const bufferCtx = buffer.getContext('2d');

  game.draw = function(){
    const liveView = this.view;
    const extraScale = portraitExtraScaleForView(liveView);
    if(extraScale === 1){
      baseDraw();
      return;
    }

    const screenCtx = this.ctx;
    const dpr = liveView.dpr || 1;
    const renderW = liveView.w / extraScale;
    const renderH = liveView.h / extraScale;
    const pixelW = Math.ceil(renderW * dpr);
    const pixelH = Math.ceil(renderH * dpr);

    if(buffer.width !== pixelW || buffer.height !== pixelH){
      buffer.width = pixelW;
      buffer.height = pixelH;
    }
    bufferCtx.setTransform(dpr,0,0,dpr,0,0);

    this.ctx = bufferCtx;
    this.view = {...liveView,w:renderW,h:renderH};
    try{
      baseDraw();
    }finally{
      this.ctx = screenCtx;
      this.view = liveView;
    }

    screenCtx.save();
    screenCtx.setTransform(dpr,0,0,dpr,0,0);
    screenCtx.clearRect(0,0,liveView.w,liveView.h);
    screenCtx.drawImage(buffer,0,0,buffer.width,buffer.height,0,0,liveView.w,liveView.h);
    screenCtx.restore();
  };
}
