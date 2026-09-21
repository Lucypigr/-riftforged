"""Precompress Godot payloads for static hosts with per-file size limits."""
import gzip,sys
from pathlib import Path
p=Path(sys.argv[1]);html=p/'index.html'
for name in ['index.wasm','index.pck']:
 f=p/name;(p/(name+'.gz')).write_bytes(gzip.compress(f.read_bytes(),compresslevel=9,mtime=0));f.unlink()
loader='''<script>
(() => {
 const originalFetch = window.fetch.bind(window);
 window.fetch = async (input, options) => {
   const url = typeof input === 'string' ? input : input.url;
   if (!/index\\.(wasm|pck)(\\?.*)?$/.test(url)) return originalFetch(input, options);
   const response = await originalFetch(url.replace(/(\\?.*)?$/, '.gz$1'), options);
   if (!response.ok) throw new Error('遊戲檔案下載失敗：' + response.status);
   const bytes = new Uint8Array(await response.arrayBuffer());
   let body = bytes;
   if (bytes[0] === 31 && bytes[1] === 139) {
     if (!window.DecompressionStream) throw new Error('請使用支援解壓縮的新版 Safari、Chrome 或 Edge。');
     body = await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
   }
   return new Response(body, {headers:{'Content-Type':url.includes('.wasm')?'application/wasm':'application/octet-stream'}});
 };
})();
</script>'''
s=html.read_text().replace('<script src="index.js"></script>',loader+'\n<script src="index.js"></script>')
s=s.replace('width=device-width, initial-scale=1.0','width=device-width, initial-scale=1.0, viewport-fit=cover')
s=s.replace('</head>','<style>body{touch-action:none;overscroll-behavior:none}#canvas{padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);box-sizing:border-box}</style></head>')
html.write_text(s)
(p/'_headers').write_text('/index.wasm.gz\n  Cache-Control: public, max-age=86400\n/index.pck.gz\n  Cache-Control: public, max-age=0, must-revalidate\n')
for f in p.glob('*.gz'):print(f.name, f.stat().st_size)
