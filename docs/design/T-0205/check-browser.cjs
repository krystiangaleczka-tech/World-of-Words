/* Offline review with an already installed Playwright browser runtime. */
const assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path');
const {pathToFileURL}=require('node:url');
const {createHash}=require('node:crypto');
const {chromium}=require(process.env.BROWSER_TEST_MODULE || 'playwright-core');
const states=['home','complete','journey','shop','tutorial','shuffle','bonus','hint','reveal','journey_coach'];
const modes=['hc','large','pseudo','insets'];
const views=[['COMPACT',360,640],['REGULAR',390,844],['TABLET',768,1024]];
const output=path.resolve(process.env.BROWSER_OUTPUT || path.join(__dirname,'evidence'));
const tokenRefs=[...fs.readFileSync(path.join(__dirname,'screens.css'),'utf8').matchAll(/var\((--(?:Palette|Type|Space|Radius|Touch|Layout|Motion|Ease|Elevation)-[\w-]+)/g)].map(m=>m[1]);

function inspect(tokenRefs){
  const root=document.documentElement,main=document.querySelector('.screen'),css=getComputedStyle(root),safe=getComputedStyle(main),query=new URLSearchParams(location.search),failures=[];
  const check=(ok,message)=>{if(!ok)failures.push(message);};
  const px=name=>{const n=document.createElement('span');n.style.cssText=`position:fixed;visibility:hidden;width:var(--${name})`;document.body.append(n);const value=n.getBoundingClientRect().width;n.remove();return value;};
  const rect=node=>node.getBoundingClientRect(),contained=(a,b)=>a.left>=b.left-.1&&a.right<=b.right+.1&&a.top>=b.top-.1&&a.bottom<=b.bottom+.1;
  const min=px('Touch-MIN_TARGET'),hc=query.get('hc')==='1',scale=query.get('large')==='1'?1.3:1,screen=root.dataset.screen;
  check(root.scrollWidth<=innerWidth&&root.scrollHeight<=innerHeight,'outer scrolling');
  check(root.dataset.hc===String(hc),'HC flag ignored');
  if(hc)check(css.getPropertyValue('--Palette-BG').trim()==='#FFFFFF'&&css.getPropertyValue('--Palette-TEXT').trim()==='#000000','HC palette ignored');
  check(Math.abs(Number(css.getPropertyValue('--Mock-text-scale'))-scale)<.001,'text scale ignored');
  for(const [selector,token] of [['.caption','Type-CAPTION-size'],['.title','Type-TITLE-size'],['.copy','Type-BODY-size'],['.subtitle','Type-SUBTITLE-size'],['.level-number','Type-DISPLAY-size']]){
    for(const node of main.querySelectorAll(selector))check(Math.abs(parseFloat(getComputedStyle(node).fontSize)-px(token)*scale)<.1,`actual text scale ignored ${selector}`);
  }
  check(Math.abs(parseFloat(safe.paddingTop)-(query.get('insets')==='1'?44:px('Space-S')))<.1,'top inset ignored');
  check(Math.abs(parseFloat(safe.paddingBottom)-(query.get('insets')==='1'?34:px('Space-S')))<.1,'bottom inset ignored');
  for(const node of main.querySelectorAll('[data-key]')){
    check(query.get('pseudo')==='1'?Boolean(node.dataset.sourceCopy)&&node.textContent.startsWith('[')&&node.textContent.length>=node.dataset.sourceCopy.length*1.35:!node.dataset.sourceCopy,'pseudo flag ignored');
    check(node.scrollWidth<=node.clientWidth+1&&node.scrollHeight<=node.clientHeight+1,`label clipping ${node.dataset.key}`);
    const range=document.createRange();range.selectNodeContents(node);
    const bounds=rect(node.closest('.action,.card,.content,.sheet,.topbar,.navigation,.wheel-caption-row,.bonus-row,.reveal-coach')||main);
    for(const line of range.getClientRects())check(line.left>=bounds.left-.1&&line.right<=bounds.right+.1,`text line exceeds container ${node.dataset.key}`);
  }
  for(const node of main.querySelectorAll('.icon,.pill,.action,.tab')){
    const r=rect(node);check(r.width+.1>=min&&r.height+.1>=min,`small target ${node.className}`);
    check(Boolean(node.getAttribute('aria-label')),`missing accessible label ${node.className}`);
    if(node.matches('[data-component="IconButton"],[data-component="HintButton"],[data-component="CurrencyPill"]'))check(Boolean(node.dataset.labelKey),`missing accessible key ${node.className}`);
    const clip=node.closest('.content');
    if(!clip || contained(r,rect(clip)))check(r.left>=rect(main).left-.1&&r.right<=rect(main).right+.1,`target horizontal overflow ${node.className}`);
  }
  for(const node of main.querySelectorAll('[aria-label][data-component]'))check(Boolean(node.dataset.labelKey),'accessible component lacks key mapping');
  for(const label of main.querySelectorAll('.action [data-key],.tab [data-key]')){
    const range=document.createRange();range.selectNodeContents(label);
    const lines=new Set([...range.getClientRects()].map(r=>Math.round(r.top*10)));
    check(lines.size<=2,`action label exceeds two lines ${label.dataset.key}`);
  }
  check(main.querySelectorAll('[data-component="PrimaryButton"]').length<=1,'multiple primary actions');
  for(const name of tokenRefs)check(css.getPropertyValue(name).trim().length>0,`unresolved ${name}`);
  const active=screen==='shop'?main.querySelector('.sheet'):main;
  let minContrast=Infinity;
  const rgba=value=>value.match(/[\d.]+/g).map(Number),blend=(front,back)=>front.slice(0,3).map((v,i)=>v*(front[3]??1)+back[i]*(1-(front[3]??1)));
  const background=node=>{const parents=[];for(let n=node;n;n=n.parentElement)parents.unshift(n);return parents.reduce((color,n)=>blend(rgba(getComputedStyle(n).backgroundColor),color),[255,255,255]);};
  const luminance=rgb=>rgb.map(v=>v/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0);
  for(const node of active.querySelectorAll('[data-key],.numeric,.word-preview,.tile,.icon svg,.ad-badge svg,.pill svg,.bonus svg,.stamp svg')){
    const bg=background(node),s=getComputedStyle(node),fg=rgba(s.color);fg[3]=(fg[3]??1)*Number(s.opacity);
    const a=luminance(blend(fg,bg)),b=luminance(bg),ratio=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);minContrast=Math.min(minContrast,ratio);
    check(ratio>=(hc?7:4.5),`contrast ${node.dataset.key||node.className.baseVal||node.className}: ${ratio.toFixed(3)}`);
  }
  if(screen==='shop'){
    check(rect(active).height<=innerHeight*Number(css.getPropertyValue('--Layout-SHEET_MAX_RATIO'))+.1,'sheet too tall');
    check(main.querySelector('[data-product="nc.remove_forced_ads.v1"]')&&main.querySelector('[data-product="c.coins_s.v1"]'),'noncanonical products');
    check(main.querySelectorAll('[data-ad="true"]').length===1,'rewarded shop action lacks ad badge');
    check(Boolean(main.querySelector('[data-restore]'))===(query.get('platform')==='ios'),'restore platform gating');
  }
  if(screen==='complete'){check(main.querySelectorAll('[data-ad="true"]').length===1,'x2 lacks ad badge');check(main.querySelector('.rewards .pill').textContent.trim()==='1','Q2 star rule');}
  if(screen==='home'||screen==='journey_coach'){check(main.querySelectorAll('[data-component="NavTab"]').length===1,'unbuilt tabs shown');}
  if(screen==='journey'){
    for(const state of ['locked','current','complete'])check(Boolean(main.querySelector(`.card.${state} .card-label svg`)),`missing ${state} shape cue`);
    const stamp=main.querySelector('.card.complete .postcard .stamp'),glyph=stamp?.querySelector('svg');
    check(Boolean(glyph),'complete postcard stamp missing');
    if(glyph){const s=getComputedStyle(glyph);check(rect(glyph).width<=24.1&&rect(glyph).height<=24.1&&s.stroke!=='none'&&parseFloat(s.strokeWidth)>0&&s.display!=='none'&&s.visibility==='visible'&&Number(s.opacity)>0,'complete stamp not a visible icon');check(contained(rect(stamp),rect(stamp.closest('.postcard'))),'stamp outside postcard');}
  }
  let clearance=null,gridShare=null;
  const body=main.querySelector('.level-body');
  if(body){
    const board=main.querySelector('.board'),area=main.querySelector('.board-area'),wheel=main.querySelector('.wheel'),diameter=rect(wheel).width;
    gridShare=rect(area).height/rect(body).height;
    check(gridShare+.0002>=Number(css.getPropertyValue('--Layout-GRID_MIN_RATIO')),'insufficient grid share');
    check(contained(rect(board),rect(area)),'board clipping');
    check(rect(main.querySelector('.cell')).width+.1>=px('Layout-CELL_MIN'),'cell too small');
    check(diameter+.1>=px('Layout-WHEEL_MIN')&&diameter<=px('Layout-WHEEL_MAX')+.1,'wheel clamp');
    const tiles=[...main.querySelectorAll('.tile')];clearance=Infinity;
    for(const tile of tiles){
      const t=rect(tile),radius=t.width/2*Number(css.getPropertyValue('--Touch-TILE_HIT_RATIO'));
      check(radius*2+.1>=min,'tile hit target too small');
      check(Math.abs(parseFloat(getComputedStyle(tile).fontSize)-px('Type-TILE_LETTER-size'))<.1,'geometric text scaled');
      for(const button of main.querySelectorAll('.corner')){const b=rect(button),x=(t.left+t.right)/2,y=(t.top+t.bottom)/2,d=Math.hypot(x-Math.max(b.left,Math.min(x,b.right)),y-Math.max(b.top,Math.min(y,b.bottom)));clearance=Math.min(clearance,d-radius);check(d>=radius,'corner intersects tile hit circle');}
      for(const caption of main.querySelectorAll('.coach-caption')){const b=rect(caption),x=(t.left+t.right)/2,y=(t.top+t.bottom)/2,d=Math.hypot(x-Math.max(b.left,Math.min(x,b.right)),y-Math.max(b.top,Math.min(y,b.bottom)));check(d>=radius,'coach caption intersects tile hit circle');}
    }
    const slot=Number(root.dataset.slot);
    check(Boolean(main.querySelector('[data-target="shuffle"]'))===(slot>=2),'shuffle gating');
    check(Boolean(main.querySelector('[data-component="BonusMeter"]'))===(slot>=5),'bonus gating');
    check(Boolean(main.querySelector('[data-target="hint"]'))===(slot>=7),'hint gating');
    check(Boolean(main.querySelector('[data-target="reveal"]'))===(slot>=12),'reveal gating');
    for(const node of main.querySelectorAll('[data-component="HintButton"]')){
      const badge=node.querySelector('[data-component="Badge"]');check(Boolean(badge),'hint/reveal count presentation missing');
      if(badge){const s=getComputedStyle(badge);check(rect(badge).width>0&&rect(badge).height>0&&s.display!=='none'&&s.visibility==='visible'&&Number(s.opacity)>0,'hint/reveal count hidden');}
    }
    check(Boolean(main.querySelector('.pill'))===(slot>=7),'coin gating');
    if(slot===1){check(!main.querySelector('.icon,.pill,.corner,.bonus'),'slot-1 gated controls');check(Boolean(main.querySelector('[data-key="level.tutorial.connect"]')),'tutorial caption missing');}
    else check(!main.querySelector('[data-component="TutorialHand"]'),'hand reused for coach mark');
  }
  if(!['home','complete','journey','shop','tutorial'].includes(screen)&&root.dataset.coachDismissed!=='true'){
    check(Boolean(main.querySelector('.highlighted'))&&Boolean(main.querySelector('.coach-caption')),'coach shape/caption absent');
    check(!main.querySelector('.scrim,.tutorial-arrow'),'coach overlay or arrow');
    check(getComputedStyle(main.querySelector('.coach-caption')).pointerEvents==='none','coach blocks input');
    const caption=main.querySelector('.coach-caption');
    check(rect(caption).height<=parseFloat(getComputedStyle(caption).lineHeight)*2+.1,'coach caption exceeds two lines');
  }
  return {failures,minContrast,clearance,gridShare,layout:root.dataset.layout||null};
}

(async()=>{
  fs.mkdirSync(output,{recursive:true});
  const sources=JSON.parse(fs.readFileSync(path.join(__dirname,'sources.json'),'utf8'));
  const ownerHash=createHash('sha256').update(fs.readFileSync(path.join(__dirname,'reference-owner.html'))).digest('hex');
  assert.equal(ownerHash,sources.files.owner_reference.sha256,'owner reference changed');
  const browser=await chromium.launch(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{});
  const errors=[],external=[],results=[],behaviour=[];
  try{
    const context=await browser.newContext({deviceScaleFactor:1});
    context.on('page',page=>{page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});page.on('requestfailed',r=>errors.push(`${r.url()}: ${r.failure().errorText}`));});
    await context.route(/https?:\/\//,route=>{external.push(route.request().url());return route.abort();});
    const page=await context.newPage();
    const navigate=async(screen,params={})=>{const query=new URLSearchParams({screen,...params});await page.goto(`${pathToFileURL(path.join(__dirname,'preview.html'))}?${query}`);await page.evaluate(async()=>{await document.fonts.ready;await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});};
    for(const [label,width,height] of views){
      await page.setViewportSize({width,height});
      for(const screen of states)for(let mask=0;mask<16;mask++){
        const params={};modes.forEach((mode,i)=>{if(mask&(1<<i))params[mode]='1';});await navigate(screen,params);
        results.push({screen,viewport:label,params,...await page.evaluate(inspect,tokenRefs)});
        if(mask===0||mask===15)await page.screenshot({path:path.join(output,`${screen}_${label}_${mask?'PSEUDO_stress_hc':'PL_default'}.png`),animations:'disabled'});
      }
    }
    for(const [width,height] of [[512,768],[1024,768]]){await page.setViewportSize({width,height});for(const screen of states){await navigate(screen,{hc:'1',large:'1',pseudo:'1',insets:'1'});results.push({screen,viewport:`RESIZED_${width}x${height}`,...await page.evaluate(inspect,tokenRefs)});}}
    await page.setViewportSize({width:390,height:844});
    for(const reduced of [false,true]){
      await navigate('tutorial',reduced?{reduced:'1'}:{});
      assert.equal(await page.locator('.tutorial-hand').isVisible(),!reduced);assert.equal(await page.locator('.tutorial-arrow').isVisible(),reduced);
      await page.locator('.tile').first().dispatchEvent('pointerdown');
      assert.equal(await page.locator('.tutorial-hand').isVisible(),false);assert.equal(await page.locator('.tutorial-arrow').isVisible(),false);
      assert.equal(await page.locator('html').getAttribute('data-wheel-touched'),'true');behaviour.push({screen:'tutorial',reduced,firstTouch:'PASS'});
    }
    for(const screen of ['shuffle','bonus','hint','reveal','journey_coach']){
      await navigate(screen);await page.locator('.screen').dispatchEvent('pointerdown');assert.equal(await page.locator('.coach-caption').count(),0);assert.equal(await page.locator('.highlighted').count(),0);
      if(screen!=='journey_coach'){await page.locator('.tile').first().dispatchEvent('pointerdown');assert.equal(await page.locator('html').getAttribute('data-wheel-touched'),'true');}
      const after=await page.evaluate(inspect,tokenRefs);assert.deepEqual(after.failures,[],`post-dismissal ${screen}`);
      behaviour.push({screen,anyTapDismissal:'PASS',input:'unblocked'});
    }
    await navigate('shop',{platform:'ios'});results.push({screen:'shop',platform:'ios',...await page.evaluate(inspect,tokenRefs)});
    await page.goto(pathToFileURL(path.join(__dirname,'index.html')).href);
    for(const mode of [...modes,'reduced','ios'])await page.locator(`input[name="${mode}"]`).check();
    for(const screen of states){const article=page.locator(`article[data-screen="${screen}"]`),href=await article.locator('a').getAttribute('href');assert.equal(href,await article.locator('iframe').getAttribute('src'));const p=new URL(href,'file:///').searchParams;assert.equal(p.get('screen'),screen);for(const mode of [...modes,'reduced'])assert.equal(p.get(mode),'1');assert.equal(p.get('platform'),'ios');}
    for(const mode of [...modes,'reduced','ios'])await page.locator(`input[name="${mode}"]`).uncheck();await page.setViewportSize({width:1440,height:1100});
    await Promise.all(page.frames().slice(1).map(frame=>frame.waitForSelector('.screen')));await page.screenshot({path:path.join(output,'comparison_DESKTOP_PL_default.png'),fullPage:true,animations:'disabled'});
    for(const [label,width,height] of views){await page.setViewportSize({width,height});await page.goto(pathToFileURL(path.join(__dirname,'specimen.html')).href);await page.evaluate(()=>document.fonts.ready);assert.equal(await page.evaluate(()=>document.fonts.check('800 32px InterPreview')&&document.fonts.check('800 32px NunitoPreview')),true);await page.screenshot({path:path.join(output,`font_${label}_PL_DE.png`),fullPage:true});}
    const report={browser:browser.version(),cases:results.length,errors,external,behaviour,results};fs.writeFileSync(path.join(output,'browser-results.json'),JSON.stringify(report,null,2)+'\n');
    const failed=results.filter(r=>r.failures.length);console.log(JSON.stringify({cases:results.length,failed:failed.length,errors,external,behaviour},null,2));if(failed.length)console.log(JSON.stringify(failed.slice(0,5),null,2));assert.equal(failed.length,0);assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
