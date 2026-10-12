/* Review-only fixture: no gameplay, persistence, telemetry or production token writes. */
const directions = ['ceramic', 'paper', 'mist'];
const modes = ['hc', 'large', 'pseudo', 'eight', 'insets'];
if (document.body.classList.contains('comparison')) {
  document.querySelector('.review').addEventListener('change', () => {
    const values = new FormData(document.querySelector('.review'));
    document.querySelectorAll('article').forEach(article => {
      const query = new URLSearchParams({direction: article.dataset.direction});
      modes.forEach(mode => { if (values.has(mode)) query.set(mode, '1'); });
      const url = `level.html?${query}`;
      article.querySelector('iframe').src = url;
      article.querySelector('a').href = url;
    });
  });
} else {
  const query = new URLSearchParams(location.search), root = document.documentElement;
  root.dataset.direction = directions.includes(query.get('direction')) ? query.get('direction') : 'ceramic';
  root.dataset.hc = String(query.get('hc') === '1');
  root.style.setProperty('--Mock-text-scale', query.get('large') === '1' ? '1.3' : '1');
  if (query.get('insets') === '1') { root.style.setProperty('--Mock-top', '44px'); root.style.setProperty('--Mock-bottom', '34px'); }
  if (query.get('pseudo') === '1') {
    document.documentElement.lang = 'en';
    document.querySelector('[data-key="level.hud.level_n"]').textContent = '⟦Pózíóm aa 12⟧';
  }
  document.querySelectorAll('[data-icon]').forEach(node => {
    node.innerHTML = `<svg aria-hidden="true"><use href="#${node.dataset.icon}"></use></svg>`;
  });
  // LAS across; LATO down through L; STO across through T. All words use the wheel.
  const cells = [[0,2,'L','filled'],[0,3,'A','filled'],[0,4,'S','filled'],[1,2,'A','hinted'],[2,1,'',''],[2,2,'',''],[2,3,'',''],[3,2,'','']];
  document.querySelector('.board').innerHTML = cells.map(([row,col,letter,state]) => `<span class="cell ${state}" style="grid-row:${row+1};grid-column:${col+1}">${letter}</span>`).join('');
  const letters = query.get('eight') === '1' ? ['L','A','T','O','S','Ż','Ó','Ł'] : ['L','A','T','O','S'];
  document.querySelector('.wheel').setAttribute('aria-label', `Koło liter ${letters.join(', ')}; zaznaczone L i A`);
  const positions = letters.map((letter,index) => ({letter,angle: (index / letters.length * 2 * Math.PI) - Math.PI / 2}));
  const tiles = document.querySelector('.tiles');
  tiles.innerHTML = positions.map(({letter},i) => `<span class="tile ${i<2?'selected':''}">${letter}</span>`).join('');
  const css = getComputedStyle(root), number = name => Number(css.getPropertyValue(`--${name}`));
  const probe = document.createElement('span');
  probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none';
  document.body.append(probe);
  const px = name => { probe.style.width = `var(--${name})`; return probe.getBoundingClientRect().width; };
  const size = Object.fromEntries(['Layout-WHEEL_MIN','Layout-WHEEL_MAX','Layout-CELL_MAX','Space-XS','Space-S','Space-L'].map(name=>[name,px(name)]));
  probe.remove();
  function layout() {
    const screen = document.querySelector('.screen'), body = document.querySelector('.body');
    const safe = getComputedStyle(screen), width = body.getBoundingClientRect().width;
    const aspect = (innerHeight-parseFloat(safe.paddingTop)-parseFloat(safe.paddingBottom))/innerWidth;
    const compact = aspect >= number('Layout-TABLET_MAX_ASPECT') && aspect < number('Layout-COMPACT_MAX_ASPECT');
    root.dataset.layout = aspect < number('Layout-TABLET_MAX_ASPECT') ? 'TABLET' : compact ? 'COMPACT' : 'REGULAR';
    const ratio = number(compact ? 'Layout-WHEEL_COMPACT_RATIO' : 'Layout-WHEEL_WIDTH_RATIO');
    const minWheel = size['Layout-WHEEL_MIN'];
    const requestedWheel = Math.min(size['Layout-WHEEL_MAX'], Math.max(minWheel, width * ratio));
    const height = body.getBoundingClientRect().height;
    const fixed = document.querySelector('.bonus').getBoundingClientRect().height + document.querySelector('.preview-strip').getBoundingClientRect().height;
    const budget = height * (1-number('Layout-GRID_MIN_RATIO')) - fixed;
    let padding = size[compact ? 'Space-S' : 'Space-L'];
    // Shrink towards WHEEL_MIN first; the review-only compact fallback preserves grid share.
    if (budget - padding*2 < minWheel) padding = size['Space-S'];
    const wheel = Math.min(requestedWheel, Math.max(minWheel, budget-padding*2));
    root.style.setProperty('--Mock-wheel', `${wheel}px`);
    root.style.setProperty('--Mock-wheel-space', `${padding}px`);
    const area = document.querySelector('.board-area');
    const gap = size['Space-XS'], cell = Math.min(size['Layout-CELL_MAX'], (width-gap*4)/5, (area.getBoundingClientRect().height-gap*3)/4);
    root.style.setProperty('--Mock-cell', `${Math.max(0,cell)}px`);
    const ring = number('Layout-WHEEL_RING_RATIO');
    const coords = positions.map(({angle}) => [wheel*(.5+Math.cos(angle)*ring),wheel*(.5+Math.sin(angle)*ring)]);
    [...tiles.children].forEach((tile,i) => { tile.style.left=`${coords[i][0]}px`; tile.style.top=`${coords[i][1]}px`; });
    document.querySelector('.chain polyline').setAttribute('points',coords.slice(0,2).map(p=>p.join(',')).join(' '));
  }
  new ResizeObserver(layout).observe(document.querySelector('.screen'));
  layout();
}
