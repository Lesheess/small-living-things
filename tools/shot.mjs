/* Capture a page at an exact device size through the Chrome DevTools
   Protocol, with Node's own WebSocket: no puppeteer, no npm.
   node rig/shot.mjs <url> <out.png> <width> <height> [dpr=1] [mobile=0] [full=0] [js-before-shot] */
import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
const [url, out, W, H, dpr = "1", mobile = "0", full = "0", pre = ""] = process.argv.slice(2);
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const port = 9300 + Math.floor(Math.random()*500);
const prof = mkdtempSync(tmpdir() + "/shot-");
const ch = spawn(CHROME, ["--headless=new", "--disable-gpu", "--hide-scrollbars", `--remote-debugging-port=${port}`,
  `--user-data-dir=${prof}`, "about:blank"], { stdio:"ignore" });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let ws, id = 0; const wait = new Map();
const send = (method, params = {}) => new Promise(res => { const i = ++id; wait.set(i, res); ws.send(JSON.stringify({ id:i, method, params })); });
try{
  let target;
  for(let k = 0; k < 50 && !target; k++){ await sleep(150);
    try{ const l = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); target = l.find(t => t.type === "page"); }catch(e){} }
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise(r => ws.addEventListener("open", r));
  ws.addEventListener("message", m => { const d = JSON.parse(m.data); if(d.id && wait.has(d.id)){ wait.get(d.id)(d.result); wait.delete(d.id); } });
  await send("Emulation.setDeviceMetricsOverride", { width:+W, height:+H, deviceScaleFactor:+dpr, mobile: mobile === "1" });
  await send("Page.enable");
  await send("Page.navigate", { url });
  await sleep(4500);
  if(pre) { await send("Runtime.evaluate", { expression: pre, awaitPromise:true }); await sleep(1600); }
  let clip;
  if(full === "1"){ const m = await send("Page.getLayoutMetrics");
    const cs = m.cssContentSize || m.contentSize; clip = { x:0, y:0, width:+W, height:Math.ceil(cs.height), scale:1 }; }
  const shot = await send("Page.captureScreenshot", { format:"png", captureBeyondViewport: full === "1", ...(clip ? { clip } : {}) });
  writeFileSync(out, Buffer.from(shot.data, "base64"));
  console.log("wrote", out);
} finally { try{ ws && ws.close(); }catch(e){} ch.kill(); }
