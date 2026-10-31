// Run from the repo with sharp installed and KOOCOMIC_LUA_BIN set to Lua 5.1.
const fs = require('fs');
const path = require('path');
const os = require('os');
const cp = require('child_process');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
process.chdir(root);
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'koocomic-book-preview-'));
const original = fs.readFileSync('assets/ui-preview/open-book-appearance.svg','utf8');
const samples = [...original.matchAll(/<svg x="44"[\s\S]*?<\/svg>/g)].map(m => m[0]);
const w=500,h=350,sw=185,sh=237;

async function book(mode,index) {
  const warm = mode==='warm';
  const shell = fs.readFileSync(`koocomic.koplugin/artwork/open-book-${mode}.svg`,'utf8')
    .replace(/<svg[^>]*>/,'').replace('</svg>','')
    .replaceAll('id="left"',`id="${mode}left"`).replaceAll('id="right"',`id="${mode}right"`)
    .replaceAll('url(#left)',`url(#${mode}left)`).replaceAll('url(#right)',`url(#${mode}right)`);
  const sample = samples[index].replace(/<svg[^>]*>/,
    '<svg xmlns="http://www.w3.org/2000/svg" width="130" height="179" viewBox="0 0 130 179">')
    .replace(/<rect x="\.5"[^>]*\/>/,'');
  const rgb=path.join(tmp,mode+'.rgb'), rgba=path.join(tmp,mode+'.rgba');
  fs.writeFileSync(rgb, await sharp(Buffer.from(sample)).resize(sw,sh,{fit:'contain',background:warm?'#fffdf7':'#ffffff'})
    .removeAlpha().raw().toBuffer());
  cp.execFileSync(process.env.KOOCOMIC_LUA_BIN || 'lua',[
    'scripts/render_book_surface_preview.lua',rgb,rgba,''+w,''+h,''+sw,''+sh]);
  const image=await sharp(fs.readFileSync(rgba),{raw:{width:w,height:h,channels:4}}).png().toBuffer();
  const ink=warm?'#744619':'#303030';
  return `${shell}<image width="400" height="280" href="data:image/png;base64,${image.toString('base64')}"/>
  <text x="291" y="123" text-anchor="middle" font-size="20" font-weight="600" fill="${ink}">雾山之下</text>
  <text x="291" y="148" text-anchor="middle" font-size="15" fill="${ink}">卷 01</text>`;
}

(async()=>{
  const mono=await book('mono',0), warm=await book('warm',1);
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="650">
  <rect width="1200" height="650" fill="#f7f6f3"/>
  <g font-family="PingFang SC,Heiti SC,sans-serif">
  <text x="60" y="66" font-size="30" font-weight="600" fill="#242424">打开书 · 封面随纸面弯曲</text>
  <text x="60" y="103" font-size="17" fill="#727272">曲线上下沿 / 贴合倾斜页边 / 书脊处轻微压缩与明暗</text>
  <rect x="40" y="136" width="550" height="410" rx="18" fill="#fff"/>
  <rect x="610" y="136" width="550" height="410" rx="18" fill="#fffbf5"/>
  <g transform="translate(65 176) scale(1.25)">${mono}</g>
  <g transform="translate(635 176) scale(1.25)">${warm}</g>
  <text x="315" y="578" text-anchor="middle" font-size="22" fill="#333">黑白版</text>
  <text x="885" y="578" text-anchor="middle" font-size="22" fill="#744619">暖纸色版</text>
  <text x="600" y="622" text-anchor="middle" font-size="16" fill="#777">使用插件同一曲面算法绘制；示例封面，非 Kindle 实机截图。</text></g></svg>`;
  fs.writeFileSync('assets/ui-preview/open-book-curved.svg',svg);
  await sharp(Buffer.from(svg)).png().toFile('assets/ui-preview/open-book-curved.png');
  console.log('Rendered assets/ui-preview/open-book-curved.png');
})().catch(e=>{ console.error(e);process.exitCode=1; });
