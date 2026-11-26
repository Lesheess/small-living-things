/* They dance (Roomie 0.9). A button plays a song made right here in the browser, at 112 bpm, the same one as in the film:
   four on the floor, a clap on 2 and 4, hats, a disco bass, chord stabs and a little hook in A minor. The beat clock is pinned
   to when the sound leaves the speakers, so every move lands on its beat. The moves are the app's (roomie/main.swift: applyDance).
   Needs roomie.js first. window.RoomieDance = { on, toggle(), apply(look, who), notes(g, cx, cy, R0, look, who), transform(g, cx, cy, R0, look) } */
(function(){
  const BPM = 112, P = 60/BPM, T = () => performance.now()/1000;
  let ac = null, master = null, timer = 0, on = false, nextNote = 0, step = 0, ctx0 = 0, t0 = 0, amt = 0, last = T(), startedAt = 0;

  /* ---- the song ---- */
  function audio(){ if(!ac){ ac = new (window.AudioContext || window.webkitAudioContext)(); master = ac.createGain(); master.gain.value = .55;
      const comp = ac.createDynamicsCompressor(); comp.threshold.value = -14; comp.ratio.value = 4; master.connect(comp).connect(ac.destination); }
    if(ac.state === "suspended") ac.resume(); return ac; }
  let noiseBuf = null;
  function noise(){ if(!noiseBuf){ noiseBuf = ac.createBuffer(1, ac.sampleRate, ac.sampleRate); const d = noiseBuf.getChannelData(0); for(let i = 0; i < d.length; i++) d[i] = Math.random()*2 - 1; }
    const s = ac.createBufferSource(); s.buffer = noiseBuf; return s; }
  function env(g, t, peak, a, d){ g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(peak, t + a); g.gain.exponentialRampToValueAtTime(0.0001, t + a + d); }
  function pan(x){ const p = ac.createStereoPanner ? ac.createStereoPanner() : null; if(p){ p.pan.value = x; p.connect(master); return p; } return master; }
  function kick(t){ const o = ac.createOscillator(), g = ac.createGain(); o.frequency.setValueAtTime(160, t); o.frequency.exponentialRampToValueAtTime(46, t + .12);
    env(g, t, .95, .003, .38); o.connect(g).connect(master); o.start(t); o.stop(t + .42); }
  function clap(t){ const n = noise(), f = ac.createBiquadFilter(), g = ac.createGain(); f.type = "bandpass"; f.frequency.value = 1500; f.Q.value = .8;
    g.gain.setValueAtTime(.0001, t); [0, .012, .024].forEach(d => { g.gain.setValueAtTime(.5, t + d); g.gain.exponentialRampToValueAtTime(.08, t + d + .01); });
    g.gain.exponentialRampToValueAtTime(.0001, t + .2); n.connect(f).connect(g).connect(master); n.start(t, Math.random()*.5); n.stop(t + .22); }
  function hat(t, open, x){ const n = noise(), f = ac.createBiquadFilter(), g = ac.createGain(); f.type = "highpass"; f.frequency.value = open ? 6500 : 8000;
    env(g, t, open ? .16 : .09, .002, open ? .22 : .04); n.connect(f).connect(g).connect(pan(x)); n.start(t, Math.random()*.5); n.stop(t + (open ? .26 : .06)); }
  function tone(t, f0, dur, peak, type, cut, x){ const o = ac.createOscillator(), fl = ac.createBiquadFilter(), g = ac.createGain();
    o.type = type; o.frequency.value = f0; fl.type = "lowpass"; fl.frequency.setValueAtTime(cut, t); fl.frequency.exponentialRampToValueAtTime(Math.max(200, cut*.25), t + dur);
    env(g, t, peak, .006, dur); o.connect(fl).connect(g).connect(pan(x || 0)); o.start(t); o.stop(t + dur + .05); }
  const ROOTS = [55, 43.65, 65.41, 49], CHORDS = [[220, 261.63, 329.63], [174.61, 220, 261.63], [261.63, 329.63, 392], [196, 246.94, 293.66]];
  const HOOK = [[659.3, 0, 523.3, 587.3, 659.3, 0, 784, 659.3], [587.3, 0, 523.3, 440, 523.3, 0, 0, 0], [659.3, 0, 523.3, 587.3, 659.3, 0, 784, 880], [784, 0, 659.3, 0, 587.3, 0, 523.3, 0]];
  function beat(k, t){ const bar = Math.floor(k/4), inBar = k % 4, ch = bar % 4;
    kick(t); if(inBar === 1 || inBar === 3) clap(t);
    hat(t, false, -.2); hat(t + P/4, false, -.2); hat(t + P/2, true, .25); hat(t + 3*P/4, false, -.2);
    tone(t, ROOTS[ch], P*.45, .5, "sawtooth", 700); tone(t + P/2, ROOTS[ch]*2, P*.4, .38, "sawtooth", 900);
    if(inBar === 1 || inBar === 3) CHORDS[ch].forEach((f, n) => tone(t + P/2, f, .32, .07, "sawtooth", 2400, (n - 1)*.4));
    if(bar >= 2){ const line = HOOK[(bar - 2) % 4]; for(let e = 0; e < 2; e++){ const f = line[inBar*2 + e]; if(f) tone(t + e*P/2, f, P*.46, .11, "triangle", 5000, .1); } } }
  function start(){ audio(); stop(true); on = true; startedAt = T();
    nextNote = ac.currentTime + .12; ctx0 = nextNote; step = 0; t0 = T() + .12;
    timer = setInterval(() => { while(nextNote < ac.currentTime + .2){ beat(step, nextNote); nextNote += P; step++; } }, 25);
    document.dispatchEvent(new CustomEvent("roomie-dance", { detail: true })); }
  function stop(quiet){ clearInterval(timer); timer = 0;
    if(on && ac && master){ const t = ac.currentTime; master.gain.cancelScheduledValues(t); master.gain.setValueAtTime(master.gain.value, t); master.gain.linearRampToValueAtTime(.0001, t + .25);
      setTimeout(() => { if(!on && master) master.gain.value = .55; }, 400); }
    on = false; if(!quiet) document.dispatchEvent(new CustomEvent("roomie-dance", { detail: false })); }
  document.addEventListener("visibilitychange", () => { if(document.hidden && on) stop(); });

  /* where the beat is now: beat 0 is pinned to when the first kick leaves the speakers (Bluetooth adds a quarter second) */
  function beatNow(){ const t = T();
    if(ac && ac.getOutputTimestamp){ const ts = ac.getOutputTimestamp(); if(ts.contextTime > 0 && ts.performanceTime > 0) t0 = ts.performanceTime/1000 + (ctx0 - ts.contextTime); }
    return (t - t0)/P + 8; }                                  /* +8: start a little way into the phrase, so the squint comes soon */

  /* ---- the moves (the app's applyDance) ---- */
  function apply(look, who){
    const t = T(), dt = Math.min(.1, t - last); last = t;
    amt += ((on ? 1 : 0) - amt)*Math.min(1, dt*(on ? 2.5 : 4));
    if(amt < .002 || !look) return look;
    const b = beatNow(), ph = b - Math.floor(b), bar = Math.floor(b/4), inBar = b - Math.floor(b/4)*4, phrase = ((bar % 8) + 8) % 8;
    const sure = 1, hit = Math.exp(-ph*7)*sure, soft = .5 - .5*Math.cos(ph*Math.PI*2), A = amt, mix = (a, v) => a + (v - a)*A;
    let tilt, dx, hop, squash, px, py, up, pupil, joy = false, heart = 0, wink = false, brow = false;
    if(who === "madam"){ const sway = Math.sin(Math.PI*b/2);
      tilt = .13*sway; dx = 1.6*sway; hop = .9*hit - .5*(1 - hit)*sure*Math.min(1, ph*3); squash = .3*hit; px = .35*sway; py = -.15; pupil = .42 + .07*hit; up = -.05;
      joy = ((phrase === 1 || phrase === 3) && inBar >= 2) || (phrase === 6 && inBar >= 1);
      if(phrase === 7) heart = .78 + .3*hit + .08*soft;
      wink = phrase === 5 && inBar >= 3 && inBar < 3.5; }
    else { const sway = Math.sin(Math.PI*b/2);
      tilt = .07*sway; dx = 1.2*sway; hop = 1.1*hit; squash = .14*hit; px = .3*sway; py = -.05; up = -.12 - .14*hit; pupil = .42 + .05*hit;
      joy = ((phrase === 1 || phrase === 3 || phrase === 5) && inBar >= 2) || phrase === 7;
      brow = phrase === 6 && inBar < 2; }
    const out = Object.assign({}, look, { tilt: mix(look.tilt || 0, tilt), dx: mix(look.dx || 0, dx), hop: mix(look.hop || 0, hop), squash: mix(look.squash || 0, squash) });
    out.l = Object.assign({}, look.l); out.r = Object.assign({}, look.r);
    [out.l, out.r].forEach((e, i) => {
      e.px = mix(e.px, brow ? .5 : px); e.py = mix(e.py, py); e.pupil = mix(e.pupil, pupil); e.up = mix(e.up, brow && i === 0 ? -.45 : up);
      if(amt > .85){ if(joy) e.closed = "joy"; else if(wink && i === 1) e.closed = "blink"; else if(e.closed === "joy") e.closed = null;
        if(heart && !joy){ e.heart = heart; e.up = -.25; if(e.closed === "blink") e.closed = null; } } });
    if(amt > .5){ out.beat = b; out.beatLen = P; }
    return out; }

  /* the face slides and tilts about its centre */
  function transform(g, cx, cy, R0, look){ if(look.dx || look.tilt){ g.translate(cx + (look.dx || 0)*R0/7.5, cy); g.rotate(look.tilt || 0); g.translate(-cx, -cy); } }

  /* a quiet note now and then: hers every two beats, his every four; it floats up beside them and fades */
  const COLS = { madam: ["#8f80eb", "#cd6766", "#f2f1ec"], gentleman: ["#f2f1ec", "#9fb0c4", "#8f80eb"] };
  function eighth(g, x, y, s, beamed){
    const head = (hx, hy) => { g.save(); g.translate(hx, hy); g.rotate(-.35); g.beginPath(); g.ellipse(0, 0, s*.3, s*.21, 0, 0, Math.PI*2); g.fill(); g.restore(); };
    g.lineWidth = Math.max(.7, s*.11); g.lineCap = "round";
    if(!beamed){ head(x, y); g.beginPath(); g.moveTo(x + s*.27, y - s*.06); g.lineTo(x + s*.27, y - s*1.05); g.quadraticCurveTo(x + s*.36, y - s*.72, x + s*.62, y - s*.58); g.stroke(); }
    else { const w = s*.62; head(x, y); head(x + w, y - s*.12);
      g.beginPath(); g.moveTo(x + s*.27, y - s*.06); g.lineTo(x + s*.27, y - s*1.02); g.moveTo(x + w + s*.27, y - s*.18); g.lineTo(x + w + s*.27, y - s*1.14); g.stroke();
      g.lineWidth = Math.max(1, s*.2); g.lineCap = "butt"; g.beginPath(); g.moveTo(x + s*.22, y - s*1.0); g.lineTo(x + w + s*.32, y - s*1.12); g.stroke(); } }
  function notes(g, cx, cy, R0, look, who){
    if(look.beat == null) return;
    const every = who === "madam" ? 2 : 4, life = 1.7, cols = COLS[who], lastI = Math.floor(look.beat/every);
    for(let i = lastI - 3; i <= lastI; i++){
      const age = (look.beat - i*every)*look.beatLen; if(age < 0 || age > life) continue;
      const u = age/life, side = (i & 1) ? 1 : -1, s = R0*(.5 + .12*u);
      const x = cx + side*R0*(2.2 + .25*u) + Math.sin(u*Math.PI*2)*R0*.12 - s*.3, y = cy - R0*(.1 + 1.6*u);
      g.save(); g.globalAlpha = .85*Math.min(1, u*6)*Math.min(1, (1 - u)*2.2); g.fillStyle = g.strokeStyle = cols[((i % 3) + 3) % 3];
      eighth(g, x, y, s, ((i % 4) + 4) % 4 === 3); g.restore(); } }

  window.RoomieDance = { get on(){ return on; }, get amount(){ return amt; }, get since(){ return startedAt; },
    toggle(){ on ? stop() : start(); return on; }, apply, transform, notes };
})();
