import { spawn, spawnSync } from 'node:child_process';
import process from 'node:process';

const sleep = ms => new Promise(r=>setTimeout(r,ms));
const root = process.cwd();

function findChrome(){
  for(const name of [process.env.CHROME_PATH,'google-chrome','google-chrome-stable','chromium','chromium-browser'].filter(Boolean)){
    const r=spawnSync('which',[name],{encoding:'utf8'});
    if(r.status===0&&r.stdout.trim())return r.stdout.trim();
  }
  throw new Error('No Chrome/Chromium executable found for browser smoke test');
}

async function waitFor(url,tries=60){
  let last;
  for(let i=0;i<tries;i++){
    try{const r=await fetch(url);if(r.ok)return r;}catch(e){last=e;}
    await sleep(100);
  }
  throw last||new Error(`Timed out waiting for ${url}`);
}

async function main(){
  const server=spawn('python3',['-m','http.server','5173','--bind','127.0.0.1'],{cwd:root,stdio:'ignore'});
  const chromePath=findChrome();
  const chrome=spawn(chromePath,[
    '--headless=new','--no-sandbox','--disable-gpu','--disable-dev-shm-usage',
    '--remote-debugging-port=9222','--user-data-dir=/tmp/riftforged-chrome','about:blank'
  ],{stdio:'ignore'});

  let ws;
  try{
    await waitFor('http://127.0.0.1:5173');
    await waitFor('http://127.0.0.1:9222/json/version');
    const targets=await (await fetch('http://127.0.0.1:9222/json/list')).json();
    const page=targets.find(t=>t.type==='page');
    if(!page?.webSocketDebuggerUrl)throw new Error('No debuggable page target found');

    ws=new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});});
    let id=0;
    const pending=new Map();
    const exceptions=[];
    ws.addEventListener('message',event=>{
      const msg=JSON.parse(event.data);
      if(msg.id&&pending.has(msg.id)){const {resolve,reject}=pending.get(msg.id);pending.delete(msg.id);if(msg.error)reject(new Error(msg.error.message));else resolve(msg.result);return;}
      if(msg.method==='Runtime.exceptionThrown')exceptions.push(msg.params.exceptionDetails?.text||'Runtime exception');
    });
    const send=(method,params={})=>new Promise((resolve,reject)=>{const msgId=++id;pending.set(msgId,{resolve,reject});ws.send(JSON.stringify({id:msgId,method,params}));});
    const evalValue=async expression=>{
      const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
      if(r.exceptionDetails)throw new Error(r.exceptionDetails.text||'Evaluation failed');
      return r.result.value;
    };

    await send('Runtime.enable');
    await send('Page.enable');
    await send('Page.navigate',{url:'http://127.0.0.1:5173/'});
    for(let i=0;i<50;i++){
      if(await evalValue('document.readyState')==='complete')break;
      await sleep(100);
    }
    await sleep(1200);

    const initial=await evalValue(`(()=>({
      canvas:!!document.querySelector('#game')&&document.querySelector('#game').width>0,
      gemButton:!!document.querySelector('#gemButton'),
      gemOverlay:!!document.querySelector('#gemOverlay'),
      sockets:document.querySelectorAll('.gem-socket').length,
      stash:document.querySelectorAll('.gem-card').length,
      socketSource:document.querySelector('#socketSourceLayout')?.textContent
    }))()`);
    if(!initial.canvas)throw new Error('Canvas did not initialize');
    if(!initial.gemButton||!initial.gemOverlay)throw new Error('Gem UI did not mount');
    if(initial.sockets!==4)throw new Error(`Expected 4 starter sockets, got ${initial.sockets}`);
    if(initial.socketSource!=='4連')throw new Error(`Expected starter 4-link source, got ${initial.socketSource}`);
    if(initial.stash<2)throw new Error(`Expected starter gem stash, got ${initial.stash}`);

    await evalValue(`document.querySelector('#gemButton').click()`);
    await sleep(100);
    if(await evalValue(`document.querySelector('#gemOverlay').classList.contains('hidden')`))throw new Error('Gem overlay did not open');

    await evalValue(`document.querySelectorAll('.gem-card')[0].click();document.querySelectorAll('.gem-socket')[1].click();`);
    await sleep(100);
    const afterInstall=await evalValue(`(()=>({stash:document.querySelectorAll('.gem-card').length,status:document.querySelector('#gemStatus').textContent}))()`);
    if(afterInstall.stash!==initial.stash-1)throw new Error('Gem install did not consume the selected stash entry');
    if(!afterInstall.status.includes('翠綠連鎖'))throw new Error('Linked support did not appear active in browser UI');

    await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
    await send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});
    await sleep(150);
    const mobile=await evalValue(`(()=>({
      width:innerWidth,
      mobileControls:!!document.querySelector('#mobileControls'),
      attack:!!document.querySelector('#attackButton'),
      dash:!!document.querySelector('#dashButton'),
      overflow:document.documentElement.scrollWidth>innerWidth+2
    }))()`);
    if(mobile.width!==390||!mobile.mobileControls||!mobile.attack||!mobile.dash)throw new Error('Mobile control smoke test failed');
    if(mobile.overflow)throw new Error('Mobile viewport has horizontal overflow');

    if(exceptions.length)throw new Error(`Browser runtime exceptions: ${exceptions.join(' | ')}`);
    console.log('Browser smoke test passed: boot, 4-link gem UI, linked install, mobile viewport.');
  } finally {
    try{ws?.close();}catch{}
    chrome.kill('SIGTERM');server.kill('SIGTERM');
  }
}

main().catch(err=>{console.error(err);process.exitCode=1;});
