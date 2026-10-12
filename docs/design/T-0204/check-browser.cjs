/* Repeatable offline review, using an already installed Playwright runtime.
   No repository dependency or production code. See README.md for invocation. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require(process.env.BROWSER_TEST_MODULE || 'playwright-core');
const directions = ['ceramic', 'paper', 'mist'];
const modes = ['hc', 'large', 'pseudo', 'eight', 'insets'];
const viewports = [['COMPACT',360,640], ['REGULAR',390,844], ['TABLET',768,1024]];
const output = path.resolve(process.env.BROWSER_OUTPUT || path.join(__dirname, 'evidence'));
const tokenRefs = [...fs.readFileSync(path.join(__dirname,'level.css'),'utf8').matchAll(/var\((--[\w-]+)/g)].map(match=>match[1]);

function inspect(tokenRefs) {
  const failures = [], root = document.documentElement, css = getComputedStyle(root);
  const rect = selector => document.querySelector(selector).getBoundingClientRect();
  const px = name => {
    const probe = document.createElement('span');
    probe.style.cssText = `position:fixed;visibility:hidden;width:var(--${name})`;
    document.body.append(probe);
    const result = probe.getBoundingClientRect().width;
    probe.remove(); return result;
  };
  const number = name => Number(css.getPropertyValue(`--${name}`));
  const check = (ok, message) => { if (!ok) failures.push(message); };
  const screen = rect('.screen'), screenStyle = getComputedStyle(document.querySelector('.screen'));
  const query = new URLSearchParams(location.search), hc = query.get('hc') === '1';
  const scale = query.get('large') === '1' ? 1.3 : 1;
  check(root.dataset.hc === String(hc), 'HC flag ignored');
  if(hc) check(css.getPropertyValue('--Palette-BG').trim() === '#FFFFFF' && css.getPropertyValue('--Palette-TEXT').trim() === '#000000', 'HC palette ignored');
  check(Math.abs(parseFloat(getComputedStyle(document.querySelector('.currency b')).fontSize)-px('Type-NUMERIC-size')*scale)<.1, 'text scale ignored');
  check(Math.abs(parseFloat(getComputedStyle(document.querySelector('.tile')).fontSize)-px('Type-TILE_LETTER-size'))<.1, 'geometric tile text scaled');
  check(Math.abs(parseFloat(getComputedStyle(document.querySelector('.word-preview')).fontSize)-px('Type-PREVIEW-size'))<.1, 'geometric preview text scaled');
  check(document.querySelector('h1').textContent === (query.get('pseudo') === '1' ? '⟦Pózíóm aa 12⟧' : 'Poziom 12'), 'pseudo flag ignored');
  check(Math.abs(parseFloat(screenStyle.paddingTop)-(query.get('insets') === '1' ? 44 : px('Space-S')))<.1, 'top inset ignored');
  check(Math.abs(parseFloat(screenStyle.paddingBottom)-(query.get('insets') === '1' ? 34 : px('Space-S')))<.1, 'bottom inset ignored');
  const aspect = (innerHeight-parseFloat(screenStyle.paddingTop)-parseFloat(screenStyle.paddingBottom))/innerWidth;
  check(root.dataset.layout === (aspect<number('Layout-TABLET_MAX_ASPECT') ? 'TABLET' : aspect<number('Layout-COMPACT_MAX_ASPECT') ? 'COMPACT' : 'REGULAR'), 'incorrect layout class');
  const top = screen.top + parseFloat(screenStyle.paddingTop), bottom = screen.bottom - parseFloat(screenStyle.paddingBottom);
  const left = screen.left + parseFloat(screenStyle.paddingLeft), right = screen.right - parseFloat(screenStyle.paddingRight);
  const inside = (r, area) => r.left >= area.left-.1 && r.right <= area.right+.1 && r.top >= area.top-.1 && r.bottom <= area.bottom+.1;
  check(root.scrollWidth <= innerWidth && root.scrollHeight <= innerHeight, 'game screen scrolls');
  check(inside(rect('.board'), rect('.board-area')), 'board clipping');
  check(rect('.board-area').height+.1 >= rect('.body').height*number('Layout-GRID_MIN_RATIO'), 'grid share below minimum');
  check(rect('.cell').width+.1 >= px('Layout-CELL_MIN'), 'cell below minimum');
  check(rect('.wheel').width+.1 >= px('Layout-WHEEL_MIN') && rect('.wheel').width <= px('Layout-WHEEL_MAX')+.1, 'wheel clamp');
  for (const node of document.querySelectorAll('.control,.currency,.tile,.cell,.bonus,.word-preview,h1')) {
    check(inside(node.getBoundingClientRect(), {top,bottom,left,right}), `${node.className || node.tagName} outside safe content`);
    check(node.scrollWidth <= node.clientWidth+1 && node.scrollHeight <= node.clientHeight+1, `${node.className || node.tagName} clips content`);
  }
  const min = px('Touch-MIN_TARGET');
  for (const node of document.querySelectorAll('.control,.currency')) {
    const r = node.getBoundingClientRect();
    check(r.width+.1 >= min && r.height+.1 >= min, `${node.className} below touch minimum`);
    check(Boolean(node.getAttribute('aria-label')), `${node.className} missing accessible label`);
  }
  let minClearance = Infinity;
  for (const button of document.querySelectorAll('.corner')) {
    const b = button.getBoundingClientRect();
    for (const tile of document.querySelectorAll('.tile')) {
      const t = tile.getBoundingClientRect(), x = (t.left+t.right)/2, y = (t.top+t.bottom)/2;
      // Use the selected visual scale too: stricter than the unscaled runtime hit radius.
      const radius = t.width/2 * number('Touch-TILE_HIT_RATIO');
      const distance = Math.hypot(x-Math.max(b.left,Math.min(x,b.right)), y-Math.max(b.top,Math.min(y,b.bottom)));
      minClearance = Math.min(minClearance, distance-radius);
      check(distance >= radius, `${button.className} intersects ${tile.textContent} hit circle`);
    }
  }
  const visible = node => {const s=getComputedStyle(node); return s.display!=='none' && s.visibility==='visible' && Number(s.opacity)>0;};
  const painted = color => color!=='none' && color!=='transparent' && !/^rgba\([^)]*,\s*0(?:\.0+)?\)$/.test(color);
  const tileNodes = [...document.querySelectorAll('.tile')];
  tileNodes.forEach((tile,i)=>tileNodes.slice(i+1).forEach(other=>{
    const a=tile.getBoundingClientRect(), b=other.getBoundingClientRect();
    check(a.right<=b.left || b.right<=a.left || a.bottom<=b.top || b.bottom<=a.top, `visible tiles ${tile.textContent}/${other.textContent} overlap`);
  }));
  const hinted = document.querySelector('.cell.hinted'), dot = getComputedStyle(hinted,'::after');
  check(visible(hinted) && dot.content!=='none' && parseFloat(dot.width)>0 && parseFloat(dot.height)>0 && dot.display!=='none' && dot.visibility==='visible' && Number(dot.opacity)>0 && painted(dot.backgroundColor), 'hint dot missing');
  for(const tile of document.querySelectorAll('.tile.selected')) {
    const s=getComputedStyle(tile);
    check(visible(tile) && s.outlineStyle!=='none' && parseFloat(s.outlineWidth)>0 && painted(s.outlineColor), 'selection outline missing');
  }
  const chain = document.querySelector('.chain'), polyline = chain.querySelector('polyline'), stroke=getComputedStyle(polyline);
  check(visible(chain) && visible(polyline) && painted(stroke.stroke) && parseFloat(stroke.strokeWidth)>0 && polyline.points.numberOfItems===2, 'selection chain missing');
  const selected = [...document.querySelectorAll('.tile.selected')];
  if(polyline.points.numberOfItems===2) selected.forEach((tile,i)=>{
    const point=polyline.points.getItem(i), actual=new DOMPoint(point.x,point.y).matrixTransform(polyline.getScreenCTM()), t=tile.getBoundingClientRect();
    check(Math.hypot(actual.x-(t.left+t.right)/2,actual.y-(t.top+t.bottom)/2)<.1, 'selection chain misses tile centre');
  });
  // Alpha-composite ancestor backgrounds and foreground opacity before WCAG luminance.
  const rgba = value => value.match(/[\d.]+/g).map(Number);
  const blend = (front, back) => front.slice(0,3).map((v,i)=>v*(front[3] ?? 1)+back[i]*(1-(front[3] ?? 1)));
  const background = node => {
    const chain = []; for(let n=node;n;n=n.parentElement) chain.unshift(n);
    return chain.reduce((color,n)=>blend(rgba(getComputedStyle(n).backgroundColor),color),[255,255,255]);
  };
  const luminance = rgb => rgb.map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
  let minContrast = Infinity;
  for(const node of document.querySelectorAll('h1,b,small,.bonus>span:last-child,.word-preview,.selection-mark,.tile,.cell.filled,.cell.hinted,[data-icon]')) {
    const s = getComputedStyle(node), bg = background(node), fg = rgba(s.color);
    fg[3] = (fg[3] ?? 1)*Number(s.opacity);
    const a = luminance(blend(fg,bg)), b = luminance(bg), ratio = (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
    minContrast = Math.min(minContrast, ratio);
    check(ratio >= (root.dataset.hc === 'true' ? 7 : 4.5), `${node.className || node.tagName} contrast ${ratio.toFixed(3)}`);
  }
  for(const name of tokenRefs) check(css.getPropertyValue(name).trim().length > 0, `unresolved ${name}`);
  check(document.querySelectorAll('.tile').length === (new URLSearchParams(location.search).get('eight') === '1' ? 8 : 5), 'wrong letter fixture');
  return {failures, layout:root.dataset.layout, minContrast, minClearance, gridShare:rect('.board-area').height/rect('.body').height};
}

(async () => {
  fs.mkdirSync(output, {recursive:true});
  const browser = await chromium.launch(process.env.BROWSER_EXECUTABLE ? {executablePath:process.env.BROWSER_EXECUTABLE} : {});
  const errors = [], external = [], results = [];
  try {
    const context = await browser.newContext({deviceScaleFactor:1});
    context.on('page', page => {
      page.on('pageerror', error=>errors.push(error.message));
      page.on('console', message=>{if(message.type()==='error') errors.push(message.text());});
      page.on('requestfailed', request=>errors.push(`${request.url()}: ${request.failure().errorText}`));
    });
    await context.route(/https?:\/\//, route=>{external.push(route.request().url()); return route.abort();});
    const page = await context.newPage();
    for(const [label,width,height] of viewports) {
      await page.setViewportSize({width,height});
      for(const direction of directions) for(let mask=0;mask<32;mask++) {
        const query = new URLSearchParams({direction});
        modes.forEach((mode,i)=>{if(mask & (1<<i)) query.set(mode,'1');});
        await page.goto(`${pathToFileURL(path.join(__dirname,'level.html'))}?${query}`);
        await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
        const result = await page.evaluate(inspect, tokenRefs);
        results.push({viewport:label,width,height,direction,query:query.toString(),...result});
        if(mask===0 || mask===30 || mask===31) {
          const state = mask===0?'default':mask===30?'stress':'stress_hc', lang=mask===0?'PL':'PSEUDO';
          await page.screenshot({path:path.join(output,`level_${direction}_${label}_${lang}_${state}.png`)});
        }
      }
    }
    // A live resize must recompute layout and leave no stale wheel/board dimensions.
    for(const [label,width,height] of [...viewports].reverse()) {
      await page.setViewportSize({width,height});
      await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      const result = await page.evaluate(inspect, tokenRefs);
      results.push({viewport:label,resize:true,...result});
    }
    await page.goto(pathToFileURL(path.join(__dirname,'index.html')).href);
    for(let mask=0;mask<32;mask++) {
      for(let i=0;i<modes.length;i++) await page.locator(`input[name="${modes[i]}"]`).setChecked(Boolean(mask & (1<<i)));
      for(const direction of directions) {
        const href = await page.locator(`article[data-direction="${direction}"] a`).getAttribute('href');
        const src = await page.locator(`article[data-direction="${direction}"] iframe`).getAttribute('src');
        assert.equal(href,src);
        const query = new URL(href,'file:///').searchParams;
        assert.equal(query.get('direction'),direction);
        modes.forEach((mode,i)=>assert.equal(query.get(mode),mask & (1<<i) ? '1' : null));
      }
    }
    await page.setViewportSize({width:1440,height:1150});
    for(const mode of modes) await page.locator(`input[name="${mode}"]`).uncheck();
    await Promise.all(page.frames().slice(1).map(frame=>frame.waitForSelector('.tile')));
    await page.screenshot({path:path.join(output,'comparison_DESKTOP_PL_default.png'),fullPage:true});
    const report = {browser:browser.version(), cases:results.length, errors, external, results};
    fs.writeFileSync(path.join(output,'browser-results.json'),JSON.stringify(report,null,2)+'\n');
    const failures = results.filter(x=>x.failures.length);
    console.log(JSON.stringify({browser:report.browser,cases:results.length,failed:failures.length,errors,external,minimumContrast:Math.min(...results.map(x=>x.minContrast)),minimumClearance:Math.min(...results.map(x=>x.minClearance))},null,2));
    if(failures.length) console.log(JSON.stringify(failures.slice(0,4),null,2));
    assert.equal(failures.length,0,'browser matrix failures');
    assert.deepEqual(errors,[]); assert.deepEqual(external,[]);
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
