/* The stage: a close-up of a Mac's menu bar with its notch, Roomie living at the right of it, and now and then
   their card springing out of the notch with one of their lines, the way the app does it (roomie/main.swift:
   Island, paintIsland). Everything is drawn here in code. Needs roomie.js first (window.Roomie).
   <canvas data-stage> anywhere on the page. Click the eyes to poke them; click the card to answer it. */
(function(){
  const R = window.Roomie, cv = document.querySelector("canvas[data-stage]");
  if(!R || !cv) return;
  const g = cv.getContext("2d"), D = Math.min(2, devicePixelRatio || 1), still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const BW = 640, BH = 200;                                   /* the stage is drawn in these units, then scaled to fit */
  const LINES = {
    madam: ["Darling, your eyes. Look at something far away for twenty seconds. I'll count.",
            "Half an hour in that chair. Up you get: walk for five minutes.",
            "Going, you said. Darling, I can see you."],
    gentleman: ["Twenty minutes, if I may. Kindly look at something twenty feet away. I shall count.",
                "Might I suggest a stroll? Five minutes. I shall hold the fort.",
                "A remarkably brief stroll, if I may say so."] };
  const BUTTONS = { madam: [["Okay", "Later"], ["Going", "Later"], null], gentleman: [["Very well", "Later"], ["Going", "Later"], null] };
  const T = () => performance.now()/1000;
  const ACCENT = { madam: "rgba(143,128,235,A)", gentleman: "rgba(143,166,186,A)" };
  let closedAt = -1e9;
  function star(x, y, r, a, col){ if(r <= .2) return; g.save(); g.translate(x, y); g.globalAlpha = a; g.fillStyle = col; const k = r*.16; g.beginPath(); g.moveTo(0, -r);
    g.quadraticCurveTo(k, -k, r, 0); g.quadraticCurveTo(k, k, 0, r); g.quadraticCurveTo(-k, k, -r, 0); g.quadraticCurveTo(-k, -k, 0, -r); g.fill(); g.restore(); }
  let mouse = { x: -1e4, y: -1e4 }, scale = 1, box = null;
  addEventListener("pointermove", e => { mouse = { x: e.clientX, y: e.clientY }; });

  /* the card: a spring for its size, like the app's (k 230, c 23) */
  const NOTCH = { w: 190, h: 40 }, CARD_W = 340;
  let size = { w: NOTCH.w, h: NOTCH.h }, vel = { w: 0, h: 0 }, open = false, alpha = 0, line = 0, since = T(), nextAt = T() + 0.3, rounds = 0;
  function target(){ return open ? { w: CARD_W, h: NOTCH.h + cardH() } : { w: NOTCH.w, h: NOTCH.h }; }
  let wrapped = [], cardHc = 0;
  function cardH(){ return cardHc; }
  function layout(){
    const who = R.who, text = LINES[who][line], btn = BUTTONS[who][line];
    g.font = "600 15px 'Golos Text', -apple-system, sans-serif";
    wrapped = wrap(text, CARD_W - 16 - 64 - 12 - 18);
    cardHc = 16 + Math.max(44, wrapped.length*20) + (btn ? 14 + 32 : 0) + 16;
  }
  function wrap(text, width){ const words = text.split(" "), out = []; let cur = "";
    for(const w of words){ const t = cur ? cur + " " + w : w; if(g.measureText(t).width > width && cur){ out.push(cur); cur = w; } else cur = t; }
    if(cur) out.push(cur); return out; }

  /* the island's shape: flush with the top, little concave flares where it meets the bar, rounded below */
  function shape(x, w, h){
    const f = 6, r = Math.min(h/2, 9 + Math.max(0, h - NOTCH.h)*0.4, 30);
    g.beginPath(); g.moveTo(x - f, 0); g.arcTo(x, 0, x, f, f); g.arcTo(x, h, x + w/2, h, r); g.arcTo(x + w, h, x + w, 0, r);
    g.arcTo(x + w, 0, x + w + f, 0, f); g.closePath(); }
  function roundRect(x, y, w, h, r){ g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }

  /* the same feelings as the bar's eyes, with the gaze worked out from where these eyes are */
  function lookFrom(cx, cy, toward){
    const base = R.look; if(!base) return null;
    const L = .68; let dx, dy;
    if(toward){ dx = toward.x - cx; dy = toward.y - cy; }
    else { const b = cv.getBoundingClientRect(); dx = mouse.x - (b.left + cx*scale); dy = mouse.y - (b.top + cy*scale); }
    const d = Math.hypot(dx, dy) || 1, k = toward ? 1 : Math.min(1, d/(320*scale));
    const eye = e => (e.closed || e.spiral > .5) ? e : Object.assign({}, e, { px: dx/d*k*L, py: dy/d*k*L });
    return Object.assign({}, base, { l: eye(base.l), r: eye(base.r) });
  }

  function frame(){
    const t = T(), b = cv.getBoundingClientRect(), W = b.width, H = W*BH/BW;
    if(Math.abs(cv.height/D - H) > .5 || cv.width !== Math.round(W*D)){ cv.width = Math.round(W*D); cv.height = Math.round(H*D); cv.style.height = H + "px"; }
    scale = W/BW;
    /* the rhythm: a pause, the card springs out, stays to be read, folds back, the next line */
    /* three rounds, then they rest; a click on the stage starts them again */
    if(!open && t > nextAt && rounds < 3){ layout(); open = true; since = t; rounds++; }
    if(open && t - since > (still ? 1e9 : 6.5)){ open = false; since = t; closedAt = t; nextAt = t + 2.2; line = (line + 1) % 3; }
    const tg = target(), n = 4, h = Math.min(.05, t - (frame.last || t))/n; frame.last = t;
    /* a liquid spring, as in the app: opening, the height leads and bounces a touch; closing, the width pulls in first */
    const op = tg.h > size.h, kw = op ? 200 : 260, cw = op ? 24 : 26, kh = op ? 270 : 220, ch = op ? 19 : 24;
    for(let i = 0; i < n; i++){ vel.w += (kw*(tg.w - size.w) - cw*vel.w)*h; size.w += vel.w*h; vel.h += (kh*(tg.h - size.h) - ch*vel.h)*h; size.h += vel.h*h; }
    const near = Math.abs(size.h - tg.h) < Math.max(4, tg.h*.12);
    alpha = open && near ? Math.min(1, alpha + h*4*7) : Math.max(0, alpha - h*4*14);

    g.setTransform(D*scale, 0, 0, D*scale, 0, 0); g.clearRect(0, 0, BW, BH);
    /* the desktop: a deep, cool wallpaper */
    const bg = g.createLinearGradient(0, 0, 0, BH); bg.addColorStop(0, "#2a2f55"); bg.addColorStop(1, "#151726");
    roundRect(0, 0, BW, BH, 22); g.save(); g.clip(); g.fillStyle = bg; g.fillRect(0, 0, BW, BH);
    const glow = g.createRadialGradient(BW*.72, BH*.95, 10, BW*.72, BH*.95, BW*.7); glow.addColorStop(0, "rgba(120,100,230,.35)"); glow.addColorStop(1, "rgba(120,100,230,0)");
    g.fillStyle = glow; g.fillRect(0, 0, BW, BH);
    /* the menu bar */
    g.fillStyle = "rgba(14,15,24,.55)"; g.fillRect(0, 0, BW, NOTCH.h);
    g.font = "500 14px 'Golos Text', -apple-system, sans-serif"; g.fillStyle = "rgba(255,255,255,.62)"; g.textBaseline = "middle";
    ["File", "Edit"].forEach((w, i) => g.fillText(w, 26 + i*54, NOTCH.h/2 + 1));      /* a real menu never runs under the notch, nor under the card */
    g.textAlign = "right"; g.fillStyle = "rgba(255,255,255,.85)";
    g.fillText(new Date().toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" }), BW - 22, NOTCH.h/2 + 1);
    g.textAlign = "left";
    /* the card, grown out of the notch */
    const x = BW/2 - size.w/2, age = t - since;
    /* arriving: a glow in their colour and a band of light sweeping round the edge */
    if(open && age < 1.7){ const a = Math.sin(Math.min(1, age/1.7)*Math.PI), acc = ACCENT[R.who];
      g.save(); g.shadowColor = acc.replace("A", (.95*a).toFixed(3)); g.shadowBlur = 24*scale*D; g.fillStyle = "#000"; shape(x, size.w, size.h); g.fill(); g.restore();
      g.save(); const c = { x: BW/2, y: size.h*.6 }, ang = age*4.2, rr = Math.max(size.w, size.h)*.6;
      const lg = g.createLinearGradient(c.x - Math.cos(ang)*rr, c.y - Math.sin(ang)*rr, c.x + Math.cos(ang)*rr, c.y + Math.sin(ang)*rr);
      [acc, "rgba(205,103,102,A)", "rgba(57,145,211,A)", "rgba(255,255,255,A)", acc].forEach((col, i) => lg.addColorStop(i/4, col.replace("A", a.toFixed(3))));
      g.strokeStyle = lg; g.lineWidth = 2.8; shape(x, size.w, size.h); g.stroke(); g.restore(); }
    g.fillStyle = "#000"; shape(x, size.w, size.h); g.fill();
    /* the roommate at the right of the bar; they glance at the card while it is out */
    const ex = BW - 112, ey = NOTCH.h/2, eR = 8;            /* true to size: in the bar they are as tall as the system's own icons */
    const cardCenter = { x: BW/2, y: NOTCH.h + 40 };
    box = { x: ex - eR*2.4, y: ey - eR*1.3, w: eR*4.8, h: eR*2.6 };
    /* teleport: they swell, squeeze flat and vanish from the bar as the card opens, and pop back home when it folds */
    let hs = 1, sq = 0, puff = -1;
    const e3 = u => u < .5 ? 4*u*u*u : 1 - Math.pow(-2*u + 2, 3)/2, pop = u => u <= 0 ? 0 : u >= .6 ? 1 : 1 - Math.exp(-9*u)*Math.cos(12*u);
    if(open){ if(age < .05) hs = 1 + .08*e3(age/.05); else if(age < .14){ const k = e3((age - .05)/.09); hs = 1.08*(1 - k); sq = k; } else hs = 0; if(age >= .1) puff = age - .1; }
    else { const u = t - closedAt - .12; if(u < 0) hs = 0; else if(u < .6){ hs = pop(u); puff = u; } }
    const barLook = lookFrom(ex, ey, null);
    if(barLook && hs > .01){ g.save(); g.translate(ex, ey); g.scale(Math.max(.01, hs + .5*sq), Math.max(.01, hs*(1 - .85*sq))); g.translate(-ex, -ey); R.drawFace(g, ex, ey, eR, barLook); g.restore(); }
    if(puff >= 0 && puff < .35){ const k = puff/.35, d = 4 + 9*(1 - Math.exp(-6*k));
      ["#ffffff", "#8f80eb", "#cd6766", "#ffffff"].forEach((col, i) => { const an = i*Math.PI/2 + .4; star(ex + Math.cos(an)*d*1.3, ey + Math.sin(an)*d*.55, 2.6*(1 - k), 1 - k, col); }); }
    if(alpha > .01){
      g.save(); g.globalAlpha = alpha; const who = R.who, btn = BUTTONS[who][line], cx0 = BW/2 - CARD_W/2, top = NOTCH.h;
      /* their face reads its own line */
      const fy = top + 16 + Math.max(44, wrapped.length*20)/2, fx = cx0 + 16 + 32;
      g.font = "600 15px 'Golos Text', -apple-system, sans-serif"; g.textBaseline = "middle";
      /* the words appear one after another, as if they were saying them */
      const ty = top + 16 + (Math.max(44, wrapped.length*20) - wrapped.length*20)/2 + 10; let wi = 0;
      wrapped.forEach((l, i) => { let wx = cx0 + 16 + 64 + 12; l.split(" ").forEach(word => { const k = Math.max(0, Math.min(1, (age - .18 - wi*.045)/.16));
        g.fillStyle = "rgba(255,255,255," + k.toFixed(3) + ")"; g.fillText(word, wx, ty + i*20); wx += g.measureText(word + " ").width; wi++; }); });
      if(btn){ const by0 = top + 16 + Math.max(44, wrapped.length*20) + 14, bw = (CARD_W - 32 - 10)/2;
        btn.forEach((label, i) => { const ba = Math.max(0, Math.min(1, (age - .4 - i*.07)/.22)), by = by0 + (1 - ba)*6; g.globalAlpha = alpha*ba;
          roundRect(cx0 + 16 + i*(bw + 10), by, bw, 32, 16); g.fillStyle = i ? "#2b2d33" : "#fff"; g.fill();
          g.fillStyle = i ? "#fff" : "#000"; g.font = "700 14px 'Golos Text', -apple-system, sans-serif"; g.textAlign = "center";
          g.fillText(label, cx0 + 16 + i*(bw + 10) + bw/2, by + 16); g.textAlign = "left"; }); }
      g.restore(); }
    /* their face pops into the card as it opens: they have just left the bar */
    if(open){ const fs = pop(age - .1), cx0 = BW/2 - CARD_W/2, fy = NOTCH.h + 16 + Math.max(44, wrapped.length*20)/2, fx = cx0 + 16 + 32;
      const cardLook = lookFrom(fx, fy, { x: fx + 200, y: fy + 30 });
      if(cardLook && fs > .01){ g.save(); shape(x, size.w, size.h); g.clip(); g.translate(fx, fy); g.scale(fs, fs); g.translate(-fx, -fy); R.drawFace(g, fx, fy, 13, cardLook); g.restore(); } }
    g.restore();
    requestAnimationFrame(frame);
  }
  /* a click on the eyes pokes them; a click on the card answers it, and they are pleased */
  cv.addEventListener("click", e => { const b = cv.getBoundingClientRect(), x = (e.clientX - b.left)/scale, y = (e.clientY - b.top)/scale;
    if(box && x > box.x && x < box.x + box.w && y > box.y && y < box.y + box.h){ R.poke(); return; }
    if(open && Math.abs(x - BW/2) < CARD_W/2 && y < NOTCH.h + cardH()){ open = false; since = T(); closedAt = T(); nextAt = T() + 2.2; line = (line + 1) % 3; R.love(); return; }
    if(!open && rounds >= 3){ rounds = 0; nextAt = T() + 0.2; } });
  cv.setAttribute("role", "img");
  cv.setAttribute("aria-label", "A Mac menu bar close up: Roomie's eyes live at the right, and their card springs out of the notch with a line, then folds back.");
  requestAnimationFrame(frame);
})();
