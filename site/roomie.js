/* Roomie, living in the site's own menu bar: the same eyes as the Mac app (0.7), drawn the same way
   (roomie/main.swift: v2Eye, drawV2Face): a soft white ball, a glossy iris with a white spot, lids of the
   ball's colour with her liner or his crease, her curled lashes. The page is dark, so this is the dark-bar picture.
   He follows the pointer, blinks, squashes when clicked, cries on the third click in half a minute
   (the drops fall down the page), gets dizzy if you shake the pointer, dozes off if you leave the page
   alone, and his pupils turn into hearts when he says hello.
   <canvas data-roomie> in the bar, <canvas id="rain"> over the page, <time data-clock> for the clock,
   any [data-who="madam"|"gentleman"] button chooses who lives here. */
(function(){
  const TEAR = "rgb(57,145,211)";
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const cv = document.querySelector("canvas[data-roomie]"), rain = document.getElementById("rain");
  if(!cv || !rain) return;
  const g = cv.getContext("2d"), rg = rain.getContext("2d");
  const D = Math.min(2, devicePixelRatio || 1), TAU = Math.PI*2;
  let who = "madam"; try { who = localStorage.getItem("roomie-who") || "madam"; } catch(e){}
  if(who !== "madam" && who !== "gentleman") who = "madam";

  /* ---------- one eye (0.7: the cartoon eyes, as in roomie/main.swift v2Eye) ---------- */
  const V2 = {
    madam: { rest: .04, iris: .7, irisC: ["#140f20", "#2b2150", "#6e5ecf", "#b1a6f5"], spot: .25, gap: .2, lashes: true },
    gentleman: { rest: .33, iris: .5, irisC: ["#0b0d11", "#1c252d", "#435565", "#7d90a2"], spot: .18, gap: .16, lashes: false } };
  function heartPath(c, w){ c.beginPath(); c.moveTo(0, w*.85);
    c.bezierCurveTo(-w*.6, w*.45, -w, w*.2, -w, -w*.2); c.bezierCurveTo(-w, -w*.8, -w*.2, -w*.85, 0, -w*.45);
    c.bezierCurveTo(w*.2, -w*.85, w, -w*.8, w, -w*.2); c.bezierCurveTo(w, w*.2, w*.6, w*.45, 0, w*.85); c.closePath(); }
  function lidY(R, top, tilt, x, right){ const s = right ? 1 : -1;
    return -R*1.02 + top*2.04*R + tilt*R*(-x*s/R) - (1 - Math.min(1, (x/R)**2))*R*.1*Math.min(1, Math.max(0, top)*4); }
  function lash(c, R, ang, len, w, s){
    const bx = s*Math.sin(ang)*R, by = -Math.cos(ang)*R, nx = s*Math.sin(ang), ny = -Math.cos(ang), px = -ny, py = nx, turn = -s*.8;
    const tx = bx + (nx*Math.cos(turn) - ny*Math.sin(turn))*len, ty = by + (nx*Math.sin(turn) + ny*Math.cos(turn))*len, cx = bx + nx*len*.62, cy = by + ny*len*.62;
    c.beginPath(); c.moveTo(bx + px*w, by + py*w); c.quadraticCurveTo(cx + px*w*.5, cy + py*w*.5, tx, ty);
    c.quadraticCurveTo(cx - px*w*.2, cy - py*w*.2, bx - px*w, by - py*w); c.closePath(); c.fill(); }
  function eye(c, R, e, right, wet){
    const st = V2[who], madam = who === "madam", s = right ? 1 : -1, lashC = "#ece8f6";
    if(e.closed === "joy"){
      c.save(); c.beginPath(); c.rect(-R*2, -R*2, R*4, R*4); c.arc(0, R*.8, R*.84, 0, TAU); c.clip("evenodd");
      const cg = c.createLinearGradient(0, -R*.35, 0, R*.1); cg.addColorStop(0, "#fff"); cg.addColorStop(1, "#d9d7e1");
      c.fillStyle = cg; c.beginPath(); c.arc(0, R*.42, R*.78, 0, TAU); c.fill(); c.restore();
      if(st.lashes){ c.save(); c.translate(0, R*.42); c.fillStyle = lashC; [1, 1.24].forEach((a, i) => lash(c, R*.74, a, R*(.3 - i*.06), R*.07, s)); c.restore(); }
      return; }
    const shut = !!e.closed, top = shut ? .9 : Math.max(-.1, Math.min(1.02, st.rest + e.up*(1 - st.rest) + Math.max(0, e.py)*.1));
    const tilt = (right ? -e.ang : e.ang)*.57, pup = Math.max(.7, Math.min(1.25, e.pupil/.42));
    const gx = Math.max(-1, Math.min(1, e.px/.68)), gy = Math.max(-1, Math.min(1, e.py/.68)), small = R < 10;
    c.save(); c.beginPath(); c.arc(0, 0, R, 0, TAU); c.clip();
    const g0 = c.createRadialGradient(-R*.3, -R*.38, R*.05, 0, 0, R*1.05);
    g0.addColorStop(0, "#fff"); g0.addColorStop(.62, "#f3f2ef"); g0.addColorStop(1, "#d3d1dc"); c.fillStyle = g0; c.fillRect(-R, -R, 2*R, 2*R);
    const ix = gx*R*.34, iy = gy*R*.3, ri = R*st.iris*pup;
    if(e.spiral > .5){ c.strokeStyle = st.irisC[1]; c.lineWidth = R*.13; c.lineCap = "round"; c.beginPath();
      for(let k = 0; k <= 60; k++){ const q = k/60, a = e.spin + q*Math.PI*5, rr = R*.76*q; k ? c.lineTo(Math.cos(a)*rr, Math.sin(a)*rr) : c.moveTo(Math.cos(a)*rr, Math.sin(a)*rr); } c.stroke(); }
    else if(e.heart <= .02){
      c.save(); c.beginPath(); c.arc(ix, iy, ri, 0, TAU); c.clip();
      const ig = c.createLinearGradient(0, iy - ri, 0, iy + ri); [0, .5, .84, 1].forEach((o, i) => ig.addColorStop(o, st.irisC[i]));
      c.fillStyle = ig; c.fillRect(ix - ri, iy - ri, 2*ri, 2*ri);
      c.fillStyle = "rgba(4,3,8,.75)"; c.beginPath(); c.arc(ix, iy - ri*.06, ri*.46, 0, TAU); c.fill(); c.restore();
      c.fillStyle = "#fff"; c.beginPath(); c.arc(-R*.22 + ix*.3, -R*.25 + iy*.3, R*(small ? .2 : st.spot*(wet ? 1.25 : 1)*.8), 0, TAU); c.fill(); }
    const N = 24, xs = [...Array(N + 1)].map((_, i) => -R*1.05 + 2.1*R*i/N), Y = x => lidY(R, top, tilt, x, right);
    if(top > -.05){
      c.beginPath(); c.moveTo(-R*1.1, -R*1.2); xs.forEach(x => c.lineTo(x, Y(x))); c.lineTo(R*1.1, -R*1.2); c.closePath();
      const lg = c.createLinearGradient(0, -R, 0, Math.max(-R + 1, Y(0)));
      if(madam){ lg.addColorStop(0, "#fbfaf8"); lg.addColorStop(1, "#e3dfeb"); } else { lg.addColorStop(0, small ? "#f1f0f3" : "#e4e3e9"); lg.addColorStop(1, small ? "#dcdae2" : "#c8c6d1"); }
      c.fillStyle = lg; c.fill();
      const k = small ? .7 : 1, wv = x => { if(madam){ const t = (x*s/R + 1.05)/2.1; return k*(R*.035 + R*.105*t*t); } return k*R*(.035 + .035*(1 - (x/R)**2)); }, a = madam ? .3 : .4;
      c.beginPath(); xs.forEach((x, i) => i ? c.lineTo(x, Y(x) - wv(x)*a) : c.moveTo(x, Y(x) - wv(x)*a)); [...xs].reverse().forEach(x => c.lineTo(x, Y(x) + wv(x)*(1 - a)));
      c.closePath(); c.fillStyle = madam ? "#1b1724" : "#2b2f37"; c.fill(); }
    c.restore();
    if(st.lashes){ const yL = Math.max(-R*.999, Math.min(R*.999, Y(s*R*.9))), la = Math.acos(-yL/R); c.fillStyle = lashC;
      [.78, 1.05, 1.32].forEach((a, i) => lash(c, R*.98, Math.max(a, la + .1 + i*.27), R*(.4 - i*.06), R*.075, s)); }
    if(e.heart > .02 && !shut){ const hw = R*.74*e.heart; c.save(); c.translate(ix*.3, iy*.3 + R*.05); heartPath(c, hw); c.clip();
      const hg = c.createLinearGradient(0, -hw, 0, hw); hg.addColorStop(0, "#e59392"); hg.addColorStop(1, "#c45a59"); c.fillStyle = hg; c.fillRect(-hw, -hw, 2*hw, 2*hw); c.restore(); }
  }
  function drop(c, x, y, r, color, a){ c.save(); c.globalAlpha = a; c.translate(x, y); c.fillStyle = color; c.beginPath(); c.moveTo(0, -r*1.8);
    c.bezierCurveTo(r*.2, -r*.9, r, -r*.3, r, r*.15); c.arc(0, r*.15, r, 0, Math.PI); c.bezierCurveTo(-r, -r*.3, -r*.2, -r*.9, 0, -r*1.8); c.fill(); c.restore(); }

  /* ---------- the face: two eyes in a box ---------- */
  function face(W, H, look){
    g.setTransform(D, 0, 0, D, 0, 0); g.clearRect(0, 0, W, H);
    const eh = 16, fw = eh*2.22; return drawFace(g, W/2, H/2, Math.min(eh/2*.94, fw/(4 + V2[who].gap)), look);
  }
  /* two eyes centred on (cx, cy), each R0 in radius; used by the bar and by the stage */
  function drawFace(g, cx, cy0, R0, look){
    const st = V2[who], cy = cy0 + look.hop*R0/7.5;
    g.save();
    if(look.squash){ g.translate(cx, cy + R0); g.scale(1 + .16*look.squash, 1 - .3*look.squash); g.translate(-cx, -cy - R0); }
    const cs = [look.l, look.r].map((e, i) => { const right = i === 1, gx = Math.max(-1, Math.min(1, e.px/.68)), gy = Math.max(-1, Math.min(1, e.py/.68));
      const x = cx + (right ? 1 : -1)*(R0 + R0*st.gap/2) + gx*R0*.12, y = cy + gy*R0*.08;
      g.save(); g.translate(x, y); if(e.closed === "blink" || e.closed === "sleep") g.scale(1.04, .92); eye(g, R0, e, right, look.tear != null); g.restore(); return [x, y]; });
    if(look.tear != null) cs.forEach((c, i) => { const q = (look.tear + i*.5) % 1, side = i ? 1 : -1;
      drop(g, c[0] + side*R0*.72, c[1] + R0*.6 + q*R0*1.3, R0*.16, TEAR, Math.min(1, (1 - q)*3)); });
    g.restore(); return cs;
  }

  /* ---------- how he lives ---------- */
  const T = () => performance.now()/1000;
  let P = { x:innerWidth*.4, y:innerHeight*.6 }, moved = T(), p = [[0, .1], [0, .1]], v = [[0, 0], [0, 0]], tgt = [[0, .1], [0, .1]];
  let up = [0, 0], ang = [0, 0], pupil = .42, micro = [0, 0], nextMicro = 0, blinkUntil = 0, nextBlink = T() + 1.6, flutterAt = 0;
  let winkAt = -100, pokes = [], pokeAt = -100, cryUntil = 0, loveAt = -100, happyUntil = 0, dizzy = 0, asleep = false, startleUntil = 0;
  let sign = 0, flips = [], lastX = P.x, lastT = T(), dropAt = 0, dropLeft = true;
  const bits = [];
  function love(t){ loveAt = t; happyUntil = t + 2.4 + .8; }
  function heartAmount(t){ const u = t - loveAt; if(u < 0 || u >= 2.4) return 0;
    let x = 1 - Math.exp(-7*u)*Math.cos(15*u);
    for(const b of [.85, 1.1, 1.55, 1.8]){ const d = u - b; if(d > 0 && d < .2) x += .24*Math.sin(d/.2*Math.PI); }
    const out = 2.12; if(u > out){ const k = (u - out)/.28; x *= 1 - k*k; } return Math.max(0, x); }
  function setWho(w){ if(w !== "madam" && w !== "gentleman") return; who = w; try { localStorage.setItem("roomie-who", w); } catch(e){}
    mark(); label(); love(T() + .15); moved = T(); }
  /* the chosen one's button says so */
  function mark(){ document.querySelectorAll("[data-who]").forEach(b => { const on = b.dataset.who === who;
    if(!b.dataset.label) b.dataset.label = b.textContent; b.setAttribute("aria-pressed", String(on));
    b.textContent = on ? (b.dataset.who === "madam" ? "She lives here" : "He lives here") : b.dataset.label; }); }
  document.querySelectorAll("[data-who]").forEach(b => b.addEventListener("click", () => setWho(b.dataset.who))); mark();

  addEventListener("pointermove", e => { const t = T(), dt = Math.max(.001, t - lastT), vx = (e.clientX - lastX)/dt; lastX = e.clientX; lastT = t;
    const sg = Math.abs(vx) > 1300 ? Math.sign(vx) : 0; if(sg && sg !== sign){ if(sign) flips.push(t); sign = sg; }
    flips = flips.filter(f => t - f < .9); if(flips.length >= 4 && sg) dizzy = Math.min(1.7, dizzy + .07);
    P = { x:e.clientX, y:e.clientY }; moved = t; });
  addEventListener("pointerdown", e => { P = { x:e.clientX, y:e.clientY }; moved = T(); });
  addEventListener("keydown", () => { moved = T(); });
  addEventListener("scroll", () => { moved = T(); }, { passive:true });
  function poke(){ const t = T(); pokeAt = t; happyUntil = 0; loveAt = -100; moved = t;
    pokes = pokes.filter(q => t - q < 30).concat(t); if(pokes.length >= 3){ cryUntil = t + .9 + 4; pokes = []; } }
  cv.addEventListener("click", poke);
  const label = () => cv.setAttribute("aria-label", "Roomie. Click to poke. Three times and " + (who === "madam" ? "she" : "he") + " cries.");
  cv.setAttribute("role", "button"); cv.setAttribute("tabindex", "0"); label();
  cv.addEventListener("keydown", e => { if(e.key === "Enter" || e.key === " "){ e.preventDefault(); cv.click(); } });
  love(T() + 1.2);

  const clock = document.querySelector("time[data-clock]");
  function tickClock(){ if(!clock) return; const d = new Date();
    clock.textContent = d.toLocaleDateString("en-GB", { weekday:"short", day:"numeric", month:"short" }) + "  " + d.toLocaleTimeString("en-GB", { hour:"2-digit", minute:"2-digit" }); }
  tickClock(); setInterval(tickClock, 20000);

  function frame(){
    const t = T(), dt = Math.min(.05, t - (frame.last || t)); frame.last = t;
    const b = cv.getBoundingClientRect(), w = b.width, h = b.height;
    if(cv.width !== Math.round(w*D) || cv.height !== Math.round(h*D)){ cv.width = Math.round(w*D); cv.height = Math.round(h*D); }
    const madam = who === "madam";
    /* asleep after a while with nothing happening on the page; glad when you are back */
    const idle = t - moved;
    if(idle > 45) asleep = true; else if(asleep){ asleep = false; startleUntil = t + .35; love(t + .35); }
    dizzy = Math.max(0, dizzy - dt*(dizzy > 1 ? .45 : .22));
    const dz = Math.max(0, Math.min(1, (dizzy - .55)/.35)), wince = t - pokeAt < .9, crying = !wince && t < cryUntil;
    const heart = heartAmount(t), startled = t < startleUntil, happy = t < happyUntil && heart === 0 && !startled && !crying;
    if(t > nextBlink){ blinkUntil = t + .13; if(madam && Math.random() < .35) flutterAt = blinkUntil + .12; nextBlink = t + 1.8 + Math.random()*4.2; }
    if(flutterAt && t >= flutterAt){ blinkUntil = t + .11; flutterAt = 0; }
    const [K, C, lazy, microEvery, microSize] = madam ? [150, 9, .03, .9, .05] : [55, 7.2, .14, 2.6, .03];
    if(t > nextMicro){ micro = [(Math.random()*2 - 1)*microSize, (Math.random()*2 - 1)*microSize*.7]; nextMicro = t + microEvery*(.6 + Math.random()*.8); }
    const look = { l:null, r:null, tear:null, hop:0, squash:0 };
    for(let i = 0; i < 2; i++){
      const L = .68, ex = b.left + w/2 + (i ? 10 : -10), ey = b.top + h/2;
      const dx = P.x - ex, dy = P.y - ey, d = Math.hypot(dx, dy) || 1, k = Math.min(1, d/420), near = 1 - k;
      let tx = dx/d*k*L, ty = dy/d*k*L;
      if(dz > .5){ const a = t*8*(i ? -1 : 1) + i*2; tx = Math.cos(a)*L; ty = Math.sin(a)*L; }
      else if(crying){ tx = -tx*.6; ty = L*.55; }
      else if(asleep){ tx *= .3; ty = L*.6; }
      if(dz <= .5 && !crying){ if(Math.hypot(tx - tgt[i][0], ty - tgt[i][1]) > lazy){
          if(i === 0 && Math.hypot(tx - tgt[i][0], ty - tgt[i][1]) > .6 && t > blinkUntil + .6) blinkUntil = t + .12;
          tgt[i] = [tx, ty]; }
        tx = tgt[i][0] + micro[0]; ty = tgt[i][1] + micro[1]; } else tgt[i] = [tx, ty];
      v[i][0] += (K*(tx - p[i][0]) - C*v[i][0])*dt; v[i][1] += (K*(ty - p[i][1]) - C*v[i][1])*dt;
      p[i][0] += v[i][0]*dt; p[i][1] += v[i][1]*dt;
      const m = Math.hypot(p[i][0], p[i][1]); if(m > L){ const nx = p[i][0]/m, ny = p[i][1]/m, vn = v[i][0]*nx + v[i][1]*ny; p[i][0] = nx*L; p[i][1] = ny*L; if(vn > 0){ v[i][0] -= 1.5*vn*nx; v[i][1] -= 1.5*vn*ny; } }
      const q = Math.min(1, dt*14); up[i] += ((crying ? .3 : dz*(i ? .05 : .16)) - up[i])*q; ang[i] += ((crying ? (i ? .42 : -.42) : 0) - ang[i])*q;
      if(!i) pupil += ((startled ? .24 : crying ? .32 : .37 + .17*near + (madam ? .02 : 0)) - pupil)*Math.min(1, dt*6);
      const e = { px:p[i][0], py:p[i][1], pupil, up:startled ? 0 : up[i], ang:ang[i], closed:null, spiral:dz, spin:t*7*(i ? -1 : 1), heart:0 };
      if(heart > 0){ e.heart = heart; e.up = madam ? -.25 : -.55; }
      if(wince){ if(t - pokeAt < .14) e.closed = "blink"; }
      else if(asleep) e.closed = "sleep";
      else if(happy) e.closed = "joy";
      else if(t < blinkUntil && heart === 0 && !startled) e.closed = "blink";
      /* goodbye: she winks, one eye shut while the other stays on you; he closes both, slowly, a small bow */
      const wu = t - winkAt; if(wu > 0 && wu < (madam ? .85 : .6) && !asleep && (i === 1 || !madam)){ e.closed = "blink"; }
      if(i) look.r = e; else look.l = e;
    }
    if(crying) look.tear = (t*.7) % 1;
    const pu = t - pokeAt; if(pu >= 0 && pu < .9 && !crying) look.squash = Math.exp(-6*pu)*Math.cos(14*pu);
    const lu = t - loveAt; if(lu >= 0 && lu < .35) look.hop = -Math.sin(lu/.35*Math.PI)*2.5;
    const cs = face(w, h, look); shared.look = look;
    /* the tears that fall out of the bar and down the page */
    if(crying && !still && t - dropAt > 1){ dropAt = t; dropLeft = !dropLeft; bits.push({ k:0, x:b.left + cs[dropLeft ? 0 : 1][0], y:b.bottom + 2, vy:30, age:0, s:4.5 }); }
    const W = innerWidth, H = innerHeight;
    if(rain.width !== Math.round(W*D) || rain.height !== Math.round(H*D)){ rain.width = Math.round(W*D); rain.height = Math.round(H*D); }
    rg.setTransform(D, 0, 0, D, 0, 0); rg.clearRect(0, 0, W, H);
    for(let j = bits.length - 1; j >= 0; j--){ const q = bits[j]; q.age += dt;
      if(q.k === 0){ q.vy += 520*dt; q.y += q.vy*dt;
        if(q.y >= H - 4){ bits.splice(j, 1); for(let n = -1; n <= 1; n++) bits.push({ k:3, x:q.x, y:H - 5, vx:n*70 + (Math.random() - .5)*40, vy:-150 - Math.random()*80, age:0, life:.5, s:q.s*.42 }); continue; }
        drop(rg, q.x, q.y, q.s, TEAR, 1); }
      else { q.vy += 1100*dt; q.x += q.vx*dt; q.y += q.vy*dt; if(q.age >= q.life){ bits.splice(j, 1); continue; }
        drop(rg, q.x, q.y, q.s, TEAR, Math.max(0, Math.min(1, (q.life - q.age)/.35))); } }
    requestAnimationFrame(frame);
  }
  /* the stage (stage.js) draws the same roommate, bigger, from the same feelings */
  const shared = window.Roomie = { look: null, drawFace, poke, love: () => love(T()), wink: (delay = .15) => { winkAt = T() + delay; moved = T(); }, get who(){ return who; } };
  requestAnimationFrame(frame);
})();

/* on a phone there is nothing to download to: send the link to yourself instead */
document.querySelectorAll("[data-share]").forEach(b => b.addEventListener("click", async () => {
  const url = location.href.split("#")[0], text = "Roomie: a pair of eyes for my Mac's menu bar";
  try { if(navigator.share){ await navigator.share({ title: "Roomie", text, url }); return; }
        await navigator.clipboard.writeText(url); b.textContent = "Link copied"; } catch(e){} }));


/* a last smile: reach the end of the page and, once you have stopped scrolling, they say goodbye in the bar */
(function(){ const f = document.querySelector("footer"); if(!f || !window.Roomie) return;
  let last = -1e9, timer = 0;
  const atEnd = () => innerHeight + scrollY >= document.documentElement.scrollHeight - 40;
  addEventListener("scroll", () => { clearTimeout(timer); timer = setTimeout(() => { const t = performance.now();
    if(atEnd() && t - last > 8000){ last = t; window.Roomie.wink(.1); } }, 450); }, { passive: true });
 })();

/* the makers' marks: a tap shows the name for a moment, like a hover does */
document.querySelectorAll(".maker").forEach(m => m.addEventListener("click", () => { m.classList.add("on"); clearTimeout(m._t); m._t = setTimeout(() => m.classList.remove("on"), 1800); }));
