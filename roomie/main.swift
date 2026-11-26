/* =====================================================================
   ROOMIE 0.3 — a someone who lives in the menu bar (2026-11-19).
   Two living eyeballs (see drawEye). You choose who moves in: MADAM (open,
   slightly cat-like lids, quick darting looks, caring and a little sassy) or
   the GENTLEMAN (heavy lids, slow looks, dry as a butler). Each watches you and, by a few
   rules taken from research, nudges you:
     every 20 minutes at the screen     look at something far away for 20 s
                                        (the 20-20-20 rule, American Academy
                                        of Ophthalmology)
     every 30 minutes in the chair      a five-minute walk (Columbia, 2023:
                                        5 min every 30 min did best)
     past 00:30                         go to bed
   A nudge works like a Dynamic Island: a small black pill grows under the
   eyes and they keep glancing down at it. Click it (or them) and it opens
   into what they have to say. Ignore it and they get pushy; after a few
   minutes they give up and try later.
   Between nudges they only live: follow the pointer, blink, get dizzy when
   you shake the mouse, wince when poked and cry on the third poke, sweat
   when the Mac runs hot, droop when the battery is low, and a heart falls
   when you come back. Tears, a heart and a z fall down the screen.
   Right-click for the only menu: who lives here, Open at Login, Quit.
   What they read: the clock, seconds since any input, the pointer, battery,
   heat. Nothing on the screen, nothing typed, no network.
   Build: ./build.sh   Faces and island: Roomie --render out.png
   Rules: Roomie --selftest   Rules in seconds instead of minutes: --fast
   ===================================================================== */
import AppKit
import IOKit.ps
import ServiceManagement
import CoreAudio
import AVFoundation
import Accelerate

// MARK: - who

enum Who: String { case madam, gentleman }
let defaults = UserDefaults.standard
let FAST = CommandLine.arguments.contains("--fast"), LOG = ProcessInfo.processInfo.environment["ROOMIE_LOG"] != nil

// MARK: - what a face is

enum Closed { case blink, sleep, joy, wince, cry }
struct EyeLook {
  var px: CGFloat = 0.12, py: CGFloat = 0.1      /* pupil, in units of the eye's radius */
  var pupil: CGFloat = 0.42
  var up: CGFloat = 0, ang: CGFloat = 0
  var closed: Closed? = nil
  var spiral: CGFloat = 0, spin: CGFloat = 0
  var scale: CGFloat = 1
  var heart: CGFloat = 0                          /* > 0: the pupil is a heart this big (it springs past 1) */
  var low: CGFloat = 0                            /* the lower lid pushed up: a squint */
}
struct FaceLook { var l = EyeLook(), r = EyeLook(); var tear: CGFloat? = nil; var sweat: CGFloat? = nil; var hop: CGFloat = 0; var squash: CGFloat = 0
  var sparkle: CGFloat? = nil                     /* > nil: little stars twinkle round them; the value is a clock in seconds */
  var battery: CGFloat? = nil                     /* > nil: a little empty battery blinks by them (low battery); a clock */
  var zzz: CGFloat? = nil                         /* > nil: z's drift up from them (asleep); a clock in seconds */
  /* 0.9, dancing: the head tilts and slides; little notes float up beside them, counted in beats */
  var tilt: CGFloat = 0, dx: CGFloat = 0
  var beat: CGFloat? = nil, beatLen: CGFloat = 0.5, noteEvery: CGFloat = 2
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
let INK = rgb(0.09, 0.085, 0.10)
/* no yellow (the owner's call, 2026-11-16): her lids are a soft lilac, his a quiet grey */
func lidColor(_ who: Who?) -> (CGColor, CGColor) {
  who == .madam ? (rgb(0.87, 0.80, 0.93), rgb(0.47, 0.37, 0.56)) : (rgb(0.80, 0.81, 0.85), rgb(0.36, 0.37, 0.43)) }
/* 0.7: each roommate's colour is taken from their iris (hers violet, his slate), so rings, dots and symbols belong to the eyes */
func accent(_ who: Who?) -> CGColor { who == .gentleman ? rgb(0.56, 0.65, 0.73) : rgb(0.56, 0.5, 0.92) }
func sm(_ a: Double, _ b: Double, _ v: Double) -> Double { let k = max(0, min(1, (v - a)/(b - a))); return k*k*(3 - 2*k) }

// MARK: - drawing (y runs down)

func drawDrop(_ g: CGContext, at c: CGPoint, r: CGFloat, color: CGColor = rgb(0.33, 0.72, 0.98)) {
  g.saveGState(); g.translateBy(x: c.x, y: c.y)
  g.beginPath(); g.move(to: CGPoint(x: 0, y: -r*1.8))
  g.addCurve(to: CGPoint(x: r, y: r*0.15), control1: CGPoint(x: r*0.2, y: -r*0.9), control2: CGPoint(x: r, y: -r*0.3))
  g.addArc(center: CGPoint(x: 0, y: r*0.15), radius: r, startAngle: 0, endAngle: .pi, clockwise: false)
  g.addCurve(to: CGPoint(x: 0, y: -r*1.8), control1: CGPoint(x: -r, y: -r*0.3), control2: CGPoint(x: -r*0.2, y: -r*0.9))
  g.setFillColor(color); g.fillPath()
  g.restoreGState()
}
func drawHeart(_ g: CGContext, at c: CGPoint, r: CGFloat, color: CGColor = rgb(1, 0.27, 0.4)) {
  g.saveGState(); g.translateBy(x: c.x, y: c.y); g.beginPath(); g.move(to: CGPoint(x: 0, y: r*0.9))
  g.addCurve(to: CGPoint(x: -r, y: -r*0.25), control1: CGPoint(x: -r*0.55, y: r*0.55), control2: CGPoint(x: -r, y: r*0.2))
  g.addArc(center: CGPoint(x: -r*0.5, y: -r*0.3), radius: r*0.5, startAngle: .pi, endAngle: 0, clockwise: false)
  g.addArc(center: CGPoint(x: r*0.5, y: -r*0.3), radius: r*0.5, startAngle: .pi, endAngle: 0, clockwise: false)
  g.addCurve(to: CGPoint(x: 0, y: r*0.9), control1: CGPoint(x: r, y: r*0.2), control2: CGPoint(x: r*0.55, y: r*0.55))
  g.setFillColor(color); g.fillPath(); g.restoreGState()
}

/* ---- EYEBALLS (0.3, 2026-11-19) ----
   Not drawn eyes: a lit ball with a wet highlight that stays where the light is, an iris that lies on the
   ball and flattens toward its edge, fibres, a pupil that opens when you come near, and lids that are
   shells of the same ball. Character is in the lids and in how they move, not in accessories
   (the owner turned down lashes and a monocle). Ported from roomie/lab/eyeballs.html. */
func hex(_ s: String) -> CGColor { var v: UInt64 = 0; Scanner(string: String(s.dropFirst())).scanHexInt64(&v)
  return rgb(CGFloat((v >> 16) & 255)/255, CGFloat((v >> 8) & 255)/255, CGFloat(v & 255)/255) }
struct EyeStyle { var iris: [CGColor]; var irisR: CGFloat; var lid: [CGColor]; var edge: CGColor; var liner: CGFloat; var rest: CGFloat; var tilt: CGFloat; var lower: CGFloat }
/* 0.3.1: neutral, so they sit among the white menu-bar glyphs (the owner: the pink and purple looked foreign).
   The lids are the same glass-white as the ball; only the iris keeps a hint of colour, hers plum, his slate. */
/* 0.5: the whites and lids are pure neutral greys (the bluish ones went blue on his dimmed second screen),
   and the lids are dark shells, so the lid reads against the white ball at 16 pt. */
let STYLE_MADAM = EyeStyle(iris: ["#221a26", "#5e4b69", "#a693b2", "#e8def0"].map(hex), irisR: 0.52, lid: ["#78777b", "#454447", "#28282a"].map(hex),
                           edge: hex("#141415"), liner: 3.2, rest: 0.14, tilt: 0.22, lower: 0.08)
let STYLE_GENT = EyeStyle(iris: ["#161d23", "#465763", "#9aabb6", "#dfe8ee"].map(hex), irisR: 0.42, lid: ["#78777b", "#454447", "#28282a"].map(hex),
                          edge: hex("#141415"), liner: 1.8, rest: 0.44, tilt: -0.1, lower: 0.1)
let STYLE_NONE = EyeStyle(iris: ["#10203a", "#3b67b0", "#9cc0f0", "#e2efff"].map(hex), irisR: 0.46, lid: ["#eceef3", "#c0c5d1", "#8a90a0"].map(hex),
                          edge: hex("#3d4250"), liner: 2, rest: 0.06, tilt: 0, lower: 0.06)
func style(_ who: Who?) -> EyeStyle { who == .madam ? STYLE_MADAM : who == .gentleman ? STYLE_GENT : STYLE_NONE }

func radial(_ g: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from c0: CGPoint, _ r0: CGFloat, to c1: CGPoint, _ r1: CGFloat) {
  let gr = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locs)!
  g.drawRadialGradient(gr, startCenter: c0, startRadius: r0, endCenter: c1, endRadius: r1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
func linear(_ g: CGContext, _ colors: [CGColor], from p0: CGPoint, to p1: CGPoint) {
  let gr = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!
  g.drawLinearGradient(gr, start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }

func drawEye(_ g: CGContext, c: CGPoint, r R0: CGFloat, e: EyeLook, right: Bool, who: Who?, pill: Bool = false) {
  let st = style(who), s: CGFloat = right ? 1 : -1, R = R0*e.scale
  let close: CGFloat = (e.closed == .blink || e.closed == .sleep || e.closed == .wince) ? 1 : 0
  let wince: CGFloat = e.closed == .wince ? 1 : 0, joy = e.closed == .joy
  g.saveGState(); g.translateBy(x: c.x, y: c.y)
  if R > 30 { g.saveGState(); g.addEllipse(in: CGRect(x: -R*1.22, y: R*0.18 - R*1.22, width: R*2.44, height: R*2.44)); g.clip()
    radial(g, [rgb(0, 0, 0, 0.22), rgb(0, 0, 0, 0)], [0, 1], from: CGPoint(x: 0, y: R*0.18), R*0.9, to: CGPoint(x: 0, y: R*0.18), R*1.22); g.restoreGState() }
  g.scaleBy(x: 1 + 0.03*wince + 0, y: 1 - 0.05*close - 0.06*wince)
  let ball = CGRect(x: -R, y: -R, width: 2*R, height: 2*R)
  g.saveGState(); g.addEllipse(in: ball); g.clip()
  /* the white, lit from the top left */
  radial(g, ["#ffffff", "#f3f3f3", "#d6d6d6", "#b3b3b3"].map(hex), [0, 0.55, 0.88, 1], from: CGPoint(x: -R*0.32, y: -R*0.38), R*0.1, to: .zero, R*1.02)
  /* the iris, lying on the ball */
  if e.spiral < 0.99 {
    let ix = e.px*R, iy = e.py*R, off = min(0.999, hypot(ix, iy)/R), fore = max(0.25, sqrt(1 - off*off)), tilt = atan2(iy, ix), ri = R*st.irisR
    g.saveGState(); g.setAlpha(1 - e.spiral)
    g.translateBy(x: ix, y: iy); g.rotate(by: tilt); g.scaleBy(x: fore, y: 1); g.rotate(by: -tilt)
    let ir = CGRect(x: -ri, y: -ri, width: 2*ri, height: 2*ri)
    g.saveGState(); g.addEllipse(in: ir); g.clip()
    radial(g, [st.iris[2], st.iris[1], st.iris[0], st.iris[0]], [0, 0.55, 0.9, 1], from: .zero, ri*0.2, to: .zero, ri)
    if R > 14 { g.setLineCap(.round); g.setLineWidth(max(0.6, ri*0.018))
      for k in 0..<64 { let an = CGFloat(k)/64 * .pi*2 + CGFloat(k % 3)*0.03, r0 = ri*(0.34 + CGFloat(k % 4)*0.03), r1 = ri*(0.78 + CGFloat(k % 5)*0.03)
        g.setStrokeColor(k % 2 == 1 ? rgb(1, 1, 1, 0.16) : rgb(0, 0, 0, 0.14))
        g.beginPath(); g.move(to: CGPoint(x: cos(an)*r0, y: sin(an)*r0)); g.addLine(to: CGPoint(x: cos(an)*r1, y: sin(an)*r1)); g.strokePath() } }
    g.setAlpha((1 - e.spiral)*0.75)
    radial(g, [st.iris[3], st.iris[3].copy(alpha: 0)!], [0, 1], from: CGPoint(x: ri*0.35, y: ri*0.45), 0, to: CGPoint(x: ri*0.35, y: ri*0.45), ri*0.75)
    g.setAlpha(1 - e.spiral)
    let pr = ri*e.pupil; g.setFillColor(rgb(0.03, 0.03, 0.05)); g.fillEllipse(in: CGRect(x: -pr, y: -pr, width: 2*pr, height: 2*pr))
    g.restoreGState()
    g.setStrokeColor(rgb(0, 0, 0, 0.35)); g.setLineWidth(max(0.6, ri*0.05)); g.strokeEllipse(in: ir.insetBy(dx: ri*0.015, dy: ri*0.015))
    g.restoreGState()
  }
  if e.spiral > 0.01 {
    g.saveGState(); g.setAlpha(e.spiral); g.setStrokeColor(INK); g.setLineWidth(max(1.1, R*0.12)); g.setLineCap(.round); g.beginPath()
    for k in 0...48 { let q = CGFloat(k)/48, a = e.spin + q * .pi*4.4, rr = R*0.7*q
      let p = CGPoint(x: cos(a)*rr, y: sin(a)*rr); if k == 0 { g.move(to: p) } else { g.addLine(to: p) } }
    g.strokePath(); g.restoreGState() }
  /* lids: shells of the ball. The upper one follows the gaze down a little; sorrow lifts their inner corners */
  let sorrow = min(1, abs(e.ang)/0.42)
  var up = min(1, st.rest + e.up*(1 - st.rest) + max(0, e.py)*0.22 - max(0, -e.py)*0.1)
  var low = st.lower + max(0, -e.py)*0.2 + 0.3*wince + e.low
  if joy { up = st.rest*0.5; low = 0.84 }            /* glad: the lower lids push up into crescents */
  if close > 0 { up = 1 }
  let yU = -R + up*2*R*0.98, lean = s*(st.tilt - sorrow*0.3)*R, bow = R*0.32*(1 - up*0.6), yL = R - low*R
  let lidFill = { radial(g, st.lid, [0, 0.7, 1], from: CGPoint(x: -R*0.32, y: -R*0.42), R*0.05, to: .zero, R*1.02) }
  g.saveGState(); g.clip(to: CGRect(x: -R, y: yU - R*0.1, width: 2*R, height: R*0.6))
  linear(g, [rgb(0, 0, 0, 0.4), rgb(0, 0, 0, 0)], from: CGPoint(x: 0, y: yU), to: CGPoint(x: 0, y: yU + R*0.45)); g.restoreGState()
  /* the wet highlight, kept inside the open part of the eye */
  if close < 0.6 && !joy && !pill {
    g.saveGState(); g.addEllipse(in: ball.insetBy(dx: R*0.03, dy: R*0.03)); g.clip()
    g.clip(to: CGRect(x: -R, y: yU + bow*0.4 + R*0.06, width: 2*R, height: max(0, yL - (yU + bow*0.4) - R*0.12)))
    let hy = max(-R*0.32, yU + bow*0.5 + R*0.16)
    g.translateBy(x: -R*0.3, y: hy); g.rotate(by: -0.45); g.setFillColor(rgb(1, 1, 1, 0.95)); if pill { g.scaleBy(x: 0.55, y: 0.55) }
    g.fillEllipse(in: CGRect(x: -R*0.17, y: -R*0.1, width: R*0.34, height: R*0.2))
    g.fillEllipse(in: CGRect(x: R*0.17 - R*0.045, y: R*0.1 - R*0.035, width: R*0.09, height: R*0.07))
    g.restoreGState() }
  let upper = CGMutablePath(); upper.move(to: CGPoint(x: -R*1.1, y: -R*1.2)); upper.addLine(to: CGPoint(x: R*1.1, y: -R*1.2))
  upper.addLine(to: CGPoint(x: R*1.1, y: yU - lean)); upper.addQuadCurve(to: CGPoint(x: -R*1.1, y: yU + lean), control: CGPoint(x: 0, y: yU + bow)); upper.closeSubpath()
  g.saveGState(); g.addPath(upper); g.clip(); lidFill()
  if true { g.setStrokeColor(rgb(1, 1, 1, R > 14 ? 0.5 : 0.35)); g.setLineWidth(max(0.5, R*0.025)); g.beginPath(); g.move(to: CGPoint(x: R*1.1, y: yU - lean - R*0.05))
    g.addQuadCurve(to: CGPoint(x: -R*1.1, y: yU + lean - R*0.05), control: CGPoint(x: 0, y: yU + bow - R*0.05)); g.strokePath() }
  g.restoreGState()
  /* the lid's edge, thicker toward the outer corner */
  g.setStrokeColor(st.edge); g.setLineCap(.round)
  func q(_ t: CGFloat) -> CGPoint { let x0 = -R*1.1, x1 = R*1.1, y0 = yU + lean, y1 = yU - lean, cy = yU + bow
    return CGPoint(x: (1 - t)*(1 - t)*x0 + 2*(1 - t)*t*0 + t*t*x1, y: (1 - t)*(1 - t)*y0 + 2*(1 - t)*t*cy + t*t*y1) }
  for k in 0..<6 { let t0 = CGFloat(k)/6, t1 = CGFloat(k + 1)/6, outer = right ? (t0 + t1)/2 : 1 - (t0 + t1)/2
    let small: CGFloat = R < 20 ? (who == .madam ? R*0.2*(0.35 + outer*1.1) : R*0.13) : 0
    g.setLineWidth(max(0.8, R*0.018*st.liner*(0.55 + outer*0.9), small)); g.beginPath(); g.move(to: q(t0)); g.addLine(to: q(t1)); g.strokePath() }
  if low > 0.02 {
    let rise = joy ? R*0.75 : R*(0.18 - 0.3*e.low)
    let lower = CGMutablePath(); lower.move(to: CGPoint(x: -R*1.1, y: R*1.2)); lower.addLine(to: CGPoint(x: R*1.1, y: R*1.2)); lower.addLine(to: CGPoint(x: R*1.1, y: yL))
    lower.addQuadCurve(to: CGPoint(x: -R*1.1, y: yL), control: CGPoint(x: 0, y: yL - rise)); lower.closeSubpath()
    g.saveGState(); g.addPath(lower); g.clip()
    radial(g, ["#ededee", "#d2d2d4", "#ababae"].map(hex), [0, 0.7, 1], from: CGPoint(x: -R*0.32, y: -R*0.42), R*0.05, to: .zero, R*1.02); g.restoreGState()
    g.setStrokeColor(joy ? st.edge : rgb(0, 0, 0, pill ? 0.55 : 0.18)); g.setLineWidth(max(0.6, R*(joy ? 0.05 : pill ? 0.035 : 0.02)))
    g.beginPath(); g.move(to: CGPoint(x: R*1.1, y: yL)); g.addQuadCurve(to: CGPoint(x: -R*1.1, y: yL), control: CGPoint(x: 0, y: yL - rise)); g.strokePath() }
  g.restoreGState()
  /* the rim of the ball */
  let lw = max(0.7, R*0.03); g.setStrokeColor(rgb(0, 0, 0, 0.32)); g.setLineWidth(lw); g.strokeEllipse(in: ball.insetBy(dx: lw/2, dy: lw/2))
  /* her flick: the liner runs on past the outer corner and up. A faint light rim keeps it visible on a dark bar */
  if who == .madam && !joy {
    let cy = close > 0 ? R*0.1 : max(-R*0.75, yU - lean*0.95), b = CGPoint(x: s*R*0.9, y: cy + (close > 0 ? 0 : R*0.04))
    let p = CGMutablePath(); p.move(to: CGPoint(x: b.x - s*R*0.1, y: b.y - R*0.16))
    /* in the pill (pill) the flick runs out nearly level, like the bar's: pointing up it read as horns */
    let tip = pill ? CGPoint(x: s*R*1.32, y: b.y - R*0.2) : CGPoint(x: s*R*1.5, y: b.y - R*0.62)
    p.addQuadCurve(to: tip, control: CGPoint(x: s*R*1.18, y: b.y - (pill ? R*0.08 : R*0.18)))
    p.addQuadCurve(to: CGPoint(x: b.x, y: b.y + R*0.16), control: CGPoint(x: s*R*1.2, y: b.y + (pill ? R*0.06 : -R*0.04))); p.closeSubpath()
    if !pill { g.addPath(p); g.setStrokeColor(rgb(1, 1, 1, 0.45)); g.setLineWidth(max(0.5, R*0.05)); g.setLineJoin(.round); g.strokePath() }
    g.addPath(p); g.setFillColor(pill ? hex("#5c5b5f") : st.edge); g.fillPath() }
  g.restoreGState()
}

/* two eyeballs in the box: the app icon */
func drawBallFace(_ g: CGContext, in box: CGRect, look: FaceLook, who: Who?, pill: Bool = false) {
  let r = min(box.height/2 - 0.5, box.width/4.44), cy = box.midY + look.hop
  let gap = r*0.22, cl = CGPoint(x: box.midX - r - gap/2, y: cy), cr = CGPoint(x: box.midX + r + gap/2, y: cy)
  drawEye(g, c: cl, r: r, e: look.l, right: false, who: who, pill: pill); drawEye(g, c: cr, r: r, e: look.r, right: true, who: who, pill: pill)
  if let t = look.tear { drawDrop(g, at: CGPoint(x: cl.x - r*0.2, y: cl.y + r*(0.75 + 0.5*t)), r: r*0.2) }
  if let s = look.sweat { drawDrop(g, at: CGPoint(x: cr.x + r*1.02, y: cr.y - r*0.35 + r*0.6*s), r: r*0.2) }
}


/* ---- THE GLYPH (0.4, 2026-11-19) ----
   In the menu bar they are drawn like the system's own icons: one colour, which macOS paints white on a dark
   bar, black on a light one and dims on a screen that is not in focus (a template image). The owner: the
   coloured eyeballs looked foreign, too big, and on the second screen turned blue. Who is who is in the
   silhouette: SHE has a cat-eye flick at each outer corner and a sparkle in her pupils; HE has heavy,
   flat lids. In the black island the same glyph is drawn in white. */
/* 0.6 (2026-11-19): the system-icon glyph again, with volume. A template image keeps its alpha, so the eye
   is drawn in layers of one ink, the way macOS draws its hierarchical symbols: the ball is clear glass,
   denser toward its rim; the rim is heavier underneath; the pupil sits in a softer iris, both foreshortened
   on the ball when the eye looks aside, with a glint; the lid is a half-tone shell with a solid edge that
   casts a shadow on the ball. Who is who stays in the silhouette: SHE has open lids, a liner that thickens
   outward and flicks up, a big iris and a big glint; HE has heavy flat lids and a smaller iris. */
/* a heart w wide either side of its middle, y down */
func heartPath(_ w: CGFloat) -> CGPath {
  let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: w*0.85))
  p.addCurve(to: CGPoint(x: -w, y: -w*0.2), control1: CGPoint(x: -w*0.6, y: w*0.45), control2: CGPoint(x: -w, y: w*0.2))
  p.addCurve(to: CGPoint(x: 0, y: -w*0.45), control1: CGPoint(x: -w, y: -w*0.8), control2: CGPoint(x: -w*0.2, y: -w*0.85))
  p.addCurve(to: CGPoint(x: w, y: -w*0.2), control1: CGPoint(x: w*0.2, y: -w*0.85), control2: CGPoint(x: w, y: -w*0.8))
  p.addCurve(to: CGPoint(x: 0, y: w*0.85), control1: CGPoint(x: w, y: w*0.2), control2: CGPoint(x: w*0.6, y: w*0.45))
  p.closeSubpath(); return p }

/* .tone is a map of how dark each part is (glass, iris, pupil, lid, edge, rim); .line is what is always ink
   (her flick, the joy and wince strokes). On a light bar the map is drawn as is; on a dark bar drawFace
   turns it over inside the eye, so the white is light and the pupil dark there too. */
enum GlyphPass { case tone, line }
func drawGlyphEye(_ g: CGContext, c: CGPoint, r R: CGFloat, e: EyeLook, right: Bool, who: Who?, ink inkC: CGColor, pass: GlyphPass, dark: Bool = false, deep: Bool = false) {
  let tone = pass == .tone
  let s: CGFloat = right ? 1 : -1, madam = who == .madam, gent = who == .gentleman
  func ink(_ a: CGFloat) -> CGColor { inkC.copy(alpha: inkC.alpha*a)! }
  let lw = max(1.05, R*0.14), inner = R - lw*0.9
  g.saveGState(); g.translateBy(x: c.x, y: c.y)
  g.setStrokeColor(ink(1)); g.setFillColor(ink(1)); g.setLineCap(.round); g.setLineJoin(.round)
  /* the rim: a ring that is heavier underneath, like a ball standing in light from above */
  func rim() {
    let p = CGMutablePath(); p.addEllipse(in: CGRect(x: -R, y: -R, width: 2*R, height: 2*R))
    let t = lw*0.3; p.addEllipse(in: CGRect(x: -R + lw*0.8, y: -R + lw*0.8 - t, width: 2*(R - lw*0.8), height: 2*(R - lw*0.8)))
    g.setFillColor(ink(1)); g.addPath(p); g.fillPath(using: .evenOdd) }
  func glass() {
    g.saveGState(); g.addEllipse(in: CGRect(x: -inner, y: -inner, width: 2*inner, height: 2*inner)); g.clip()
    radial(g, dark ? [ink(0), ink(0.01), ink(0.07)] : [ink(0.06), ink(0.13), ink(0.28)], [0, 0.5, 1], from: CGPoint(x: -R*0.35, y: -R*0.45), 0, to: CGPoint(x: -R*0.35, y: -R*0.45), R*1.9)
    g.restoreGState() }
  /* her liner runs on past the outer corner and up */
  func wing(_ b: CGPoint) { guard madam, !tone else { return }
    /* a liner flick that carries the lid line out past the corner, nearly level: not tufts (she read as an owl) */
    let p = CGMutablePath(); p.move(to: CGPoint(x: b.x - s*R*0.14, y: b.y - R*0.1))
    p.addQuadCurve(to: CGPoint(x: s*R*1.34, y: b.y - R*0.26), control: CGPoint(x: s*R*1.14, y: b.y - R*0.08))
    p.addQuadCurve(to: CGPoint(x: b.x - s*R*0.02, y: b.y + R*0.12), control: CGPoint(x: s*R*1.12, y: b.y + R*0.04)); p.closeSubpath()
    g.setFillColor(ink(1)); g.addPath(p); g.fillPath() }
  if let cl = e.closed {
    if cl == .blink || cl == .sleep {
      /* the lid is down: the whole ball is the half-tone lid, with the lash line low on it */
      let y0: CGFloat = gent ? R*0.2 : R*0.12
      if tone { glass(); g.setFillColor(ink(deep ? 0.7 : dark ? 0.2 : 0.5)); g.fillEllipse(in: CGRect(x: -inner, y: -inner, width: 2*inner, height: 2*inner)); rim()
        g.setStrokeColor(ink(1)); g.setLineWidth(lw*(madam ? 1.25 : 1.05)); g.beginPath()
        g.move(to: CGPoint(x: -R*0.92, y: y0 - R*0.1)); g.addQuadCurve(to: CGPoint(x: R*0.92, y: y0 - R*0.1), control: CGPoint(x: 0, y: y0 + R*0.42)); g.strokePath() }
      wing(CGPoint(x: s*R*0.88, y: y0 - R*0.08))
    } else if !tone {
      g.setLineWidth(lw*1.15); g.beginPath()
      if cl == .wince { g.move(to: CGPoint(x: -s*R*0.55, y: -R*0.5)); g.addLine(to: CGPoint(x: s*R*0.45, y: 0)); g.addLine(to: CGPoint(x: -s*R*0.55, y: R*0.5)) }
      /* crying: shut tight, the inner end lifted in sorrow */
      else if cl == .cry { g.setLineWidth(lw*1.35); g.move(to: CGPoint(x: s*R*0.82, y: R*0.34)); g.addQuadCurve(to: CGPoint(x: -s*R*0.82, y: R*0.2), control: CGPoint(x: 0, y: -R*0.22)) }
      else { g.move(to: CGPoint(x: -R*0.8, y: R*0.32)); g.addQuadCurve(to: CGPoint(x: R*0.8, y: R*0.32), control: CGPoint(x: 0, y: -R*0.78)) }
      g.strokePath()
    }
    g.restoreGState(); return
  }
  if !tone { /* only her flick is line here */ }
  else { glass()
  let rest: CGFloat = madam ? 0.17 : gent ? 0.36 : 0.06
  let sorrow = min(1, abs(e.ang)/0.42)
  let up = max(0, min(0.94, rest + e.up*(1 - rest) + max(0, e.py)*(gent ? 0.05 : 0.18) - max(0, -e.py)*0.08))
  let yU = -inner + up*2*inner, lean = s*((madam ? 0.16 : gent ? 0.08 : 0) - sorrow*0.35)*R, bow = madam ? R*0.34*(1 - up) : R*0.15
  g.saveGState(); g.addEllipse(in: CGRect(x: -inner, y: -inner, width: 2*inner, height: 2*inner)); g.clip()
  if e.spiral > 0.5 || e.heart > 0.02 {
    /* drawn in colour on top, by drawFace */
  } else {
    /* the iris lies on the ball: aside, it turns into an ellipse */
    let pr = R*(madam ? 0.33 : 0.29)*min(1.25, max(0.7, e.pupil/0.4)), ir = R*(madam ? 0.56 : 0.5)
    let lim = max(0, inner - ir*0.75), k = lim/0.68, pc = CGPoint(x: e.px*k, y: e.py*k)
    let off = min(0.95, hypot(pc.x, pc.y)/inner), fore = max(0.6, sqrt(1 - off*off)), tilt = atan2(pc.y, pc.x)
    g.saveGState(); g.translateBy(x: pc.x, y: pc.y); g.rotate(by: tilt); g.scaleBy(x: fore, y: 1); g.rotate(by: -tilt)
    g.setBlendMode(.copy); g.setFillColor(ink(dark ? 0.5 : 0.55)); g.fillEllipse(in: CGRect(x: -ir, y: -ir, width: 2*ir, height: 2*ir)); g.setBlendMode(.normal)
    g.setFillColor(ink(1)); g.fillEllipse(in: CGRect(x: -pr, y: -pr, width: 2*pr, height: 2*pr))
    g.restoreGState()
  }
  if up > 0.03 {
    let lid = CGMutablePath(); lid.move(to: CGPoint(x: -R*1.2, y: -R*1.3)); lid.addLine(to: CGPoint(x: R*1.2, y: -R*1.3))
    lid.addLine(to: CGPoint(x: R*1.2, y: yU - lean)); lid.addQuadCurve(to: CGPoint(x: -R*1.2, y: yU + lean), control: CGPoint(x: 0, y: yU + bow)); lid.closeSubpath()
    let edge = CGMutablePath(); edge.move(to: CGPoint(x: R*1.2, y: yU - lean)); edge.addQuadCurve(to: CGPoint(x: -R*1.2, y: yU + lean), control: CGPoint(x: 0, y: yU + bow))
    /* the lid's shadow on the ball, just under its edge */
    g.saveGState(); g.addPath(edge); g.addLine(to: CGPoint(x: -R*1.2, y: R*1.3)); g.addLine(to: CGPoint(x: R*1.2, y: R*1.3)); g.closePath(); g.clip()
    linear(g, [ink(dark ? 0.18 : 0.4), ink(0)], from: CGPoint(x: 0, y: yU + bow*0.5), to: CGPoint(x: 0, y: yU + bow*0.5 + R*0.42))
    g.restoreGState()
    /* the lid: a half-tone shell, a touch denser toward its edge */
    g.saveGState(); g.addPath(lid); g.clip(); g.setBlendMode(.copy)
    linear(g, deep ? [ink(0.66), ink(0.74)] : dark ? [ink(0.08), ink(0.22)] : [ink(0.34), ink(0.62)], from: CGPoint(x: 0, y: -inner), to: CGPoint(x: 0, y: yU + bow*0.5)); g.restoreGState()
    /* its edge, solid, heavier toward the outer corner for her */
    func q(_ t: CGFloat) -> CGPoint { let x0 = -R*1.2, x1 = R*1.2, y0 = yU + lean, y1 = yU - lean, cy = yU + bow
      return CGPoint(x: x0 + (x1 - x0)*t, y: (1 - t)*(1 - t)*y0 + 2*(1 - t)*t*cy + t*t*y1) }
    g.setStrokeColor(ink(1))
    for k in 0..<8 { let t0 = CGFloat(k)/8, t1 = CGFloat(k + 1)/8, outer = right ? (t0 + t1)/2 : 1 - (t0 + t1)/2
      g.setLineWidth(lw*(madam ? 0.75 + outer*0.9 : 1.05)); g.beginPath(); g.move(to: q(t0)); g.addLine(to: q(t1)); g.strokePath() }
  }
  /* a squint: the lower lid comes up, its edge rising a little in the middle, so the eye's opening becomes an almond */
  if e.low > 0.02 {
    let yL = inner - min(0.6, e.low)*2*inner, rise = R*0.16
    let lower = CGMutablePath(); lower.move(to: CGPoint(x: -R*1.2, y: R*1.3)); lower.addLine(to: CGPoint(x: R*1.2, y: R*1.3))
    lower.addLine(to: CGPoint(x: R*1.2, y: yL)); lower.addQuadCurve(to: CGPoint(x: -R*1.2, y: yL), control: CGPoint(x: 0, y: yL - rise)); lower.closeSubpath()
    g.saveGState(); g.addPath(lower); g.clip(); g.setBlendMode(.copy)
    linear(g, deep ? [ink(0.74), ink(0.66)] : dark ? [ink(0.2), ink(0.08)] : [ink(0.55), ink(0.34)], from: CGPoint(x: 0, y: yL), to: CGPoint(x: 0, y: inner)); g.restoreGState()
    g.setStrokeColor(ink(1)); g.setLineWidth(lw*0.9); g.beginPath(); g.move(to: CGPoint(x: R*1.2, y: yL))
    g.addQuadCurve(to: CGPoint(x: -R*1.2, y: yL), control: CGPoint(x: 0, y: yL - rise)); g.strokePath() }
  g.restoreGState()
  rim() }
  let rest2: CGFloat = madam ? 0.17 : gent ? 0.36 : 0.06, sorrow2 = min(1, abs(e.ang)/0.42)
  let up2 = max(0, min(0.94, rest2 + e.up*(1 - rest2) + max(0, e.py)*(gent ? 0.05 : 0.18) - max(0, -e.py)*0.08))
  let yU2 = -inner + up2*2*inner, lean2 = s*((madam ? 0.16 : gent ? 0.08 : 0) - sorrow2*0.35)*R
  wing(CGPoint(x: s*inner*0.93, y: up2 > 0.03 ? max(-inner*0.6, yU2 - lean2*0.9) : -inner*0.35))
  /* her lashes: two short strokes off the rim's outer top, leaning out */
  if madam && !tone && e.spiral < 0.5 {
    /* they grow out of the rim's upper outer arc, radiating, above the flick */
    for (k, deg) in [CGFloat(48)].enumerated() {
      let al = deg * .pi/180, base = CGPoint(x: s*R*0.9*cos(al), y: -R*0.9*sin(al)), len = R*(k == 0 ? 0.3 : 0.3)
      let d = CGPoint(x: s*cos(al - 0.12), y: -sin(al - 0.12)), w = R*0.1
      let lash = CGMutablePath(); lash.move(to: CGPoint(x: base.x - d.y*w, y: base.y + d.x*w))
      lash.addQuadCurve(to: CGPoint(x: base.x + d.x*len, y: base.y + d.y*len), control: CGPoint(x: base.x + d.x*len*0.5 - d.y*w*0.6 + s*R*0.04, y: base.y + d.y*len*0.5))
      lash.addLine(to: CGPoint(x: base.x + d.y*w, y: base.y - d.x*w)); lash.closeSubpath()
      g.setFillColor(ink(1)); g.addPath(lash); g.fillPath() } }
  g.restoreGState()
}

/* ---- 0.7 (2026-11-19): THE CARTOON EYES ("v2", from roomie/lab/eyes-v2.html) ----
   After the glyph and the eyeballs, he brought Pinterest sheets of cartoon eyes and we settled on this in the lab:
   no outline; a soft white ball lit from the top left; a glossy iris, dark above and lighter toward its lower rim,
   with two crisp white spots that stay where the light is while the iris moves; lids of the ball's own colour that
   cast a soft shadow. Madam: a big violet iris, a liner on her lid's edge thickening outward, three curled lashes.
   The Gentleman: a smaller slate iris, a heavy lid with a firm dark crease. Glad is a tapered crescent. On a light
   bar the ball gets a faint rim. Not a template image: it is drawn in its own colours everywhere. */
let USE_V2 = true
struct V2Style { let rest: CGFloat, iris: CGFloat, irisC: [CGColor], spot: CGFloat, gap: CGFloat, lashes: Bool }
let V2_MADAM = V2Style(rest: 0.04, iris: 0.7, irisC: ["#140f20", "#2b2150", "#6e5ecf", "#b1a6f5"].map(hex), spot: 0.25, gap: 0.2, lashes: true)
let V2_GENT = V2Style(rest: 0.33, iris: 0.5, irisC: ["#0b0d11", "#1c252d", "#435565", "#7d90a2"].map(hex), spot: 0.18, gap: 0.16, lashes: false)
func linearL(_ g: CGContext, _ colors: [CGColor], _ locs: [CGFloat], from p0: CGPoint, to p1: CGPoint) {
  let gr = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locs)!
  g.drawLinearGradient(gr, start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
func v2LidY(_ R: CGFloat, _ top: CGFloat, _ tilt: CGFloat, _ x: CGFloat, _ right: Bool) -> CGFloat {
  let s: CGFloat = right ? 1 : -1
  return -R*1.02 + top*2.04*R + tilt*R*(-x*s/R) - (1 - min(1, (x/R)*(x/R)))*R*0.1*min(1, max(0, top)*4) }
/* a lash: thick where it grows from the rim, curling out and up to a fine tip */
func v2Lash(_ g: CGContext, _ R: CGFloat, _ ang: CGFloat, _ len: CGFloat, _ w: CGFloat, _ s: CGFloat) {
  let bx = s*sin(ang)*R, by = -cos(ang)*R, nx = s*sin(ang), ny = -cos(ang), px = -ny, py = nx, turn = -s*0.8
  let tx = bx + (nx*cos(turn) - ny*sin(turn))*len, ty = by + (nx*sin(turn) + ny*cos(turn))*len
  let cx = bx + nx*len*0.62, cy = by + ny*len*0.62, p = CGMutablePath()
  p.move(to: CGPoint(x: bx + px*w, y: by + py*w)); p.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: cx + px*w*0.5, y: cy + py*w*0.5))
  p.addQuadCurve(to: CGPoint(x: bx - px*w, y: by - py*w), control: CGPoint(x: cx - px*w*0.2, y: cy - py*w*0.2)); p.closeSubpath()
  g.addPath(p); g.fillPath() }
func v2Eye(_ g: CGContext, R: CGFloat, e: EyeLook, right: Bool, who: Who?, light: Bool, wet: Bool) {
  let st = who == .gentleman ? V2_GENT : V2_MADAM, madam = who != .gentleman, s: CGFloat = right ? 1 : -1, tiny = R < 12
  let lashC = light ? hex("#1b1724") : hex("#ece8f6")
  if e.closed == .joy {
    /* glad: a crescent, the eye squeezed shut from below, thick in the middle and tapering to fine ends */
    g.saveGState()
    let cut = CGMutablePath(); cut.addRect(CGRect(x: -R*2, y: -R*2, width: R*4, height: R*4)); cut.addEllipse(in: CGRect(x: -R*0.84, y: R*0.8 - R*0.84, width: R*1.68, height: R*1.68))
    g.addPath(cut); g.clip(using: .evenOdd)
    g.addEllipse(in: CGRect(x: -R*0.78, y: R*0.42 - R*0.78, width: R*1.56, height: R*1.56)); g.clip()
    linearL(g, light ? [hex("#3a3346"), hex("#1d1924")] : [hex("#ffffff"), hex("#d9d7e1")], [0, 1], from: CGPoint(x: 0, y: -R*0.35), to: CGPoint(x: 0, y: R*0.1))
    g.restoreGState()
    if st.lashes { g.saveGState(); g.translateBy(x: 0, y: R*0.42); g.setFillColor(lashC)
      for (i, a) in [CGFloat(1.0), 1.24].enumerated() { v2Lash(g, R*0.74, a, R*(0.3 - CGFloat(i)*0.06), R*0.07, s) }; g.restoreGState() }
    return }
  let shut = e.closed != nil
  let top: CGFloat = shut ? 0.9 : max(-0.1, min(1.02, st.rest + e.up*(1 - st.rest) + max(0, e.py)*0.1))
  let tilt = (right ? -e.ang : e.ang)*0.57, bot = e.low, pup = max(0.7, min(1.25, e.pupil/0.42))
  let gx = max(-1, min(1, e.px/0.68)), gy = max(-1, min(1, e.py/0.68))
  let ball = CGRect(x: -R, y: -R, width: 2*R, height: 2*R)
  if light { g.saveGState(); g.setShadow(offset: .zero, blur: R*0.5, color: rgb(0.12, 0.1, 0.2, 0.28)); g.setFillColor(rgb(1, 1, 1)); g.fillEllipse(in: ball); g.restoreGState() }
  g.saveGState(); g.addEllipse(in: ball); g.clip()
  radial(g, ["#ffffff", "#f3f2ef", "#d3d1dc"].map(hex), [0, 0.62, 1], from: CGPoint(x: -R*0.3, y: -R*0.38), R*0.05, to: .zero, R*1.05)
  let ix = gx*R*0.34, iy = gy*R*0.3, ri = R*st.iris*pup
  if e.spiral > 0.5 {
    g.setStrokeColor(st.irisC[1]); g.setLineWidth(R*0.13); g.setLineCap(.round); g.beginPath()
    for k in 0...60 { let q = CGFloat(k)/60, a = e.spin + q * .pi*5, rr = R*0.76*q, pt = CGPoint(x: cos(a)*rr, y: sin(a)*rr); if k == 0 { g.move(to: pt) } else { g.addLine(to: pt) } }
    g.strokePath()
  } else if e.heart <= 0.02 {
    /* the iris: dark above, glowing lighter toward its lower rim, like glass with light coming through */
    g.saveGState(); g.addEllipse(in: CGRect(x: ix - ri, y: iy - ri, width: 2*ri, height: 2*ri)); g.clip()
    linearL(g, st.irisC, [0, 0.5, 0.84, 1], from: CGPoint(x: 0, y: iy - ri), to: CGPoint(x: 0, y: iy + ri))
    g.setFillColor(rgb(0.016, 0.012, 0.03, 0.75)); let pr = ri*0.46; g.fillEllipse(in: CGRect(x: ix - pr, y: iy - ri*0.06 - pr, width: 2*pr, height: 2*pr))
    g.setFillColor(rgb(1, 1, 1))
    if !tiny {
      let sb = R*st.spot*(wet ? 1.25 : 1)
      g.saveGState(); g.translateBy(x: -R*0.24 + ix*0.3, y: -R*0.27 + iy*0.3); g.rotate(by: -0.5); g.fillEllipse(in: CGRect(x: -sb, y: -sb*0.8, width: 2*sb, height: 1.6*sb)); g.restoreGState()
      let sr = sb*0.36; g.fillEllipse(in: CGRect(x: R*0.2 + ix*0.3 - sr, y: R*0.2 + iy*0.3 - sr, width: 2*sr, height: 2*sr))
    }
    g.restoreGState()
    if tiny { g.setFillColor(rgb(1, 1, 1)); let sr = R*0.2; g.fillEllipse(in: CGRect(x: -R*0.22 + ix*0.3 - sr, y: -R*0.25 + iy*0.3 - sr, width: 2*sr, height: 2*sr)) }
  }
  /* lids: the ball's own colour, a touch deeper, with a soft shadow on the ball under their edge */
  let N = 28, xs = (0...N).map { -R*1.05 + 2.1*R*CGFloat($0)/CGFloat(N) }
  func Y(_ x: CGFloat) -> CGFloat { v2LidY(R, top, tilt, x, right) }
  let small = R < 10
  if top > -0.05 {
    if !small {
    let sh = CGMutablePath(); sh.move(to: CGPoint(x: -R*1.1, y: Y(-R*1.05))); for x in xs { sh.addLine(to: CGPoint(x: x, y: Y(x) + R*0.22)) }
    sh.addLine(to: CGPoint(x: R*1.1, y: -R*1.2)); sh.addLine(to: CGPoint(x: -R*1.1, y: -R*1.2)); sh.closeSubpath()
    g.addPath(sh); g.setFillColor(rgb(0.19, 0.14, 0.33, 0.16)); g.fillPath() }
    let up = CGMutablePath(); up.move(to: CGPoint(x: -R*1.1, y: -R*1.2)); for x in xs { up.addLine(to: CGPoint(x: x, y: Y(x))) }
    up.addLine(to: CGPoint(x: R*1.1, y: -R*1.2)); up.closeSubpath()
    g.saveGState(); g.addPath(up); g.clip()
    linearL(g, madam ? [hex("#fbfaf8"), hex("#e3dfeb")] : (small ? [hex("#f1f0f3"), hex("#dcdae2")] : [hex("#e4e3e9"), hex("#c8c6d1")]), [0, 1], from: CGPoint(x: 0, y: -R), to: CGPoint(x: 0, y: max(-R + 1, Y(0))))
    g.restoreGState()
    /* her liner thickens toward the outer corner; his lid has a firm crease, a touch heavier in the middle */
    let edge = CGMutablePath()
    let k: CGFloat = small ? 0.7 : 1
    func wv(_ x: CGFloat) -> CGFloat { if madam { let t = (x*s/R + 1.05)/2.1; return k*(R*0.035 + R*0.105*t*t) }; return k*R*(0.035 + 0.035*(1 - (x/R)*(x/R))) }
    let a: CGFloat = madam ? 0.3 : 0.4
    for (i, x) in xs.enumerated() { let pt = CGPoint(x: x, y: Y(x) - wv(x)*a); if i == 0 { edge.move(to: pt) } else { edge.addLine(to: pt) } }
    for x in xs.reversed() { edge.addLine(to: CGPoint(x: x, y: Y(x) + wv(x)*(1 - a))) }
    edge.closeSubpath(); g.addPath(edge); g.setFillColor(madam ? hex("#1b1724") : hex("#2b2f37")); g.fillPath()
  }
  if bot > 0.02 {
    let yB = R*1.02 - bot*2*R
    func YB(_ x: CGFloat) -> CGFloat { yB - (1 - (x/R)*(x/R))*R*0.18 }
    let lo = CGMutablePath(); lo.move(to: CGPoint(x: -R*1.1, y: R*1.2)); for x in xs { lo.addLine(to: CGPoint(x: x, y: YB(x))) }
    lo.addLine(to: CGPoint(x: R*1.1, y: R*1.2)); lo.closeSubpath(); g.addPath(lo); g.setFillColor(madam ? hex("#e6e2ec") : hex("#dcdae2")); g.fillPath()
    g.setStrokeColor(madam ? rgb(0.106, 0.09, 0.14, 0.55) : hex("#2b2f37")); g.setLineWidth(R*0.045); g.beginPath()
    for (i, x) in xs.enumerated() { let pt = CGPoint(x: x, y: YB(x)); if i == 0 { g.move(to: pt) } else { g.addLine(to: pt) } }; g.strokePath()
  }
  g.restoreGState()
  if light { g.setStrokeColor(rgb(0.15, 0.12, 0.24, 0.42)); g.setLineWidth(max(1, R*0.1)); g.strokeEllipse(in: ball) }
  /* her lashes leave the rim where the lid meets it, curling out and up */
  if st.lashes {
    let yL = max(-R*0.999, min(R*0.999, Y(s*R*0.9))), lidAng = acos(-yL/R)
    g.setFillColor(lashC)
    for (i, a) in [CGFloat(0.78), 1.05, 1.32].enumerated() { v2Lash(g, R*0.98, max(a, lidAng + 0.1 + CGFloat(i)*0.27), R*(0.4 - CGFloat(i)*0.06), R*0.075, s) }
  }
  /* in love the iris is a heart, and it may grow past the eye */
  if e.heart > 0.02 && !shut {
    let hw = R*0.74*e.heart; g.saveGState(); g.translateBy(x: ix*0.3, y: iy*0.3 + R*0.05)
    g.addPath(heartPath(hw)); g.clip(); linearL(g, [hex("#e59392"), hex("#c45a59")], [0, 1], from: CGPoint(x: 0, y: -hw), to: CGPoint(x: 0, y: hw))
    g.setFillColor(rgb(1, 1, 1)); g.translateBy(x: -hw*0.45, y: -hw*0.32); g.rotate(by: -0.6); g.fillEllipse(in: CGRect(x: -hw*0.2, y: -hw*0.14, width: hw*0.4, height: hw*0.28)); g.restoreGState()
  }
}
func drawV2Face(_ g: CGContext, in box: CGRect, look: FaceLook, who: Who?, light: Bool) {
  let st = who == .gentleman ? V2_GENT : V2_MADAM
  let R0 = min(box.height/2*0.94, box.width/(4 + st.gap)), cx = box.midX, cy = box.midY + look.hop
  g.saveGState(); defer { g.restoreGState() }
  if look.beat != nil { drawNotes(g, cx: cx, cy: box.midY, R0: R0, look: look, who: who, light: light) }
  /* dancing: the whole face slides and tilts about its centre */
  if look.dx != 0 || look.tilt != 0 { g.translateBy(x: cx + look.dx*R0/7.5, y: cy); g.rotate(by: look.tilt); g.translateBy(x: -cx, y: -cy) }
  if look.squash != 0 { g.translateBy(x: cx, y: cy + R0); g.scaleBy(x: 1 + 0.16*look.squash, y: 1 - 0.3*look.squash); g.translateBy(x: -cx, y: -cy - R0) }
  var centers: [CGPoint] = []
  for i in 0..<2 {
    let right = i == 1, e = right ? look.r : look.l, R = R0*e.scale
    let gx = max(-1, min(1, e.px/0.68)), gy = max(-1, min(1, e.py/0.68))
    let c = CGPoint(x: cx + (right ? 1 : -1)*(R0 + R0*st.gap/2) + gx*R0*0.12, y: cy + gy*R0*0.08); centers.append(c)
    g.saveGState(); g.translateBy(x: c.x, y: c.y)
    if e.closed == .blink || e.closed == .sleep || e.closed == .wince { g.scaleBy(x: 1.04, y: 0.92) }      /* the ball squashes a little as it blinks */
    v2Eye(g, R: R, e: e, right: right, who: who, light: light, wet: look.tear != nil)
    g.restoreGState()
  }
  /* crying: a drop runs down from under each eye and fades */
  if let t = look.tear {
    for (i, c) in centers.enumerated() { let q = (t + CGFloat(i)*0.5).truncatingRemainder(dividingBy: 1), side: CGFloat = i == 0 ? -1 : 1
      drawDrop(g, at: CGPoint(x: c.x + side*R0*0.72, y: c.y + R0*0.6 + q*R0*1.3), r: R0*0.16, color: FX_TEAR.copy(alpha: min(1, (1 - q)*3))!) } }
  if let sp = look.sparkle {
    let ink = light ? rgb(0.1, 0.09, 0.14) : rgb(1, 1, 1), cl = centers[0], cr = centers[1]
    let spots: [(CGPoint, CGColor)] = [(CGPoint(x: cl.x - R0*1.15, y: cy - R0*0.85), FX_SPIN), (CGPoint(x: (cl.x + cr.x)/2, y: cy - R0*1.2), ink), (CGPoint(x: cr.x + R0*1.2, y: cy - R0*0.7), FX_HEART)]
    for (k, s) in spots.enumerated() { let tw = max(0, sin(sp*CGFloat.pi*2*1.3 + CGFloat(k)*2.1)); drawSparkle(g, at: s.0, r: R0*0.42*tw, color: s.1, turn: sp*0.6) } }
  if let sw = look.sweat {
    let c = centers[1], th = (-0.38 + 0.4*sw) * CGFloat.pi, dr = R0*0.2
    drawDrop(g, at: CGPoint(x: c.x + cos(th)*(R0 + dr*1.2), y: c.y + sin(th)*(R0 + dr*1.2)), r: dr, color: FX_SWEAT.copy(alpha: sin(sw * CGFloat.pi))!) }
  /* low battery: a little empty battery sits on the right eye like a badge, its red sliver blinking */
  if let bt = look.battery {
    let c = centers[1], bw = max(7, R0*1.0), bh = bw*0.56, x = c.x + R0*0.35, y = c.y + R0*0.35
    let body = CGRect(x: x, y: y, width: bw, height: bh), lw = max(1, bw*0.12)
    g.setFillColor(light ? rgb(1, 1, 1) : rgb(0.08, 0.08, 0.1)); g.addPath(CGPath(roundedRect: body.insetBy(dx: -lw*0.6, dy: -lw*0.6), cornerWidth: bh*0.35, cornerHeight: bh*0.35, transform: nil)); g.fillPath()
    let ink = light ? rgb(0.1, 0.09, 0.14) : rgb(1, 1, 1)
    g.setStrokeColor(ink); g.setLineWidth(lw); g.addPath(CGPath(roundedRect: body, cornerWidth: bh*0.3, cornerHeight: bh*0.3, transform: nil)); g.strokePath()
    g.setFillColor(ink); g.fill(CGRect(x: body.maxX + lw*0.3, y: body.midY - bh*0.2, width: lw*1.1, height: bh*0.4))
    if sin(bt*CGFloat.pi*2) > -0.3 { g.setFillColor(FX_HEART); g.fill(CGRect(x: body.minX + lw*1.2, y: body.minY + lw*1.2, width: bw*0.18, height: bh - lw*2.4)) } }
  /* asleep: three z's drift up and away from the right eye, one after another */
  if let zt = look.zzz {
    let c = centers[1], col = light ? NSColor(white: 0.12, alpha: 1) : NSColor.white
    for k in 0..<3 { let u = ((zt/2.4) + CGFloat(k)/3).truncatingRemainder(dividingBy: 1), size = R0*(0.55 + 0.5*u)
      let a = attributed("z", size, .heavy, col.withAlphaComponent(sin(u*CGFloat.pi)))
      drawText(g, a, in: CGRect(x: c.x + R0*(0.55 + 0.9*u), y: c.y - R0*(0.6 + 1.3*u) - size*0.6, width: size*1.2, height: size*1.4)) } }
}
/* a quiet note now and then while they dance: hers every two beats, his every four; it floats up beside them and fades.
   Worked out from the beat count alone (like the z's), so every picture of the same moment is the same */
func drawEighth(_ g: CGContext, at p: CGPoint, s: CGFloat, beamed: Bool) {
  func head(_ c: CGPoint) { g.saveGState(); g.translateBy(x: c.x, y: c.y); g.rotate(by: -0.35); g.fillEllipse(in: CGRect(x: -s*0.3, y: -s*0.21, width: s*0.6, height: s*0.42)); g.restoreGState() }
  g.setLineWidth(max(0.7, s*0.11)); g.setLineCap(.round)
  if !beamed { head(p); g.beginPath(); g.move(to: CGPoint(x: p.x + s*0.27, y: p.y - s*0.06)); g.addLine(to: CGPoint(x: p.x + s*0.27, y: p.y - s*1.05))
    g.addQuadCurve(to: CGPoint(x: p.x + s*0.62, y: p.y - s*0.58), control: CGPoint(x: p.x + s*0.36, y: p.y - s*0.72)); g.strokePath() }
  else { let w = s*0.62; head(p); head(CGPoint(x: p.x + w, y: p.y - s*0.12))
    g.beginPath(); g.move(to: CGPoint(x: p.x + s*0.27, y: p.y - s*0.06)); g.addLine(to: CGPoint(x: p.x + s*0.27, y: p.y - s*1.02))
    g.move(to: CGPoint(x: p.x + w + s*0.27, y: p.y - s*0.18)); g.addLine(to: CGPoint(x: p.x + w + s*0.27, y: p.y - s*1.14)); g.strokePath()
    g.setLineWidth(max(1, s*0.2)); g.setLineCap(.butt); g.beginPath(); g.move(to: CGPoint(x: p.x + s*0.22, y: p.y - s*1.0)); g.addLine(to: CGPoint(x: p.x + w + s*0.32, y: p.y - s*1.12)); g.strokePath() } }
func drawNotes(_ g: CGContext, cx: CGFloat, cy: CGFloat, R0: CGFloat, look: FaceLook, who: Who?, light: Bool) {
  guard let beat = look.beat else { return }
  let ink = light ? rgb(0.12, 0.11, 0.15) : rgb(0.95, 0.945, 0.925)
  let cols = who == .gentleman ? [ink, light ? hex("#5d6f80") : hex("#9fb0c4"), FX_SPIN] : [FX_SPIN, FX_HEART, ink]
  let every = look.noteEvery, life: CGFloat = 1.7, last = Int(floor(beat/every))
  for i in (last - 3)...last {
    let age = (beat - CGFloat(i)*every)*look.beatLen; guard age >= 0 && age <= life else { continue }
    let u = age/life, side: CGFloat = i & 1 == 1 ? 1 : -1, s = R0*(0.5 + 0.12*u)
    let x = cx + side*R0*(2.2 + 0.25*u) + sin(u*CGFloat.pi*2)*R0*0.12 - s*0.3, y = cy - R0*(0.1 + 1.6*u)
    let a = 0.85*min(1, u*6)*min(1, (1 - u)*2.2), c = cols[((i % 3) + 3) % 3]
    g.saveGState(); g.setFillColor(c.copy(alpha: c.alpha*a)!); g.setStrokeColor(c.copy(alpha: c.alpha*a)!)
    drawEighth(g, at: CGPoint(x: x, y: y), s: s, beamed: i % 4 == 3); g.restoreGState() } }

/* the dance itself, the same as roomie/lab/dance.html, which he approved (2026-11-26).
   beat counts beats since some start; sure is how sure we are of where the beat is (0: they only know a song is on,
   so they sway loosely with no sharp hits; 1: hits land on the beat). amt fades the whole dance in and out */
func applyDance(_ f: inout FaceLook, beat b: Double, sure: Double, period: Double, who: Who, amt: Double) {
  guard amt > 0.001 else { return }
  let ph = b - floor(b), bar = Int(floor(b/4)), inBar = b - floor(b/4)*4, phrase = ((bar % 8) + 8) % 8
  let hit = exp(-ph*7)*sure, soft = 0.5 - 0.5*cos(ph*Double.pi*2), A = CGFloat(amt)
  func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a)*A }
  var tilt = 0.0, dx = 0.0, hop = 0.0, squash = 0.0, px = 0.0, py = 0.0, up = 0.0, pupil = 0.42
  var joy = false, heart = 0.0, wink = false, browUp = false
  if who == .madam {
    /* half time: one side per two beats, a small bounce down on every beat; the gaze rides along, it doesn't dart */
    let sway = sin(Double.pi*b/2)
    tilt = 0.13*sway; dx = 1.6*sway
    hop = 0.9*hit - 0.5*(1 - hit)*sure*min(1, ph*3) + 0.6*soft*(1 - sure)
    squash = 0.3*hit; px = 0.35*sway; py = -0.15; pupil = 0.42 + 0.07*hit; up = -0.05
    joy = ((phrase == 1 || phrase == 3) && inBar >= 2) || (phrase == 6 && inBar >= 1)     /* feeling it: three times a phrase */
    if phrase == 7 { heart = 0.78 + 0.3*hit + 0.08*soft }                                     /* hearts that beat with the song */
    wink = phrase == 5 && inBar >= 3 && inBar < 3.5                                           /* a wink at you on the last beat */
  } else {
    let sway = sin(Double.pi*b/2)                                                             /* smaller: a dignified sway */
    tilt = 0.07*sway; dx = 1.2*sway
    hop = 1.1*hit + 0.5*soft*(1 - sure); squash = 0.14*hit                                    /* a small nod down on the beat */
    px = 0.3*sway; py = -0.05; up = -0.12 - 0.1*soft*(1 - sure) - 0.14*hit; pupil = 0.42 + 0.05*hit   /* awake, enjoying it */
    joy = ((phrase == 1 || phrase == 3 || phrase == 5) && inBar >= 2) || phrase == 7          /* savouring, and a whole bar at the end */
    browUp = phrase == 6 && inBar < 2                                                         /* one lid up: rather good, this */
  }
  f.tilt = mix(f.tilt, CGFloat(tilt)); f.dx = mix(f.dx, CGFloat(dx)); f.hop = mix(f.hop, CGFloat(hop)); f.squash = mix(f.squash, CGFloat(squash))
  for i in 0..<2 { var e = i == 0 ? f.l : f.r
    e.px = mix(e.px, CGFloat(px)); e.py = mix(e.py, CGFloat(py)); e.pupil = mix(e.pupil, CGFloat(pupil))
    e.up = mix(e.up, CGFloat(browUp && i == 0 ? -0.45 : up))
    if browUp { e.px = mix(e.px, 0.5) }
    if amt > 0.85 {
      if joy { e.closed = .joy } else if wink && i == 1 { e.closed = .blink }
      if heart > 0 && !joy { e.heart = CGFloat(heart); e.up = -0.25; if e.closed == .blink { e.closed = nil } } }
    if i == 0 { f.l = e } else { f.r = e } }
  if amt > 0.5 { f.beat = CGFloat(b); f.beatLen = CGFloat(period); f.noteEvery = who == .madam ? 2 : 4 }
}

func drawFace(_ g: CGContext, in box: CGRect, look: FaceLook, who: Who?, ink: CGColor = rgb(0, 0, 0), dark: Bool = false, deep: Bool = false) {
  if USE_V2 { drawV2Face(g, in: box, look: look, who: who, light: !dark); return }
  let r = min(box.height/2 - 0.5, box.width/4.44), cy = box.midY + look.hop
  let gap = r*(who == .madam ? 0.3 : 0.22), cl = CGPoint(x: box.midX - r - gap/2, y: cy), cr = CGPoint(x: box.midX + r + gap/2, y: cy)
  /* poked: squashed flat and wide, then springing back */
  g.saveGState(); defer { g.restoreGState() }
  /* layers below are as big as the clip: keep it to the face, or a big window pays for all of itself */
  g.clip(to: CGRect(x: box.minX - r*0.9, y: box.minY - r*1.0 + look.hop, width: box.width + r*1.8, height: box.height + r*2.2))
  if look.squash != 0 { g.translateBy(x: box.midX, y: cy + r); g.scaleBy(x: 1 + 0.16*look.squash, y: 1 - 0.32*look.squash); g.translateBy(x: -box.midX, y: -cy - r) }
  g.beginTransparencyLayer(auxiliaryInfo: nil)
  if dark {
    /* on a dark bar: light the eye's silhouette, then take its darkness map out of it */
    g.setFillColor(ink)
    for (c, e) in [(cl, look.l), (cr, look.r)] where e.closed == nil || e.closed == .blink || e.closed == .sleep {
      let k = r - max(1.05, r*0.14)*0.7; g.fillEllipse(in: CGRect(x: c.x - k, y: c.y - k, width: 2*k, height: 2*k)) }
    g.setBlendMode(.destinationOut); g.beginTransparencyLayer(auxiliaryInfo: nil)
    drawGlyphEye(g, c: cl, r: r, e: look.l, right: false, who: who, ink: rgb(0, 0, 0), pass: .tone, dark: true, deep: deep)
    drawGlyphEye(g, c: cr, r: r, e: look.r, right: true, who: who, ink: rgb(0, 0, 0), pass: .tone, dark: true, deep: deep)
    g.endTransparencyLayer(); g.setBlendMode(.normal)
  } else {
    drawGlyphEye(g, c: cl, r: r, e: look.l, right: false, who: who, ink: ink, pass: .tone)
    drawGlyphEye(g, c: cr, r: r, e: look.r, right: true, who: who, ink: ink, pass: .tone)
  }
  drawGlyphEye(g, c: cl, r: r, e: look.l, right: false, who: who, ink: ink, pass: .line)
  drawGlyphEye(g, c: cr, r: r, e: look.r, right: true, who: who, ink: ink, pass: .line)
  g.endTransparencyLayer()
  /* the effects, in quiet colour (no yellow, no brown): hearts, spirals, tears, sweat */
  let lw = max(1.05, r*0.14), inner = r - lw*0.9
  for (i, (c, e)) in [(cl, look.l), (cr, look.r)].enumerated() where e.closed == nil {
    g.saveGState(); g.translateBy(x: c.x, y: c.y)
    if e.heart <= 0.02 { g.addEllipse(in: CGRect(x: -inner, y: -inner, width: 2*inner, height: 2*inner)); g.clip() }   /* hearts may grow past the eye */
    if e.spiral > 0.5 {
      g.setStrokeColor(FX_SPIN); g.setLineWidth(lw*1.2); g.setLineCap(.round); g.beginPath()
      for k in 0...40 { let q = CGFloat(k)/40, a = e.spin + q * .pi*3.2, rr = inner*0.92*q
        let p = CGPoint(x: cos(a)*rr, y: sin(a)*rr); if k == 0 { g.move(to: p) } else { g.addLine(to: p) } }
      g.strokePath()
    } else if e.heart > 0.02 {
      /* love: the pupil is a heart, leaning a little toward where they look */
      let w = r*0.86*e.heart, k = max(0, inner - w*0.5)/0.68
      g.translateBy(x: e.px*k*0.35, y: e.py*k*0.35 + r*0.04)
      g.setFillColor(FX_HEART); g.addPath(heartPath(w)); g.fillPath()
    }
    g.restoreGState()
  }
  /* crying: a drop slides down the outside of each eye and fades; on the screen below they fall (Rain) */
  if let t = look.tear {
    for (i, c) in [cl, cr].enumerated() { let q = (t + CGFloat(i)*0.5).truncatingRemainder(dividingBy: 1), side: CGFloat = i == 0 ? -1 : 1
      let th = (0.12 + 0.36*q*q) * CGFloat.pi, dr = r*0.22
      let p = CGPoint(x: c.x + side*cos(th)*(r + dr*0.5), y: c.y + sin(th)*(r + dr*0.5))
      drawDrop(g, at: p, r: dr, color: FX_TEAR.copy(alpha: sin(q * CGFloat.pi))!) } }
  if let sp = look.sparkle {
    /* three little stars about them, each twinkling in its own time */
    let spots: [(CGPoint, CGColor)] = [(CGPoint(x: cl.x - r*1.15, y: cy - r*0.85), FX_SPIN), (CGPoint(x: (cl.x + cr.x)/2, y: cy - r*1.2), ink), (CGPoint(x: cr.x + r*1.2, y: cy - r*0.7), FX_HEART)]
    for (k, s) in spots.enumerated() { let tw = max(0, sin(sp*CGFloat.pi*2*1.3 + CGFloat(k)*2.1))
      drawSparkle(g, at: s.0, r: r*0.42*tw, color: s.1, turn: sp*0.6) } }
  if let sw = look.sweat {
    let th = (-0.38 + 0.4*sw) * CGFloat.pi, dr = r*0.2
    drawDrop(g, at: CGPoint(x: cr.x + cos(th)*(r + dr*1.2), y: cr.y + sin(th)*(r + dr*1.2)), r: dr, color: FX_SWEAT.copy(alpha: sin(sw * CGFloat.pi))!) }
}
/* one family: the same lightness and chroma (OKLCH 0.63, 0.14), only the hue differs */
/* tears, to tune by eye: how long they cry, a drop every so many seconds, how fast drops fall (pt/s²) */
let TEARS = (cryFor: 4.0, every: 1.0, gravity: CGFloat(520))
/* a four-point star, r from its middle to a point */
func drawSparkle(_ g: CGContext, at c: CGPoint, r: CGFloat, color: CGColor, turn: CGFloat = 0) {
  guard r > 0.2 else { return }
  g.saveGState(); g.translateBy(x: c.x, y: c.y); g.rotate(by: turn)
  let p = CGMutablePath(), k = r*0.14; p.move(to: CGPoint(x: 0, y: -r))
  p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: k, y: -k)); p.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: k, y: k))
  p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -k, y: k)); p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -k, y: -k))
  g.addPath(p); g.setFillColor(color); g.fillPath(); g.restoreGState()
}
/* a burst of stars out of a point, u seconds after it began: they spring out, twinkle, and go */
func drawBurst(_ g: CGContext, at c: CGPoint, radius R: CGFloat, size: CGFloat, u: Double) {
  guard u >= 0 && u < 1.6 else { return }
  let colors = [rgb(1, 1, 1), FX_HEART, FX_SPIN, FX_TEAR, rgb(1, 1, 1), FX_HEART, FX_SPIN, FX_TEAR]
  for k in 0..<8 {
    let d = u - Double(k)*0.04; guard d > 0 else { continue }
    let a = CGFloat(k)/8 * .pi*2 + 0.3, out = CGFloat(1 - exp(-7*d)*cos(9*d)), fade = CGFloat(max(0, min(1, (1.6 - u)/0.5)))
    let tw = CGFloat(0.75 + 0.25*sin(d*14 + Double(k))), rr = R*(0.55 + 0.45*out)*(k % 2 == 0 ? 1 : 0.78)
    drawSparkle(g, at: CGPoint(x: c.x + cos(a)*rr, y: c.y + sin(a)*rr), r: size*(k % 2 == 0 ? 1 : 0.7)*out*tw*fade, color: colors[k], turn: CGFloat(d)*0.8) }
}
let FX_HEART = rgb(0.804, 0.404, 0.4), FX_TEAR = rgb(0.224, 0.568, 0.828), FX_SWEAT = FX_TEAR, FX_SPIN = rgb(0.56, 0.5, 0.92)   /* 0.7: the violet is her iris's */   /* from his red #CD6766: one lightness and chroma, only the hue differs */
/* baked: drawn once into a bitmap for the given bar (dark or light), instead of each time macOS shows it (0.9: dancing redraws a lot) */
func glyphImage(_ look: FaceLook, who: Who?, dim: Bool = false, scale: CGFloat = 1, squash: CGFloat = 0, puff: Double = -1, baked: Bool? = nil) -> NSImage {
  let w = EyesView.eyeH*2.22 + 10, h: CGFloat = 22
  let fx = look.tear != nil || look.sweat != nil || look.sparkle != nil || [look.l, look.r].contains { $0.closed == nil && ($0.heart > 0.02 || $0.spiral > 0.5) }
  if let dk = baked, USE_V2 { return NSImage(cgImage: glyphCG(look, who: who, dim: dim, scale: scale, squash: squash, puff: puff, dark: dk), size: NSSize(width: w, height: h)) }
  let img = NSImage(size: NSSize(width: w, height: h), flipped: true) { rect in
    guard let g = NSGraphicsContext.current?.cgContext else { return false }
    paintGlyph(g, rect, look, who: who, dim: dim, scale: scale, squash: squash, puff: puff, fx: fx, dark: NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    return true }
  /* a template is painted by macOS in one colour; while hearts, tears, sweat or spirals show, it is drawn as is */
  img.isTemplate = !fx && !USE_V2 && scale >= 0.99 && puff < 0; return img
}
func glyphCG(_ look: FaceLook, who: Who?, dim: Bool = false, scale: CGFloat = 1, squash: CGFloat = 0, puff: Double = -1, dark: Bool, px: CGFloat = 2) -> CGImage {
  let w = EyesView.eyeH*2.22 + 10, h: CGFloat = 22
  let fx = look.tear != nil || look.sweat != nil || look.sparkle != nil || [look.l, look.r].contains { $0.closed == nil && ($0.heart > 0.02 || $0.spiral > 0.5) }
  return bitmap(CGSize(width: w, height: h), scale: px) { g in paintGlyph(g, CGRect(x: 0, y: 0, width: w, height: h), look, who: who, dim: dim, scale: scale, squash: squash, puff: puff, fx: fx, dark: dark) } }
func paintGlyph(_ g: CGContext, _ rect: CGRect, _ look: FaceLook, who: Who?, dim: Bool, scale: CGFloat, squash: CGFloat, puff: Double, fx: Bool, dark: Bool) {
    let eh = EyesView.eyeH, fw = eh*2.22
    let ink = fx ? (dark ? rgb(1, 1, 1) : rgb(0, 0, 0, 0.85)) : rgb(0, 0, 0)
    if dim { g.setAlpha(0.5); g.beginTransparencyLayer(auxiliaryInfo: nil) }
    /* teleporting: they swell, squeeze flat and wide and are gone; coming back they pop up on a spring */
    if scale > 0.01 { g.saveGState(); g.translateBy(x: rect.midX, y: rect.midY)
      g.scaleBy(x: max(0.01, scale + 0.5*squash), y: max(0.01, scale*(1 - 0.85*squash))); g.translateBy(x: -rect.midX, y: -rect.midY)
      drawFace(g, in: CGRect(x: rect.midX - fw/2, y: rect.midY - eh/2, width: fw, height: eh), look: look, who: who, ink: ink, dark: dark); g.restoreGState() }
    /* a puff of four little stars where they vanish or appear */
    if puff >= 0 && puff < 0.35 { let k = CGFloat(puff/0.35), d = 4 + 9*CGFloat(1 - exp(-6*puff/0.35)), cols = [rgb(1, 1, 1), FX_SPIN, FX_HEART, rgb(1, 1, 1)]
      for i in 0..<4 { let a = CGFloat(i)*CGFloat.pi/2 + 0.4
        drawSparkle(g, at: CGPoint(x: rect.midX + cos(a)*d*1.3, y: rect.midY + sin(a)*d*0.55), r: 2.6*(1 - k), color: cols[i].copy(alpha: 1 - k)!) } }
    if dim { g.endTransparencyLayer() }
}
/* 0.5: the owner found the glyph flat and foreign in feeling; the eyeballs come back, at 16 pt, in neutral greys */
func ballImage(_ look: FaceLook, who: Who?) -> NSImage {
  let w = EyesView.eyeH*2.22 + 10, h: CGFloat = 22
  let img = NSImage(size: NSSize(width: w, height: h), flipped: true) { rect in
    guard let g = NSGraphicsContext.current?.cgContext else { return false }
    let eh = EyesView.eyeH, fw = eh*2.22
    drawBallFace(g, in: CGRect(x: rect.midX - fw/2, y: rect.midY - eh/2, width: fw, height: eh), look: look, who: who)
    return true }
  return img
}

/* the same face is not drawn twice: a look, rounded to what can be seen at menu-bar size */
func signature(_ f: FaceLook, fine k: CGFloat = 1) -> [Int] {
  func q(_ e: EyeLook) -> [Int] {
    var c = 0; if let k = e.closed { switch k { case .blink: c = 1; case .sleep: c = 2; case .joy: c = 3; case .wince: c = 4; case .cry: c = 5 } }
    if c != 0 { return [c] }
    return [Int((e.px*30*k).rounded()), Int((e.py*30*k).rounded()), Int(e.pupil*40*k), Int((e.up*36*k).rounded()), Int((e.ang*16*k).rounded()),
            Int(e.spiral*16*k), e.spiral > 0.05 ? Int(e.spin*6*k) : 0, Int(e.scale*80*k), Int(e.heart*48*k)] }
  return q(f.l) + [-1] + q(f.r) + [f.tear.map { Int($0*60*k) } ?? -1, f.sweat.map { Int($0*60*k) } ?? -1, Int((f.hop*4*k).rounded()), Int((f.squash*40*k).rounded()), f.sparkle.map { Int($0*20*k) } ?? -1, f.battery.map { Int($0*8) } ?? -1, f.zzz.map { Int($0*12*k) } ?? -1,
                                   Int((f.tilt*120*k).rounded()), Int((f.dx*4*k).rounded()), f.beat.map { Int($0*f.beatLen*30*k) } ?? -1]
}

// MARK: - text

func rounded(_ size: CGFloat, _ w: NSFont.Weight) -> NSFont { let f = NSFont.systemFont(ofSize: size, weight: w)
  if let d = f.fontDescriptor.withDesign(.rounded), let r = NSFont(descriptor: d, size: size) { return r }; return f }
func attributed(_ s: String, _ size: CGFloat, _ w: NSFont.Weight, _ color: NSColor, center: Bool = false) -> NSAttributedString {
  let p = NSMutableParagraphStyle(); p.alignment = center ? .center : .left; p.lineSpacing = 1.5
  return NSAttributedString(string: s, attributes: [.font: rounded(size, w), .foregroundColor: color, .paragraphStyle: p]) }
/* words appearing one after another, as if they were saying them */
func revealed(_ s: String, _ size: CGFloat, _ w: NSFont.Weight, _ color: NSColor, center: Bool = false, age: Double, from: Double) -> NSAttributedString {
  let out = NSMutableAttributedString(attributedString: attributed(s, size, w, color, center: center))
  var loc = 0
  for (i, word) in s.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
    let len = word.utf16.count, k = max(0, min(1, (age - from - Double(i)*0.045)/0.16))
    if len > 0 { out.addAttribute(.foregroundColor, value: color.withAlphaComponent(CGFloat(k)), range: NSRange(location: loc, length: len)) }
    loc += len + 1 }
  return out }
func textHeight(_ a: NSAttributedString, width: CGFloat) -> CGFloat {
  ceil(a.boundingRect(with: NSSize(width: width, height: 2000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height) }
func drawText(_ g: CGContext, _ a: NSAttributedString, in r: CGRect) {
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: true)
  a.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading]); NSGraphicsContext.restoreGraphicsState() }
func bitmap(_ size: CGSize, scale: CGFloat = 2, _ draw: (CGContext) -> Void) -> CGImage {
  let g = CGContext(data: nil, width: Int(size.width*scale), height: Int(size.height*scale), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  g.scaleBy(x: scale, y: scale); g.translateBy(x: 0, y: size.height); g.scaleBy(x: 1, y: -1)
  draw(g); return g.makeImage()! }
func writePNG(_ img: CGImage, _ path: String) { let rep = NSBitmapImageRep(cgImage: img)
  try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path)) }

// MARK: - what they say

enum Kind { case eyes, move, late, hello }
enum Reaction { case back, cry, dizzy, battery, hot, music }
struct Card { var kind: Kind; var text: String; var buttons: [String] }

func clockText(_ d: Date = Date()) -> String { let f = DateFormatter(); f.dateFormat = "H:mm"; return f.string(from: d) }
func partOfDay() -> String { let h = Calendar.current.component(.hour, from: Date()); return h < 12 ? "morning" : h < 18 ? "afternoon" : "evening" }

enum Lines {
  static func card(_ k: Kind, _ who: Who) -> Card {
    let m = who == .madam
    switch k {
    case .hello: return Card(kind: k, text: m ? "Hello, darling. I'll be keeping an eye on you. Two, in fact." : "Good \(partOfDay()). I shall be keeping an eye on you. Both, in fact.", buttons: [])
    case .eyes: return Card(kind: k, text: (m ? ["Darling, your eyes. Look at something far away for twenty seconds. I'll count.",
                                               "Twenty minutes of screen. Find a window and look out of it for me. I'll count.",
                                               "Look up, darling. Something far away, twenty seconds. I'll keep time.",
                                               "Your eyes look tired. Let's find a horizon. Twenty seconds.",
                                               "Somewhere out there is a tree. Find it with your eyes. Twenty seconds.",
                                               "Rest them for me: far away, twenty seconds. I count, you look."]
                                             : ["Twenty minutes, if I may. Kindly look at something twenty feet away. I shall count.",
                                                "Your eyes have earned a rest. Twenty seconds, at a distance. I shall count.",
                                                "Might I recommend the horizon? Twenty seconds should suffice.",
                                                "A distant view, if you please. I shall keep the time.",
                                                "Your eyes deserve a short holiday. Twenty seconds, somewhere far off.",
                                                "The screen will keep. Twenty seconds on something distant, I suggest."]).randomElement()!,
                            buttons: [m ? "Okay" : "Very well", "Later"])
    case .move: return Card(kind: k, text: (m ? ["Half an hour in that chair. Up you get: walk for five minutes.",
                                               "Stand up, stretch, go and fetch some water. I'll mind the screen.",
                                               "You've been sitting for ages, darling. Five minutes on your feet.",
                                               "Up, up. A little walk, five minutes. The screen will wait.",
                                               "Stretch your legs for me. Five minutes. I'll be right here."]
                                             : ["Thirty minutes seated. A five-minute walk would do you credit.",
                                                "Might I suggest a stroll? Five minutes. I shall hold the fort.",
                                                "Half an hour in the chair. A short constitutional, perhaps?",
                                                "A five-minute turn about the room would be most agreeable.",
                                                "Legs, I'm told, are meant for use. Five minutes?"]).randomElement()!,
                            buttons: ["Going", "Later"])
    case .late: return Card(kind: k, text: (m ? ["It's \(clockText()), darling. Bed.", "\(clockText()). Even I'm closing my eyes. Bed?", "Darling, it's \(clockText()). Tomorrow will thank you."]
                                             : ["It is \(clockText()). Might I suggest bed?", "\(clockText()), and still at it. Bed would be wise.", "It is \(clockText()). The day is quite over, I assure you."]).randomElement()!,
                            buttons: ["Good night", "Not yet"])
    }
  }
  /* their short replies, never the same twice in a row */
  static var lastPick: [String: String] = [:]
  static func pick(_ key: String, _ who: Who, _ madam: [String], _ gent: [String]) -> String {
    let list = who == .madam ? madam : gent, k = key + "\(who)"
    let choice = list.filter { $0 != lastPick[k] }.randomElement() ?? list[0]; lastPick[k] = choice; return choice }
  static func counting(_ who: Who) -> String { pick("count", who,
    ["Far away, darling. I'll chime when it's done.", "Out of the window. You'll hear me at twenty.", "Look far. A little ding when it's time.", "Further than that. I'll chime."],
    ["Into the distance. A chime will tell you when.", "Eyes on the horizon. I shall chime at twenty.", "A distant view, please. Listen for the chime.", "Further still. You'll hear me."]) }
  static func eyesDone(_ who: Who) -> String { pick("eyes", who,
    ["There. Better, isn't it?", "Lovely. Your eyes thank you.", "Good. Back to it, darling.", "See? Twenty seconds, and you're new."],
    ["Splendid. Carry on.", "Most refreshing, I'm sure.", "Very good. As you were.", "Excellent. The screen awaits."]) }
  static func moveGo(_ who: Who) -> String { pick("go", who,
    ["Off you go. I'll be here.", "Go on. I'll keep your seat warm.", "Shoo. Five minutes.", "Lovely. Don't run."],
    ["Very good. Take your time.", "Enjoy the stroll. I shall mind things here.", "Off you go. The fort is held.", "Capital. Mind the stairs."]) }
  static func night(_ who: Who) -> String { pick("night", who,
    ["Sleep well, darling.", "Night night. Dream of something far away.", "Good. Off to bed with you.", "Sweet dreams. I'll close my eyes too."],
    ["Good night. I shall keep watch.", "Rest well. Until tomorrow.", "Good night. The lights are yours to dim.", "Sleep soundly. I'll be here in the morning."]) }
  static func later(_ who: Who) -> String { pick("later", who,
    ["Fine. But I'm counting.", "Later, then. I'll remember.", "Hmm. Soon, darling.", "All right. Don't make me ask twice.", "Suit yourself. I'll be watching."],
    ["As you wish.", "Very well. I shall ask again shortly.", "Understood. Merely postponed.", "Of course. I'll put it in the diary.", "Noted, with mild disappointment."]) }
  /* what they say when something happens to them: rare moments only, a slim pill from the notch */
  static func react(_ r: Reaction, _ who: Who) -> String {
    switch r {
    case .back: return pick("back", who, ["There you are, darling.", "Oh, you're back. I missed you.", "Welcome home, darling.", "Finally. I was getting bored."],
                                       ["Ah. Welcome back.", "Good to have you back.", "There you are. I kept watch.", "Back again. Splendid."])
    case .cry: return pick("cry", who, ["Ow. That's enough, darling.", "Stop it. I bruise easily.", "Was that necessary?", "Fine. I'm crying now. Happy?"],
                                     ["I say. That was uncalled for.", "Really, now. A gentleman has feelings.", "Ow. I shall pretend that didn't happen.", "Must you?"])
    case .dizzy: return pick("dizzy", who, ["Whoa. The room is spinning.", "Darling, stop shaking the world.", "I see three of you.", "Wheee. No, wait. Stop."],
                                         ["Steady on. I'm quite dizzy.", "Good heavens, the room won't stand still.", "Kindly hold the mouse still.", "I fear I may need to sit down."])
    case .battery: return pick("battery", who, ["I'm fading, darling. Charger?", "Low battery. Feed me.", "Running on fumes here."],
                                             ["Rather low on power, I'm afraid.", "A charger, if you'd be so kind.", "I feel a little faint. Battery, you see."])
    case .hot: return pick("hot", who, ["Is it warm in here, or is it you?", "Phew. Someone's working hard.", "I'm melting, darling."],
                                     ["Rather warm in here, isn't it?", "One is perspiring. The Mac is hot.", "Shall we let it cool a little?"])
    case .music: return music(who, artist: nil)
    }
  }
  /* a song comes on after a quiet while: one light line, with the artist when the player says who it is */
  static func music(_ who: Who, artist a0: String?) -> String {
    if let a = a0, a.count <= 26 {
      return pick("musicA", who, ["Ooh, \(a). Good taste, darling.", "\(a)? Turn it up, darling.", "Oh, I love \(a)."],
                                 ["Ah, \(a). Splendid choice.", "\(a). A fine tune, if I may.", "\(a)? Rather good, this."]) }
    return pick("music", who, ["Oh, I love this one.", "Ooh. Now we're dancing.", "Music! Finally, darling."],
                              ["A fine tune, if I may say so.", "Ah. Music. Splendid.", "I do enjoy this one."]) }
  /* "Going," you said, and you stayed: a jab, never a scolding, and no new demand */
  static func caught(_ who: Who) -> String { (who == .madam
    ? ["Going, you said. Darling, I can see you.", "Shortest walk I've ever seen.", "Lovely walk? You haven't moved an inch."]
    : ["A remarkably brief stroll, if I may say so.", "I was told \u{201C}going\u{201D}. I see staying. No matter.", "The fort, I notice, is still held by you."]).randomElement()! }
}

// MARK: - manners (0.7): no card while you are on a call or in full screen, and a quiet hour on request

/* someone is on a call: an app is using the default microphone. No permission is needed to ask this */
func micInUse() -> Bool {
  var dev = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != 0 else { return false }
  var running = UInt32(0); size = UInt32(MemoryLayout<UInt32>.size); addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
  guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running) == noErr else { return false }
  return running != 0 }
/* the front app fills a whole screen (a film, a slideshow, a full-screen window): only window sizes are read, not their contents */
func frontIsFullScreen() -> Bool {
  guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid(),
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
  let sizes = NSScreen.screens.map { $0.frame.size }
  for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == front.processIdentifier && (w[kCGWindowLayer as String] as? Int) == 0 {
    if let d = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: d),
       sizes.contains(where: { abs($0.width - r.width) < 1 && abs($0.height - r.height) < 1 }) { return true } }
  return false }

// MARK: - music (0.9): when a song is on they dance

/* sound is going out of the Mac right now (any app). Like micInUse, this needs no permission */
func outputRunning() -> Bool {
  var dev = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != 0 else { return false }
  var running = UInt32(0); size = UInt32(MemoryLayout<UInt32>.size); addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
  guard AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running) == noErr else { return false }
  return running != 0 }
/* how much later than it is mixed the sound is heard (Bluetooth: a fifth of a second or more), in seconds */
func outputLatency() -> Double {
  var dev = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr, dev != 0 else { return 0 }
  func u32(_ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> Double {
    var v = UInt32(0), sz = UInt32(4), a = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    return AudioObjectGetPropertyData(dev, &a, 0, nil, &sz, &v) == noErr ? Double(v) : 0 }
  var rate = 48000.0, rsz = UInt32(8), ra = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
  if AudioObjectGetPropertyData(dev, &ra, 0, nil, &rsz, &rate) != noErr || rate <= 0 { rate = 48000 }
  let frames = u32(kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput) + u32(kAudioDevicePropertySafetyOffset, kAudioObjectPropertyScopeOutput) + u32(kAudioDevicePropertyBufferFrameSize, kAudioObjectPropertyScopeGlobal)
  return min(0.5, frames/rate) }

/* Spotify and Apple Music tell the whole system when they play or pause, and who is playing; no permission is needed to hear it.
   Delivered at once even though Roomie is never the active app */
final class Music: NSObject {
  var state: [String: Bool] = [:], artist: String? = nil, startedAt = -1e9, stoppedAt = -1e9
  var onStart: (() -> Void)? = nil
  var playing: Bool { state.values.contains(true) }
  static let players = ["com.spotify.client.PlaybackStateChanged": "com.spotify.client", "com.apple.Music.playerInfo": "com.apple.Music"]
  override init() { super.init()
    for name in Music.players.keys { DistributedNotificationCenter.default().addObserver(self, selector: #selector(heard(_:)), name: Notification.Name(name), object: nil, suspensionBehavior: .deliverImmediately) }
    /* already playing when Roomie starts: a player is open and sound is going out */
    let open = NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }.filter { Music.players.values.contains($0) }
    if let first = open.first, outputRunning() { state[first] = true; startedAt = CACurrentMediaTime() } }
  @objc func heard(_ n: Notification) {
    let src = Music.players[n.name.rawValue] ?? n.name.rawValue, was = playing
    state[src] = (n.userInfo?["Player State"] as? String) == "Playing"
    if let a = n.userInfo?["Artist"] as? String { artist = a.trimmingCharacters(in: .whitespaces).isEmpty ? nil : a }
    let now = CACurrentMediaTime()
    if playing && !was { startedAt = now; onStart?() }
    if !playing && was { stoppedAt = now }
    if LOG { FileHandle.standardError.write("music \(src) \(playing ? "playing" : "stopped") \(artist ?? "")\n".data(using: .utf8)!) } }
}

/* the beat, found in the sound: onsets, then tempo by autocorrelation, then phase by a comb (as in roomie/lab/dance.html) */
final class BeatTracker {
  var t0 = 0.0, period = 0.5, conf = 0.0
  private var prev: [Float]? = nil, env: [(Double, Double)] = [], lastEst = 0.0
  private let n = 1024, log2n = vDSP_Length(10)
  private let setup = vDSP_create_fftsetup(10, FFTRadix(kFFTRadix2))!
  private var window = [Float](repeating: 0, count: 1024)
  init() { vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM)) }
  deinit { vDSP_destroy_fftsetup(setup) }
  func beat(_ t: Double) -> Double { (t - t0)/period }
  func reset() { prev = nil; env = []; conf = 0 }
  /* x: the latest 1024 samples; t: when they will be heard */
  func feed(_ x: [Float], rate: Double, t: Double) {
    guard x.count == n else { return }
    var w = [Float](repeating: 0, count: n); vDSP_vmul(x, 1, window, 1, &w, 1, vDSP_Length(n))
    var re = [Float](repeating: 0, count: n/2), im = [Float](repeating: 0, count: n/2), mag = [Float](repeating: 0, count: n/2)
    re.withUnsafeMutableBufferPointer { rp in im.withUnsafeMutableBufferPointer { ip in
      var sc = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
      w.withUnsafeBufferPointer { wp in wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n/2) { vDSP_ctoz($0, 2, &sc, 1, vDSP_Length(n/2)) } }
      vDSP_fft_zrip(setup, &sc, 1, log2n, FFTDirection(FFT_FORWARD)); vDSP_zvabs(&sc, 1, &mag, 1, vDSP_Length(n/2)) } }
    /* the beat lives in the kick and the snare: lows count most, the hiss of hats (on the "and") least */
    let hz = rate/Double(n), lo = max(1, Int(30/hz)), hi = min(n/2, Int(4000/hz)), bass = Int(200/hz), mid = Int(1500/hz)
    var flux = 0.0
    if let p = prev { for i in lo..<hi { let d = Double(mag[i] - p[i]); if d > 0 { flux += d*(i < bass ? 6 : i < mid ? 1 : 0.3) } } }
    prev = mag; env.append((t, flux)); while let f = env.first, t - f.0 > 8 { env.removeFirst() }
    if t - lastEst > 0.5 && env.count > 200 { lastEst = t; estimate(t) } }
  private func estimate(_ t: Double) {
    /* onset strength resampled at 200 Hz over the last 8 s, the part above its mean */
    let N = 1600, dt = 0.005; var x = [Double](repeating: 0, count: N), j = 0
    for k in 0..<N { let tk = t - 8 + Double(k + 1)*dt; while j < env.count - 1 && env[j + 1].0 <= tk { j += 1 }; x[k] = env[j].1 }
    let mean = x.reduce(0, +)/Double(N); for k in 0..<N { x[k] = max(0, x[k] - mean) }
    let zero = x.reduce(0) { $0 + $1*$1 }; guard zero > 1e-12 else { conf *= 0.8; return }
    /* tempo: the autocorrelation peak between 70 and 171 bpm, leaning towards 115; refined between lags */
    let l0 = 70, l1 = 172; var ac = [Double](repeating: 0, count: l1 + 2)
    for lag in (l0 - 1)...(l1 + 1) { var s = 0.0; for k in lag..<N { s += x[k]*x[k - lag] }; ac[lag] = s }
    var best = 0.0, lagB = 0
    for lag in l0...l1 { let bpm = 60/(Double(lag)*dt), w = exp(-pow(log2(bpm/115), 2)*1.4); if ac[lag]*w > best { best = ac[lag]*w; lagB = lag } }
    guard lagB > 0 else { return }
    let a = ac[lagB - 1], b = ac[lagB], c = ac[lagB + 1], den = a - 2*b + c
    let per = (Double(lagB) + (den < 0 ? max(-0.5, min(0.5, 0.5*(a - c)/den)) : 0))*dt
    /* phase: the comb that best fits the onsets, recent beats counting most */
    let steps = Int(per/dt); var phB = 0, sB = -1.0
    for ph in 0..<steps { var s = 0.0, m = 0.0
      while true { let k = Int((Double(N - 1 - ph) - m*per/dt).rounded()); if k < 1 { break }
        s += (x[k] + 0.5*x[k - 1] + 0.5*(k + 1 < N ? x[k + 1] : 0))*exp(-m*0.18); m += 1 }
      if s > sB { sB = s; phB = ph } }
    let lastBeat = t - Double(phB)*dt, c2 = min(1, best/zero*2.2)
    /* glide, don't jump: keep the running beat count, nudge period and phase */
    if conf < 0.2 || abs(per - period) > 0.06 { period = per; t0 = lastBeat }
    else { period += (per - period)*0.5; let bb = beat(lastBeat), err = bb - bb.rounded(); t0 += err*period*0.5 }
    conf += (c2 - conf)*0.5 }
}

/* "Dance to the Beat" (asked for, macOS 14.2 and later): a tap on what the Mac plays, mixed down to one channel and
   kept only as the last few thousand samples in memory, for the beat tracker. Nothing is recorded or sent */
@available(macOS 14.2, *)
final class SystemEar {
  private var tap = AudioObjectID(kAudioObjectUnknown), agg = AudioObjectID(kAudioObjectUnknown), proc: AudioDeviceIOProcID? = nil
  private let lock = NSLock(); private var ring = [Float](repeating: 0, count: 8192), w = 0
  private(set) var rate = 48000.0
  var running: Bool { proc != nil }
  func start() -> Bool {
    guard !running else { return true }
    var me = [AudioObjectID](); var pid = getpid(), obj = AudioObjectID(0), sz = UInt32(MemoryLayout<AudioObjectID>.size)
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, UInt32(MemoryLayout<pid_t>.size), &pid, &sz, &obj) == noErr, obj != 0 { me = [obj] }
    let d = CATapDescription(stereoGlobalTapButExcludeProcesses: me); d.uuid = UUID(); d.isPrivate = true; d.muteBehavior = .unmuted
    guard AudioHardwareCreateProcessTap(d, &tap) == noErr else { return false }
    var f = AudioStreamBasicDescription(); sz = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    a.mSelector = kAudioTapPropertyFormat
    if AudioObjectGetPropertyData(tap, &a, 0, nil, &sz, &f) == noErr, f.mSampleRate > 0 { rate = f.mSampleRate }
    let ch = Int(max(1, f.mChannelsPerFrame)), inter = f.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
    let desc: [String: Any] = [kAudioAggregateDeviceNameKey: "Roomie ear", kAudioAggregateDeviceUIDKey: UUID().uuidString,
                               kAudioAggregateDeviceIsPrivateKey: true, kAudioAggregateDeviceTapAutoStartKey: true,
                               kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: d.uuid.uuidString]]]
    guard AudioHardwareCreateAggregateDevice(desc as CFDictionary, &agg) == noErr else { stop(); return false }
    let ok = AudioDeviceCreateIOProcIDWithBlock(&proc, agg, nil) { [weak self] _, input, _, _, _ in self?.take(input, ch: ch, inter: inter) }
    guard ok == noErr, let p = proc, AudioDeviceStart(agg, p) == noErr else { stop(); return false }
    return true }
  func stop() {
    if let p = proc { AudioDeviceStop(agg, p); AudioDeviceDestroyIOProcID(agg, p) }; proc = nil
    if agg != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(agg) }; agg = AudioObjectID(kAudioObjectUnknown)
    if tap != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tap) }; tap = AudioObjectID(kAudioObjectUnknown) }
  private func take(_ input: UnsafePointer<AudioBufferList>, ch: Int, inter: Bool) {
    let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
    guard let b0 = list.first, let d0 = b0.mData else { return }
    lock.lock(); defer { lock.unlock() }
    if inter || list.count == 1 { let c = inter ? max(1, ch) : 1, frames = Int(b0.mDataByteSize)/4/c, p = d0.assumingMemoryBound(to: Float.self)
      for i in 0..<frames { var s: Float = 0; for k in 0..<c { s += p[i*c + k] }; ring[w] = s/Float(c); w = (w + 1) % ring.count } }
    else { let frames = Int(b0.mDataByteSize)/4
      for i in 0..<frames { var s: Float = 0; for b in list { if let d = b.mData { s += d.assumingMemoryBound(to: Float.self)[i] } }; ring[w] = s/Float(list.count); w = (w + 1) % ring.count } } }
  func latest(_ n: Int) -> [Float] { lock.lock(); defer { lock.unlock() }
    return (0..<n).map { ring[(w - n + $0 + ring.count) % ring.count] } }
}

enum DanceMode: String { case beat, own, off }

// MARK: - the rules

enum NudgeMode: String { case all, fewer, none }

final class Coach {
  let k: Double                                   /* 1 = minutes are minutes; --fast: minutes are seconds */
  var eyeT = 0.0, moveT = 0.0, lastAt = -1e9, snoozeUntil = 0.0, lateNext = 0.0
  var pending: Kind? = nil
  init(fast: Bool) { k = fast ? 1.0/60 : 1 }
  var eyeEvery: Double { 20*60*k }; var moveEvery: Double { 30*60*k }; var gap: Double { 8*60*k }
  var lateEvery: Double { 45*60*k }; var snooze: Double { 10*60*k }; var giveUp: Double { 4*60*k }
  /* time counts while you are at the Mac; a minute away resets the eyes, five minutes away count as the walk */
  /* how much care the person wants (right-click > Nudges): all of it, only the walk and bed, or none */
  var mode = NudgeMode(rawValue: defaults.string(forKey: "nudges") ?? "") ?? .all
  func update(now: Double, dt: Double, idle: Double, hour: Double, hold: Bool = false) -> Kind? {
    if idle < 60 { eyeT += dt; moveT += dt }
    if idle >= 60 { eyeT = 0 }
    if idle >= 300 { moveT = 0 }
    guard !hold, mode != .none, pending == nil, now >= snoozeUntil, now - lastAt >= gap, idle < 60 else { return nil }
    var due: Kind? = nil
    if hour >= 0.5 && hour < 5 && now >= lateNext { due = .late }
    else if moveT >= moveEvery { due = .move }
    else if eyeT >= eyeEvery && mode == .all { due = .eyes }
    if let d = due { pending = d; lastAt = now }
    return due
  }
  func done(_ kind: Kind, now: Double) { pending = nil
    switch kind { case .eyes: eyeT = 0; case .move: moveT = 0; eyeT = 0; case .late: lateNext = now + lateEvery; case .hello: break } }
  func later(now: Double) { if pending == .late { lateNext = now + 30*60*k }; pending = nil; snoozeUntil = now + snooze }
  func goodNight(now: Double) { pending = nil; lateNext = now + 6*3600*k }
}

// MARK: - what they feel

struct Senses {
  var idle = 0.0, hour = 12.0
  var battery: Double? = nil, charging = true, hot = false
  var shake = 0.0, rage = false
  var gaze = CGPoint.zero                         /* where you are, as a direction of length 0..1 */
  var islandDir: CGPoint? = nil                   /* where the island is, from the eyes (y down), when it shows */
  var beat: Double? = nil, beatSure = 0.0, beatLen = 0.5   /* 0.9: a song is on; where its beat is, and how sure that is */
}
enum Attend { case none, hint(Double), card, far
  var isNone: Bool { if case .none = self { return true }; return false } }

final class Brain {
  var p = [CGPoint(x: 0, y: 0.1), CGPoint(x: 0, y: 0.1)], v = [CGPoint.zero, CGPoint.zero]
  var dizzy = 0.0, hungry = 0.0, hot = 0.0, drowsy = 0.0
  var asleep = false, away = 0.0, wasCharging = true
  var happyUntil = 0.0, winceUntil = 0.0, cryUntil = 0.0, startleUntil = 0.0, blinkUntil = 0.0, nextBlink = 2.0, flutterAt = 0.0
  var pokes: [Double] = [], up = [0.0, 0.0], ang = [0.0, 0.0]
  var crying = false, cameBack = false, insisting = false
  /* love: heart pupils that spring in past full size, beat twice and shrink away */
  var loveAt = -100.0, sparkleUntil = 0.0
  /* caught you: narrowed, unimpressed eyes that follow the pointer exactly, for a few seconds */
  var suspectUntil = 0.0
  static let loveFor = 2.4
  func love(_ t: Double) { loveAt = t; happyUntil = 0 }
  func heartAmount(_ t: Double) -> Double {
    let u = t - loveAt; guard u >= 0 && u < Brain.loveFor else { return 0 }
    var x = 1 - exp(-7*u)*cos(15*u)
    for b in [0.85, 1.1, 1.55, 1.8] { let d = u - b; if d > 0 && d < 0.2 { x += 0.24*sin(d/0.2 * .pi) } }
    let out = Brain.loveFor - 0.28; if u > out { let k = (u - out)/0.28; x *= 1 - k*k }
    return max(0, x) }
  var tgt = [CGPoint.zero, CGPoint.zero], micro = CGPoint.zero, nextMicro = 0.0
  static let awayAfter = 300.0

  var pokeAt = -100.0
  func poke(_ t: Double) { winceUntil = t + 0.9; pokeAt = t; happyUntil = 0
    pokes = pokes.filter { t - $0 < 30 } + [t]; if pokes.count >= 3 { cryUntil = t + 0.9 + TEARS.cryFor; pokes.removeAll() } }

  /* the Playground can make them feel things on purpose, for a few seconds */
  var demoHotUntil = 0.0, demoSleepUntil = 0.0, demoHungryUntil = 0.0
  /* dancing fades in and out; the beat keeps counting while it fades so they don't freeze mid-move */
  var danceAmt = 0.0, danceBeat = 0.0, danceSure = 0.0, dancePeriod = 0.5
  func step(now t: Double, dt: Double, s s0: Senses, who: Who, attend: Attend) -> FaceLook {
    var s = s0
    if t < demoSleepUntil { s.idle = Brain.awayAfter + 120 }
    if t < demoHotUntil { s.hot = true }
    if t < demoHungryUntil { s.battery = 14; s.charging = false }
    if s.beat != nil { s.idle = max(0, s.idle - 600) }                           /* a song on: they stay up dancing ten minutes longer */
    if s.idle > Brain.awayAfter { asleep = true; away = s.idle }
    else if asleep { asleep = false; startleUntil = t + 0.35; love(t + 0.35); happyUntil = loveAt + Brain.loveFor + min(3, 0.8 + away/1200); cameBack = true }
    drowsy = asleep ? 1 : sm(150, Brain.awayAfter, s.idle)
    let night = s.hour >= 0.5 && s.hour < 5.5 ? 1.0 : 0
    if let b = s.battery, !s.charging { hungry = sm(25, 9, b) } else { hungry = 0 }
    if s.charging && !wasCharging && (s.battery ?? 100) < 35 { happyUntil = t + 4 }
    wasCharging = s.charging
    hot += ((s.hot ? 1 : 0) - hot)*min(1, dt*1.5)
    dizzy = max(0, min(1.7, dizzy + s.shake) - dt*(dizzy > 1 ? 0.45 : 0.22))
    if s.rage { poke(t) }
    let dz = sm(0.55, 0.9, dizzy), startled = t < startleUntil, wince = t < winceUntil, sad = !wince && t < cryUntil
    let heart = heartAmount(t)
    let happy = t < happyUntil && !startled && !sad && heart == 0
    let suspect = t < suspectUntil && !sad && !asleep && heart == 0
    if t > nextBlink { blinkUntil = t + (night > 0 ? 0.3 : 0.13)
      /* she flutters: now and then a second blink right after the first */
      if who == .madam && Double.random(in: 0...1) < 0.35 { flutterAt = blinkUntil + 0.12 }
      nextBlink = t + 1.8 + Double.random(in: 0...4.2) }
    if flutterAt > 0 && t >= flutterAt { blinkUntil = t + 0.11; flutterAt = 0 }
    crying = !asleep && sad          /* low battery makes them sad and droopy, never crying on and on (he saw them cry at 12% without end) */

    var hintAge = -1.0; if case .hint(let since) = attend { hintAge = t - since }
    insisting = hintAge > 60
    var f = FaceLook()
    let far: Bool = { if case .far = attend { return true }; return false }()
    let card: Bool = { if case .card = attend { return true }; return false }()
    let wide = startled || hot > 0.5 || insisting
    /* she darts and keeps glancing about; he moves his eyes only for something worth it, slowly */
    var (K, C, lazy, microEvery, microSize) = who == .madam ? (150.0, 9.0, 0.03, 0.9, 0.05) : (55.0, 7.2, 0.14, 2.6, 0.03)
    if suspect { K = 90; C = 13; lazy = 0; microSize = 0 }                          /* even he keeps his eyes on you now */
    if t > nextMicro { micro = CGPoint(x: CGFloat.random(in: -1...1)*CGFloat(microSize), y: CGFloat.random(in: -1...1)*CGFloat(microSize)*0.7)
      nextMicro = t + microEvery*Double.random(in: 0.6...1.4) }
    let near = 1 - min(1, Double(hypot(s.gaze.x, s.gaze.y)))
    for i in 0..<2 {
      var e = EyeLook()
      e.pupil = wide ? 0.24 : far ? 0.3 : (hungry > 0.3 || sad ? 0.32 : CGFloat(0.37 + 0.17*near) + (who == .madam ? 0.02 : 0))
      e.scale = wide ? 1.05 : 1
      let L = 0.68
      var tx = Double(s.gaze.x)*L, ty = Double(s.gaze.y)*L
      if dz > 0.5 { let a = t*8*(i == 0 ? 1 : -1) + Double(i)*2; tx = cos(a)*L; ty = sin(a)*L }
      else if suspect { let g = max(0.001, Double(hypot(s.gaze.x, s.gaze.y))); tx = Double(s.gaze.x)/g*L*0.92; ty = Double(s.gaze.y)/g*L*0.55 }   /* hard on you, whatever else is on */
      else if far { tx = -L*0.55; ty = -L*0.75 }                                   /* looking out of a window far away */
      else if card { if let d = s.islandDir { tx = Double(d.x)*L; ty = Double(d.y)*L } else { tx = 0; ty = L*0.92 } }   /* reading what they said */
      else if hintAge >= 0 && !insisting { if (hintAge.truncatingRemainder(dividingBy: 2.6)) < 1.2 { if let d = s.islandDir { tx = Double(d.x)*L; ty = Double(d.y)*L } else { tx = 0; ty = L*0.95 } } }   /* psst: glancing down at it */
      else if sad { tx = -tx*0.6; ty = L*0.55 }
      else if hungry > 0.3 && t.truncatingRemainder(dividingBy: 5) < 1.6 { tx = L*0.95; ty = L*0.15 }   /* a worried look across at the battery in the bar */
      else if drowsy > 0.6 || night > 0 && s.idle > 20 { tx *= 0.35; ty = L*0.6 }
      let free = attend.isNone && dz <= 0.5 && !sad && !suspect && !(hungry > 0.3 && t.truncatingRemainder(dividingBy: 5) < 1.6)
      if free { if hypot(CGFloat(tx) - tgt[i].x, CGFloat(ty) - tgt[i].y) > CGFloat(lazy) {
          /* a long look across: people blink on the way */
          if i == 0 && hypot(CGFloat(tx) - tgt[i].x, CGFloat(ty) - tgt[i].y) > 0.6 && t > blinkUntil + 0.6 { blinkUntil = t + 0.12 }
          tgt[i] = CGPoint(x: tx, y: ty) }
        tx = Double(tgt[i].x + micro.x); ty = Double(tgt[i].y + micro.y) } else { tgt[i] = CGPoint(x: tx, y: ty) }
      v[i].x += CGFloat((K*(tx - Double(p[i].x)) - C*Double(v[i].x))*dt); v[i].y += CGFloat((K*(ty - Double(p[i].y)) - C*Double(v[i].y))*dt)
      if s.shake > 0 { v[i].x += CGFloat.random(in: -5...5); v[i].y += CGFloat.random(in: -3...3) }
      p[i].x += v[i].x*CGFloat(dt); p[i].y += v[i].y*CGFloat(dt)
      let d = Double(hypot(p[i].x, p[i].y))
      if d > L { let nx = p[i].x/CGFloat(d), ny = p[i].y/CGFloat(d), vn = v[i].x*nx + v[i].y*ny
        p[i].x = nx*CGFloat(L); p[i].y = ny*CGFloat(L); if vn > 0 { v[i].x -= 1.5*vn*nx; v[i].y -= 1.5*vn*ny } }
      e.px = p[i].x; e.py = p[i].y
      /* lids: he keeps his a little lowered, as a gentleman does; tired at night; sorry when crying or hungry */
      let sorry = sad ? 1 : (hungry > 0.3 ? hungry : 0)
      var upT = max(drowsy*0.78, night*0.4, sorry*0.3, dz*(i == 0 ? 0.16 : 0.05))
      if wide { upT = 0 }
      if suspect { upT = who == .madam ? 0.3 : 0.2 }                             /* narrowed, lids flat, a touch tilted in */
      let angT = suspect ? (i == 0 ? 1 : -1)*0.05 : (i == 0 ? -1 : 1)*sorry*0.42
      let k = min(1, dt*(suspect ? 6 : 14)); up[i] += (upT - up[i])*k; ang[i] += (angT - ang[i])*k
      e.up = CGFloat(up[i]); e.ang = CGFloat(ang[i])
      e.spiral = CGFloat(dz); e.spin = CGFloat(t*7*(i == 0 ? 1 : -1))
      if heart > 0 { e.heart = CGFloat(heart); e.up = who == .gentleman ? -0.55 : -0.25 }   /* even he opens his eyes for this */
      if wince { if t - pokeAt < 0.14 { e.closed = .blink } } else if asleep { e.closed = .sleep } else if happy { e.closed = .joy } else if t < blinkUntil && !wide && heart == 0 && !suspect { e.closed = .blink }
      if i == 0 { f.l = e } else { f.r = e }
    }
    if crying { f.tear = CGFloat((t*0.7).truncatingRemainder(dividingBy: 1)) }
    let pu = t - pokeAt; if pu >= 0 && pu < 0.9 && !crying { f.squash = CGFloat(exp(-6*pu)*cos(14*pu)) }
    /* stars: in love, glad, or just pleased with you */
    if !crying && (heart > 0 || happy || t < sparkleUntil) { f.sparkle = CGFloat(t.truncatingRemainder(dividingBy: 1000)) }
    if hot > 0.5 { f.sweat = CGFloat((t*0.5).truncatingRemainder(dividingBy: 1)) }
    if hungry > 0.3 && !asleep { f.battery = CGFloat((t*0.7).truncatingRemainder(dividingBy: 1)) }
    if asleep { f.zzz = CGFloat(t.truncatingRemainder(dividingBy: 1000)) }
    /* ignored for a minute: they hop up and down to get your attention */
    let lu = t - loveAt; if lu >= 0 && lu < 0.35 { f.hop = -CGFloat(sin(lu/0.35 * .pi))*2.5 }      /* a little jump as the hearts pop */
    if insisting { let ph = t.truncatingRemainder(dividingBy: 2.2); f.hop = ph < 0.8 ? -CGFloat(abs(sin(ph*Double.pi*2.5)))*3 : 0 }
    /* a song is on: they dance, unless something else has their attention */
    let canDance = s.beat != nil && !asleep && drowsy < 0.6 && !sad && !wince && dz <= 0.5 && !suspect && heart == 0 && attend.isNone && !wide
    if let b = s.beat { danceBeat = b; danceSure = s.beatSure; dancePeriod = s.beatLen } else { danceBeat += dt/max(0.25, dancePeriod) }
    danceAmt += ((canDance ? 1 : 0) - danceAmt)*min(1, dt*(canDance ? 2.5 : 4))
    if danceAmt > 0.002 {
      applyDance(&f, beat: danceBeat, sure: danceSure, period: dancePeriod, who: who, amt: danceAmt)
      p[0] = CGPoint(x: f.l.px, y: f.l.py); p[1] = CGPoint(x: f.r.px, y: f.r.py); v = [.zero, .zero] }   /* the gaze eases back to you from where the dance left it */
    return f
  }
  func busy(_ t: Double) -> Bool {
    if danceAmt > 0.002 || dizzy > 0.02 || hot > 0.02 || hungry > 0.02 || crying || insisting || asleep || t < max(demoHotUntil, demoSleepUntil, demoHungryUntil) + 1 { return true }
    if t < max(happyUntil, winceUntil, startleUntil, cryUntil, suspectUntil, loveAt + Brain.loveFor) + 0.3 || t < blinkUntil + 0.15 || flutterAt > 0 { return true }
    return hypot(v[0].x, v[0].y) > 0.05 || hypot(v[1].x, v[1].y) > 0.05 }
}

// MARK: - the island: a black pill that grows out of the menu bar under them

enum Phase { case hidden, hint, open, counting, message, choose, caught, say }

struct IslandLayout { var size: CGSize; var text: CGRect = .zero; var buttons: [CGRect] = []; var faces: [CGRect] = []; var ring: CGRect = .zero; var face: CGRect = .zero }
let CARD_W: CGFloat = 344, PAD: CGFloat = 16, FACE_W: CGFloat = 70

func islandLayout(_ ph: Phase, text: String) -> IslandLayout {
  switch ph {
  case .hidden: return IslandLayout(size: CGSize(width: 86, height: 0))
  case .hint: return IslandLayout(size: CGSize(width: 86, height: 26))
  case .choose:
    let fw: CGFloat = 120
    return IslandLayout(size: CGSize(width: CARD_W, height: 168), text: CGRect(x: PAD, y: 16, width: CARD_W - 2*PAD, height: 24),
                        faces: [CGRect(x: CARD_W/2 - fw - 8, y: 52, width: fw, height: 96), CGRect(x: CARD_W/2 + 8, y: 52, width: fw, height: 96)])
  /* the roommate's own face sits at the left of the card, alive, and talks */
  case .counting:
    let tx = PAD + FACE_W + 12, tw = CARD_W - tx - PAD - 58, th = textHeight(attributed(text, 15, .semibold, .white), width: tw)
    let h = max(th, 46) + 32
    return IslandLayout(size: CGSize(width: CARD_W, height: h), text: CGRect(x: tx, y: (h - th)/2, width: tw, height: th),
                        ring: CGRect(x: CARD_W - PAD - 46, y: (h - 46)/2, width: 46, height: 46), face: CGRect(x: PAD, y: h/2 - 15, width: FACE_W - 4, height: 30))
  case .open, .message:
    let tx = PAD + FACE_W + 12, tw = CARD_W - tx - PAD, th = textHeight(attributed(text, 15, .semibold, .white), width: tw), row = max(th, 40)
    var l = IslandLayout(size: CGSize(width: CARD_W, height: 18 + row + 18), text: CGRect(x: tx, y: 18 + (row - th)/2, width: tw, height: th),
                         face: CGRect(x: PAD, y: 18 + row/2 - 15, width: FACE_W - 4, height: 30))
    if ph == .open { let by = 18 + row + 14; l.size.height = by + 32 + 16
      let bw = (CARD_W - 2*PAD - 10)/2
      l.buttons = [CGRect(x: PAD, y: by, width: bw, height: 32), CGRect(x: PAD + bw + 10, y: by, width: bw, height: 32)] }
    return l
  /* caught: the eyes big in the middle, the line under them */
  case .caught:
    let tw = CARD_W - 2*PAD, th = textHeight(attributed(text, 15, .semibold, .white, center: true), width: tw)
    let fh: CGFloat = 46
    return IslandLayout(size: CGSize(width: CARD_W, height: 14 + fh + 10 + th + 18), text: CGRect(x: PAD, y: 14 + fh + 10, width: tw, height: th),
                        face: CGRect(x: CARD_W/2 - fh*1.2, y: 14, width: fh*2.4, height: fh))
  /* say: a slim pill, their face and one short line, gone by itself */
  case .say:
    let a = attributed(text, 14, .semibold, .white), tw = ceil(a.size().width) + 2, th = ceil(a.size().height), h: CGFloat = 40
    return IslandLayout(size: CGSize(width: 14 + 44 + 10 + tw + 18, height: h), text: CGRect(x: 14 + 44 + 10, y: (h - th)/2, width: tw, height: th),
                        face: CGRect(x: 14, y: (h - 20)/2, width: 44, height: 20))
  }
}

/* caught (you said you'd walk and stayed): wide for a beat, then the lids come down and the lower ones up,
   on a spring, and they follow you; one slow unimpressed blink; at the end they let it go. u: seconds in */
func caughtLook(_ u: Double, gaze: CGPoint, who: Who?) -> FaceLook {
  /* 0-0.9 s: wide, caught you. Then the lids close in from above and below on a spring, one eye more than the other.
     2.6-4.2 s: a slow look down you and back up to your face. 6 s: one slow blink. At the end they let it go. */
  let x = max(0, u - 0.9), sq = CGFloat(1 - exp(-3.6*x)*cos(4.6*x)), rel = CGFloat(sm(CAUGHT_FOR - 0.8, CAUGHT_FOR - 0.1, u)), k = sq*(1 - rel)
  let wide = CGFloat(u < 0.9 ? sin(u/0.9 * .pi) : 0), m = who == .madam
  let over = u > 2.6 && u < 4.2 ? CGFloat(sin((u - 2.6)/1.6 * .pi)) : 0                 /* looking you over */
  var f = FaceLook()
  for kp in [\FaceLook.l, \FaceLook.r] {
    let left = kp == \FaceLook.l
    var e = EyeLook()
    e.px = gaze.x*0.45*(1 - over); e.py = gaze.y*0.3*(1 - over) + 0.55*over
    e.up = ((m ? 0.22 : 0.06) + (left ? 0.06 : 0))*k; e.scale = 1 + 0.07*wide
    e.low = ((left ? 0.25 : 0.2) - 0.06*over)*k
    e.pupil = 0.42 - 0.1*k + 0.08*wide
    f[keyPath: kp] = e }
  if u > 6.0 && u < 6.4 { f.l.closed = .blink; f.r.closed = .blink }
  return f
}
let CAUGHT_FOR = 10.5

/* the island's body: flush with the top, little concave flares where it meets the bar (like the notch's own),
   rounded below. Its body is w wide; the flares stick out f on each side */
func islandShape(w: CGFloat, h: CGFloat, notchH: CGFloat, flare f: CGFloat) -> CGPath {
  let r = notchH > 0 ? min(h/2, 9 + max(0, h - notchH)*0.4, 30) : min(22, h/2)
  let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 0))
  if f > 0 { p.addArc(tangent1End: CGPoint(x: f, y: 0), tangent2End: CGPoint(x: f, y: f), radius: f) } else { p.addLine(to: CGPoint(x: 0, y: 0)) }
  p.addArc(tangent1End: CGPoint(x: f, y: h), tangent2End: CGPoint(x: f + w/2, y: h), radius: r)
  p.addArc(tangent1End: CGPoint(x: f + w, y: h), tangent2End: CGPoint(x: f + w, y: 0), radius: r)
  if f > 0 { p.addArc(tangent1End: CGPoint(x: f + w, y: 0), tangent2End: CGPoint(x: 2*f + w, y: 0), radius: f) } else { p.addLine(to: CGPoint(x: w, y: 0)) }
  p.addLine(to: CGPoint(x: 2*f + w, y: 0)); p.closeSubpath(); return p
}
/* a system symbol, white, centred on c */
func drawSymbol(_ g: CGContext, _ name: String, at c: CGPoint, size: CGFloat, alpha: CGFloat = 1, color: NSColor = .white) {
  guard var img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
  if #available(macOS 12, *) { img = img.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .semibold).applying(.init(paletteColors: [color]))) ?? img }
  let sz = img.size, r = CGRect(x: c.x - sz.width/2, y: c.y - sz.height/2, width: sz.width, height: sz.height)
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: true)
  img.draw(in: r, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: nil)
  NSGraphicsContext.restoreGraphicsState()
}
func symbolName(_ k: Kind?) -> String { switch k { case .move: return "figure.walk"; case .late: return "moon.zzz.fill"; case .hello: return "hand.wave.fill"; default: return "eye.fill" } }
let EAR: CGFloat = 40

/* drawn the same in the menu bar and in --render. size is the body (without the flares); notch is the camera
   cut-out it grows from (zero on a screen without one: then it hangs under the eyes as before) */
func paintIsland(_ g: CGContext, size: CGSize, phase ph: Phase, text: String, buttons: [String], who: Who?, alpha: CGFloat, t: Double, left: Double, hover: Int,
                 notch: CGSize = .zero, kind: Kind? = nil, look: FaceLook? = nil, burst: Double = -1, age: Double = 99, gaze: CGPoint = .zero, faceScale: CGFloat = 1) {
  /* the face pops into the card on a spring (it has just teleported out of the menu bar) */
  func popped(_ r: CGRect, _ draw: () -> Void) { guard faceScale > 0.01 else { return }
    g.saveGState(); g.translateBy(x: r.midX, y: r.midY); g.scaleBy(x: faceScale, y: faceScale); g.translateBy(x: -r.midX, y: -r.midY); draw(); g.restoreGState() }
  let w = size.width, h = size.height, f: CGFloat = notch.width > 0 ? 6 : 0
  guard h > 1 else { return }
  let outline = islandShape(w: w, h: h, notchH: notch.height, flare: f)
  /* as a card arrives: a soft glow in their colour around it, and a rim of light running once round its edge */
  if (ph == .open || ph == .caught || ph == .say) && age < 1.7 {
    let a = CGFloat(sin(min(1, age/1.7) * .pi))
    g.saveGState(); g.setShadow(offset: .zero, blur: 24, color: accent(who).copy(alpha: 0.95*a)!); g.addPath(outline); g.setFillColor(rgb(0, 0, 0)); g.fillPath(); g.restoreGState()
    g.saveGState(); g.addPath(outline); g.setLineWidth(2.8); g.replacePathWithStrokedPath(); g.clip()
    let cols = [accent(who), FX_HEART, FX_TEAR, rgb(1, 1, 1), accent(who)].map { $0.copy(alpha: a)! }
    if let gr = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols as CFArray, locations: [0, 0.25, 0.5, 0.75, 1]) {
      /* a band of light sweeping round: a linear gradient whose direction turns with time */
      let c = CGPoint(x: f + w/2, y: h*0.6), ang = CGFloat(age)*4.2, rr = max(w, h)*0.6, d = CGPoint(x: cos(ang)*rr, y: sin(ang)*rr)
      g.drawLinearGradient(gr, start: CGPoint(x: c.x - d.x, y: c.y - d.y), end: CGPoint(x: c.x + d.x, y: c.y + d.y), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]) }
    g.restoreGState() }
  g.addPath(outline); g.setFillColor(rgb(0, 0, 0)); g.fillPath()
  guard alpha > 0.01 else { return }
  let L = islandLayout(ph, text: text)
  g.saveGState(); g.setAlpha(alpha)
  if notch.width > 0 && ph == .hint {
    /* compact: the roommate's tiny face in the left ear, what it is about in the right, breathing */
    var look = FaceLook(); look.l.px = 0.34; look.r.px = 0.34; look.l.py = 0.12; look.r.py = 0.12
    let fh: CGFloat = 15, lx = f + EAR/2 + 2
    drawFace(g, in: CGRect(x: lx - fh*1.11, y: h/2 - fh/2, width: fh*2.22, height: fh), look: look, who: who, ink: rgb(1, 1, 1), dark: true)
    let beat = CGFloat(1 + 0.1*max(0, sin(t*3.4)))
    drawSymbol(g, symbolName(kind), at: CGPoint(x: f + w - EAR/2 - 3, y: h/2), size: 13*beat, color: NSColor(cgColor: accent(who)) ?? .white)
    g.restoreGState(); return
  }
  /* the card sits under the notch, centred */
  g.translateBy(x: f + (w - L.size.width)/2, y: notch.height)
  if ph == .caught {
    /* the eyes in full, round and matte, big enough to see them narrow */
    popped(L.face) { drawFace(g, in: L.face, look: caughtLook(age, gaze: gaze, who: who), who: who, ink: rgb(1, 1, 1), dark: true) }
    drawText(g, revealed(text, 15, .semibold, .white, center: true, age: age, from: 1.5), in: L.text)
    g.restoreGState(); return
  }
  if L.face.width > 0 {
    var fl = look ?? FaceLook(); fl.hop = 0
    for k in [\FaceLook.l, \FaceLook.r] where fl[keyPath: k].closed == nil && fl[keyPath: k].heart < 0.02 && fl[keyPath: k].spiral < 0.5 {
      if ph == .counting { fl[keyPath: k].px = -0.48; fl[keyPath: k].py = -0.46 } else { fl[keyPath: k].px = 0.42; fl[keyPath: k].py = 0.12 } }
    popped(L.face) { drawFace(g, in: L.face, look: fl, who: who, ink: rgb(1, 1, 1), dark: true) }
    drawBurst(g, at: CGPoint(x: L.face.midX, y: L.face.midY), radius: 40, size: 7, u: burst) }
  switch ph {
  case .hint:
    /* three dots, breathing in their colour */
    for k in 0..<3 { let ph = t*3.2 - Double(k)*0.5, s = CGFloat(0.6 + 0.4*max(0, sin(ph)))
      let r = 3.2*s, x = L.size.width/2 + CGFloat(k - 1)*11
      g.setFillColor(accent(who)); g.fillEllipse(in: CGRect(x: x - r, y: L.size.height/2 - r, width: 2*r, height: 2*r)) }
  case .open, .message:
    drawText(g, revealed(text, 15, .semibold, .white, age: age, from: 0.18), in: L.text)
    for (k, r0) in L.buttons.enumerated() where k < buttons.count {
      /* the buttons come up one after the other, once the words are under way */
      let ba = CGFloat(max(0, min(1, (age - 0.4 - Double(k)*0.07)/0.22))), r = r0.offsetBy(dx: 0, dy: (1 - ba)*6)
      g.saveGState(); g.setAlpha(alpha*ba); defer { g.restoreGState() }
      let primary = k == 0
      g.addPath(CGPath(roundedRect: r, cornerWidth: 16, cornerHeight: 16, transform: nil))
      g.setFillColor(primary ? (hover == k ? rgb(0.86, 0.87, 0.9) : rgb(1, 1, 1)) : (hover == k ? rgb(0.25, 0.26, 0.3) : rgb(0.17, 0.18, 0.21))); g.fillPath()
      let a = attributed(buttons[k], 14, .bold, primary ? .black : .white, center: true)
      let th = textHeight(a, width: r.width); drawText(g, a, in: CGRect(x: r.minX, y: r.midY - th/2, width: r.width, height: th)) }
  case .counting:
    drawText(g, revealed(text, 15, .semibold, .white, age: age, from: 0.05), in: L.text)
    let c = CGPoint(x: L.ring.midX, y: L.ring.midY), R = L.ring.width/2 - 3
    g.setLineWidth(4); g.setLineCap(.round)
    g.setStrokeColor(rgb(1, 1, 1, 0.14)); g.strokeEllipse(in: CGRect(x: c.x - R, y: c.y - R, width: 2*R, height: 2*R))
    let frac = CGFloat(max(0, min(1, left/20)))
    g.setStrokeColor(accent(who)); g.beginPath(); g.addArc(center: c, radius: R, startAngle: -.pi/2, endAngle: -.pi/2 + .pi*2*frac, clockwise: false); g.strokePath()
    let a = attributed("\(Int(ceil(left)))", 16, .heavy, .white, center: true), th = textHeight(a, width: L.ring.width)
    drawText(g, a, in: CGRect(x: L.ring.minX, y: c.y - th/2, width: L.ring.width, height: th))
  case .choose:
    drawText(g, attributed("Who's moving in?", 16, .bold, .white, center: true), in: L.text)
    for (k, fr) in L.faces.enumerated() {
      let wh: Who = k == 0 ? .madam : .gentleman
      g.addPath(CGPath(roundedRect: fr, cornerWidth: 16, cornerHeight: 16, transform: nil))
      g.setFillColor(hover == k ? rgb(0.22, 0.23, 0.27) : rgb(0.13, 0.135, 0.16)); g.fillPath()
      var look = FaceLook(); let toward: CGFloat = k == 0 ? 0.35 : -0.35
      look.l.px = toward; look.r.px = toward; look.l.py = 0.05; look.r.py = 0.05; 
      drawFace(g, in: CGRect(x: fr.minX + 16, y: fr.minY + 14, width: fr.width - 32, height: 40), look: look, who: wh, ink: rgb(1, 1, 1), dark: true)
      let a = attributed(k == 0 ? "Madam" : "Gentleman", 14, .bold, .white, center: true)
      drawText(g, a, in: CGRect(x: fr.minX, y: fr.maxY - 30, width: fr.width, height: 20)) }
  case .say:
    drawText(g, revealed(text, 14, .semibold, .white, age: age, from: 0.12), in: L.text)
  case .hidden, .caught: break
  }
  g.restoreGState()
}

final class IslandView: NSView {
  weak var island: Island?
  override var isFlipped: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func draw(_ dirtyRect: NSRect) {
    guard let g = NSGraphicsContext.current?.cgContext, let i = island else { return }
    g.clear(bounds); g.translateBy(x: i.origin.x, y: i.origin.y)
    let now = CACurrentMediaTime()
    paintIsland(g, size: i.size, phase: i.phase, text: i.card?.text ?? i.note, buttons: i.card?.buttons ?? [], who: i.who,
                alpha: i.alpha, t: now, left: i.left, hover: i.hover, notch: i.base, kind: i.kind, look: i.look, burst: now - i.burstAt,
                age: now - i.since, gaze: i.phase == .caught ? i.gazeAtPointer() : .zero, faceScale: i.faceScale(now)) }
  override func updateTrackingAreas() { super.updateTrackingAreas(); trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self)) }
  override func mouseMoved(with e: NSEvent) { island?.hoverAt(convert(e.locationInWindow, from: nil)) }
  override func mouseExited(with e: NSEvent) { island?.hover = -1; needsDisplay = true }
  override func mouseDown(with e: NSEvent) { island?.click(convert(e.locationInWindow, from: nil)) }
}

final class IslandDriver: NSObject {
  weak var island: Island?; var link: AnyObject?; var timer: Timer?; var last = CACurrentMediaTime()
  init(_ i: Island) { island = i; super.init()
    if #available(macOS 14, *) { let l = i.view.displayLink(target: self, selector: #selector(fire)); l.add(to: .main, forMode: .common); link = l }
    else { let t = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in self?.fire() }; t.tolerance = 0; RunLoop.main.add(t, forMode: .common); timer = t } }
  var frames = 0
  @objc func fire() { let now = CACurrentMediaTime(), dt = min(0.05, max(0.001, now - last)); last = now; frames += 1
    if LOG && frames % 60 == 1, let i = island { FileHandle.standardError.write("island frame \(frames) size \(Int(i.size.width))x\(Int(i.size.height)) dt \(String(format: "%.4f", dt))\n".data(using: .utf8)!) }
    island?.step(now: now, dt: dt) }
  func stop() { if #available(macOS 14, *) { (link as? CADisplayLink)?.invalidate() }; timer?.invalidate(); link = nil; timer = nil }
}

/* The island. On a Mac with a notch it lives in the notch: at rest it is the notch itself, a nudge grows ears
   either side of it, a click springs it open into a card below. On a screen without one it hangs under the eyes. */
final class Island {
  let panel: NSPanel, view = IslandView()
  var phase = Phase.hidden, card: Card? = nil, note = "", who: Who? = nil, kind: Kind? = nil
  var look = FaceLook(), burstAt = -100.0
  /* 0.8 teleport: the phases that carry their face; when it arrived (it pops in 0.15 s after the bar eyes start to go) and when it left */
  static let faceful: Set<Phase> = [.open, .counting, .message, .caught, .say]
  var arrivedAt = -100.0, leftAt = -100.0, touched = true
  var hasFace: Bool { Island.faceful.contains(phase) }
  func faceScale(_ now: Double) -> CGFloat { let u = now - arrivedAt - 0.1
    if u <= 0 { return 0 }; if u >= 0.6 { return 1 }; return CGFloat(1 - exp(-9*u)*cos(12*u)) }
  func burst(_ now: Double) { burstAt = now }
  var size = CGSize(width: 86, height: 0), vel = CGSize.zero, alpha: CGFloat = 0, hover = -1
  var since = 0.0, countEnd = 0.0, messageEnd = 0.0
  var left: Double { max(0, countEnd - CACurrentMediaTime()) }
  var onOpen: (() -> Void)?, onButton: ((Int) -> Void)?, onChoose: ((Who) -> Void)?, onCounted: (() -> Void)?
  var anchorX: CGFloat = 0, anchorTop: CGFloat = 0
  /* the notch it grows from, in screen coordinates; zero size where there is none */
  var notch = CGRect.zero
  var base: CGSize { notch.size }
  var flare: CGFloat { notch.width > 0 ? 6 : 0 }

  /* the window never changes size (resizing a window every frame is what made it jerk): only the shape inside moves */
  static let stage = CGSize(width: 460, height: 330)
  var driver: IslandDriver?
  init() {
    panel = NSPanel(contentRect: NSRect(origin: .zero, size: Island.stage), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.colorSpace = .sRGB
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)     /* over the menu bar, where the notch is */
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]; panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false; panel.becomesKeyOnlyIfNeeded = true
    panel.contentView = view; view.island = self
    view.wantsLayer = true; view.layerContentsRedrawPolicy = .onSetNeedsDisplay; view.layer?.contentsFormat = .RGBA8Uint
  }
  /* where the stage sits on the screen, and where the shape's top left is inside it (y down) */
  var stageFrame: NSRect {
    let S = Island.stage
    if notch.width > 0 { return NSRect(x: notch.midX - S.width/2, y: notch.maxY - S.height, width: S.width, height: S.height) }
    let scr = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchorX, y: anchorTop - 1)) } ?? NSScreen.main
    var x = anchorX - S.width/2
    if let fr = scr?.frame { x = max(fr.minX, min(fr.maxX - S.width, x)) }
    return NSRect(x: x, y: anchorTop - S.height, width: S.width, height: S.height)
  }
  var origin: CGPoint {
    let W = size.width + 2*flare
    if notch.width > 0 { return CGPoint(x: (Island.stage.width - W)/2, y: 0) }
    let x = anchorX - stageFrame.minX - W/2
    return CGPoint(x: max(6, min(Island.stage.width - W - 6, x)), y: 0)
  }
  var showing: Bool { phase != .hidden }
  var layout: IslandLayout { islandLayout(phase, text: card?.text ?? note) }
  var rest: CGSize { notch.width > 0 ? base : CGSize(width: 86, height: 0) }
  var target: CGSize {
    guard notch.width > 0 else { return phase == .hidden ? rest : layout.size }
    switch phase {
    case .hidden: return base
    case .hint: return CGSize(width: base.width + 2*EAR, height: base.height)
    default: let l = layout.size; return CGSize(width: max(l.width, base.width + 2*EAR), height: base.height + l.height)
    }
  }
  var settled: Bool { let t = target; return abs(size.width - t.width) < 1 && abs(size.height - t.height) < 1 && abs(vel.width) < 8 && abs(vel.height) < 8 }
  var animating: Bool { !settled || (phase != .hidden && alpha < 0.99) || phase == .hint || phase == .counting || phase == .caught || phase == .say }
  func go(_ p: Phase, card c: Card? = nil, note n: String = "", now: Double) {
    if LOG { FileHandle.standardError.write("island \(p) \(c.map { "\($0.kind)" } ?? "") notch \(notch)\n".data(using: .utf8)!) }
    if phase == .hidden && !panel.isVisible { size = rest; vel = .zero }       /* it always grows out of the notch */
    /* on screen first: a display link only ticks for a window that is shown */
    if p != .hidden && !panel.isVisible { panel.setFrame(stageFrame, display: false); panel.ignoresMouseEvents = true; panel.orderFrontRegardless() }
    if p != .hidden && driver == nil { driver = IslandDriver(self) }
    let had = hasFace
    phase = p; if let c = c { card = c } else if p != .open && p != .hint { card = nil }
    if hasFace && !had { arrivedAt = now
      /* a light tap on the trackpad as a card opens out of the notch (felt only with a finger on it) */
      if p == .open || p == .caught { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) } }
    if p == .open || p == .caught { touched = false }
    if had && !hasFace { leftAt = now }
    note = n; since = now; alpha = 0; hover = -1
    if p == .counting { countEnd = now + 20; card = nil }
    if p == .message { messageEnd = now + 3.2 }
    if p == .caught { messageEnd = now + CAUGHT_FOR }
    if p == .say { messageEnd = now + 3 }
  }
  func place(x: CGFloat, top: CGFloat, notch n: CGRect?) {
    anchorX = x; anchorTop = top
    /* the notch is only swapped while nothing shows, so the island never jumps */
    if phase == .hidden && !panel.isVisible { notch = n ?? .zero }
  }
  func step(now: Double, dt: Double) {
    /* a spring, a touch under-damped: it overshoots a little and settles, like the real one */
    /* a liquid spring: opening, the height leads and bounces a touch; closing, the width pulls in first */
    let tg = target, opening = tg.height > size.height, n = 4, h = CGFloat(dt)/CGFloat(n)
    let kw: CGFloat = opening ? 200 : 260, cw: CGFloat = opening ? 24 : 26, kh: CGFloat = opening ? 270 : 220, ch: CGFloat = opening ? 19 : 24
    for _ in 0..<n {
      vel.width += (kw*(tg.width - size.width) - cw*vel.width)*h; size.width += vel.width*h
      vel.height += (kh*(tg.height - size.height) - ch*vel.height)*h; size.height += vel.height*h }
    /* the words come once the shape is nearly there, and go first */
    let near = abs(size.height - tg.height) < max(4, tg.height*0.12) && abs(size.width - tg.width) < max(4, tg.width*0.12)
    alpha = near && phase != .hidden ? min(1, alpha + CGFloat(dt)*7) : max(0, alpha - CGFloat(dt)*14)
    if phase == .counting && now >= countEnd { onCounted?() }
    if (phase == .message || phase == .caught || phase == .say) && now >= messageEnd { go(.hidden, now: now) }
    if phase == .hidden && settled { if panel.isVisible { panel.orderOut(nil) }; driver?.stop(); driver = nil; return }
    let frame = stageFrame
    if panel.frame != frame { panel.setFrame(frame, display: false) }
    if !panel.isVisible { panel.orderFrontRegardless() }
    /* clicks fall through everywhere but the shape itself */
    let o = origin, m = NSEvent.mouseLocation
    let shape = NSRect(x: frame.minX + o.x, y: frame.maxY - o.y - size.height, width: size.width + 2*flare, height: max(1, size.height))
    let inside = shape.contains(m) && phase != .hidden && phase != .say      /* a passing remark never catches a click */
    /* macOS plays a tap only with a finger on the trackpad: the moment the pointer first comes onto the card, it surely is */
    if inside && !touched && (phase == .open || phase == .caught) { touched = true; NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
    if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
    view.needsDisplay = true
  }
  /* which way the pointer is from the card's face, y down, longer the farther it is */
  func gazeAtPointer() -> CGPoint {
    let L = layout, o = origin, fr = stageFrame, m = NSEvent.mouseLocation
    let c = CGPoint(x: fr.minX + o.x + flare + (size.width - L.size.width)/2 + L.face.midX, y: fr.maxY - o.y - base.height - L.face.midY)
    let dx = m.x - c.x, dy = c.y - m.y, d = max(1, hypot(dx, dy)), k = min(1, d/260)
    return CGPoint(x: dx/d*k, y: dy/d*k) }
  /* where the island's centre is, on the screen (y up) */
  var center: CGPoint { notch.width > 0 ? CGPoint(x: notch.midX, y: notch.maxY - max(size.height, base.height)/2) : CGPoint(x: anchorX, y: anchorTop - size.height/2) }
  /* points in the view, moved into the card's own frame */
  func local(_ p: NSPoint) -> NSPoint { let o = origin; return NSPoint(x: p.x - o.x - flare - (size.width - layout.size.width)/2, y: p.y - o.y - base.height) }
  func hoverAt(_ p: NSPoint) {
    let L = layout, q = local(p)
    let rects = phase == .choose ? L.faces : L.buttons
    let h = rects.firstIndex { $0.contains(q) } ?? -1
    if h != hover { hover = h; view.needsDisplay = true }
  }
  func click(_ p: NSPoint) {
    let L = layout, q = local(p)
    switch phase {
    case .hint: onOpen?()
    case .open: if let i = L.buttons.firstIndex(where: { $0.contains(q) }) { onButton?(i) }
    case .choose: if let i = L.faces.firstIndex(where: { $0.contains(q) }) { onChoose?(i == 0 ? .madam : .gentleman) }
    case .caught: go(.hidden, now: CACurrentMediaTime())
    default: break
    }
  }
}

// MARK: - checks from the command line

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
  /* both of them in every state, in the menu bar on a light and a dark bar, and the island in each phase */
  var states: [(String, FaceLook)] = []
  func f(_ m: (inout FaceLook) -> Void) -> FaceLook { var x = FaceLook(); m(&x); return x }
  states.append(("calm", FaceLook()))
  states.append(("psst", f { $0.l.px = 0; $0.r.px = 0; $0.l.py = 0.5; $0.r.py = 0.5 }))
  states.append(("far away", f { for k in [\FaceLook.l, \FaceLook.r] { $0[keyPath: k].px = -0.38; $0[keyPath: k].py = -0.5; $0[keyPath: k].pupil = 0.27 } }))
  states.append(("blink", f { $0.l.closed = .blink; $0.r.closed = .blink }))
  states.append(("glad", f { $0.l.closed = .joy; $0.r.closed = .joy }))
  states.append(("asleep", f { $0.l.closed = .sleep; $0.r.closed = .sleep }))
  states.append(("ow", f { $0.squash = 1 }))
  states.append(("crying", f { for k in [\FaceLook.l, \FaceLook.r] { $0[keyPath: k].up = 0.36; $0[keyPath: k].pupil = 0.33; $0[keyPath: k].px = 0; $0[keyPath: k].py = 0.35 }; $0.l.ang = -0.42; $0.r.ang = 0.42; $0.tear = 0.6 }))
  states.append(("dizzy", f { $0.l.spiral = 1; $0.r.spiral = 1; $0.r.spin = 2 }))
  states.append(("love", f { $0.l.heart = 1.15; $0.r.heart = 1.15; $0.l.up = -0.55; $0.r.up = -0.55 }))
  states.append(("sweating", f { for k in [\FaceLook.l, \FaceLook.r] { $0[keyPath: k].pupil = 0.24; $0[keyPath: k].px = 0; $0[keyPath: k].py = 0 }; $0.sweat = 0.4 }))
  let cw: CGFloat = 132, rowH: CGFloat = 190
  let islands: [(Phase, Who, String, [String], Double)] = [
    (.hint, .madam, "", [], 0), (.open, .madam, Lines.card(.eyes, .madam).text, ["Okay", "Later"], 0),
    (.counting, .gentleman, Lines.counting(.gentleman), [], 13), (.open, .gentleman, Lines.card(.move, .gentleman).text, ["Going", "Later"], 0),
    (.choose, .madam, "", [], 0)]
  let iw: CGFloat = CARD_W + 30
  let size = CGSize(width: max(cw*CGFloat(states.count), iw*CGFloat(islands.count)) + 20, height: rowH*2 + 260)
  let img = bitmap(size) { g in
    g.setFillColor(rgb(0.93, 0.93, 0.94)); g.fill(CGRect(origin: .zero, size: size))
    for (row, who) in [Who.madam, .gentleman].enumerated() {
      let y0 = CGFloat(row)*rowH
      g.setFillColor(rgb(0.16, 0.17, 0.2)); g.fill(CGRect(x: 0, y: y0 + 140, width: size.width, height: 40))
      for (k, s) in states.enumerated() { let x = 10 + cw*CGFloat(k)
        drawText(g, attributed(s.0, 13, .bold, .black, center: true), in: CGRect(x: x, y: y0 + 8, width: cw, height: 18))
        drawFace(g, in: CGRect(x: x + 14, y: y0 + 34, width: cw - 28, height: 56), look: s.1, who: who)
        drawFace(g, in: CGRect(x: x + cw/2 - 18, y: y0 + 108, width: 36, height: 16), look: s.1, who: who)
        drawFace(g, in: CGRect(x: x + cw/2 - 18, y: y0 + 152, width: 36, height: 16), look: s.1, who: who, ink: rgb(1, 1, 1), dark: true) } }
    for (k, s) in islands.enumerated() {
      let L = islandLayout(s.0, text: s.2), x = 10 + iw*CGFloat(k), y = rowH*2 + 20
      g.setFillColor(rgb(0.86, 0.87, 0.9)); g.fill(CGRect(x: x - 6, y: y - 12, width: iw - 18, height: 12))
      g.saveGState(); g.translateBy(x: x + (iw - 30 - L.size.width)/2, y: y)
      paintIsland(g, size: L.size, phase: s.0, text: s.2, buttons: s.3, who: s.1, alpha: 1, t: 0.4, left: s.4, hover: -1); g.restoreGState() }
  }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
if args.contains("--bench") {
  /* how long one face takes to draw, small and big, dark and light */
  var f = FaceLook(); f.l.px = 0.3; f.r.px = 0.3
  for (h, dark) in [(CGFloat(16), true), (16, false), (92, true), (92, false)] {
    let t0 = CACurrentMediaTime(), n = 200
    _ = bitmap(CGSize(width: h*2.4, height: h*1.4)) { g in for _ in 0..<n { drawFace(g, in: CGRect(x: 2, y: 2, width: h*2.22, height: h), look: f, who: .madam, ink: rgb(1, 1, 1), dark: dark) } }
    print(h, dark ? "dark" : "light", String(format: "%.2f ms", (CACurrentMediaTime() - t0)*1000/Double(n))) }
  exit(0)
}
if let i = args.firstIndex(of: "--og"), i + 1 < args.count {
  /* the picture a shared link shows: both roommates, big, on the night of a screen, and the name */
  let W: CGFloat = 1200, H: CGFloat = 630
  let img = bitmap(CGSize(width: W, height: H), scale: 1) { g in
    linearL(g, [hex("#2a2f55"), hex("#151726")], [0, 1], from: .zero, to: CGPoint(x: 0, y: H))
    radial(g, [rgb(0.47, 0.39, 0.9, 0.35), rgb(0.47, 0.39, 0.9, 0)], [0, 1], from: CGPoint(x: W*0.7, y: H), 10, to: CGPoint(x: W*0.7, y: H), W*0.7)
    var m = FaceLook(); m.l.px = 0.3; m.r.px = 0.3; m.l.py = 0.12; m.r.py = 0.12
    var gl = FaceLook(); gl.l.px = -0.3; gl.r.px = -0.3; gl.l.py = 0.12; gl.r.py = 0.12
    drawFace(g, in: CGRect(x: 120, y: 150, width: 420, height: 190), look: m, who: .madam, ink: rgb(1, 1, 1), dark: true)
    drawFace(g, in: CGRect(x: 660, y: 150, width: 420, height: 190), look: gl, who: .gentleman, ink: rgb(1, 1, 1), dark: true)
    drawText(g, attributed("Roomie lives in your menu bar.", 54, .heavy, .white, center: true), in: CGRect(x: 0, y: 420, width: W, height: 70))
    drawText(g, attributed("Madam or the Gentleman. Free, for your Mac.", 28, .semibold, NSColor(white: 1, alpha: 0.7), center: true), in: CGRect(x: 0, y: 500, width: W, height: 40)) }
  writePNG(img, args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--dancefilm"), i + 1 < args.count {
  /* a vertical film for Reels: the menu bar, a song starts, they dance, the camera comes close, an end card.
     The music is made here too, at 112 bpm, so every hit lands on its beat. Usage: Roomie --dancefilm out.mp4 [madam|gentleman] */
  let who: Who = args.count > i + 2 && args[i + 2] == "gentleman" ? .gentleman : .madam
  let PW = 1080, PH = 1920, FPS = 30.0, S: CGFloat = 2.5, SW = CGFloat(PW)/S, FH = CGFloat(PH)/S
  let Y0: CGFloat = (FH*0.2).rounded(), SH = FH - Y0
  let notch = CGSize(width: 208, height: 37.5), NX = SW/2, HOME = CGPoint(x: NX + 104 + 34, y: notch.height/2)
  let BPM = 112.0, P = 60/BPM, tm0 = 0.75, startBeat = 8.0, lastBeat = 31.6, tEnd = tm0 + (lastBeat - startBeat)*P, DUR = tEnd + 3.2
  func e3(_ u: Double) -> CGFloat { let k = max(0, min(1, u)); return CGFloat(k < 0.5 ? 4*k*k*k : 1 - pow(-2*k + 2, 3)/2) }
  func popIn(_ u: Double) -> CGFloat { u <= 0 ? 0 : u >= 0.6 ? 1 : CGFloat(1 - exp(-9*u)*cos(12*u)) }
  let base = FileManager.default.temporaryDirectory.appendingPathComponent("roomie-dancefilm-\(getpid())")
  try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
  let vURL = base.appendingPathComponent("v.mp4"), aURL = base.appendingPathComponent("a.caf"), out = URL(fileURLWithPath: args[i + 1])

  /* ---- the music: four on the floor, a clap on 2 and 4, hats, a disco bass, chord stabs, and a little hook in A minor ---- */
  let SR = 44100.0, total = Int(DUR*SR); var ML = [Float](repeating: 0, count: total), MR = ML
  var seed: UInt64 = 0x9e3779b97f4a7c15
  func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11)/Double(1 << 53)*2 - 1 }
  func put(_ t0: Double, _ dur: Double, pan: Double = 0, _ f: (Double) -> Double) {
    let i0 = Int(t0*SR), n = Int(dur*SR), gl = Float(1 - max(0, pan)), gr = Float(1 + min(0, pan))
    for k in 0..<n { let j = i0 + k; if j < 0 || j >= total { continue }; let v = Float(f(Double(k)/SR)); ML[j] += v*gl; MR[j] += v*gr } }
  func kick(_ t: Double) { put(t, 0.42) { u in 0.95*exp(-u*8)*sin(2*Double.pi*(46*u + 120/30*(1 - exp(-30*u)))) } }
  func clap(_ t: Double) { var hp = 0.0, prev = 0.0
    put(t, 0.22) { u in let x = rnd(); hp = 0.85*(hp + x - prev); prev = x
      let env = exp(-u*22) + 0.5*(u < 0.012 ? 1 : 0) + 0.35*(u > 0.018 && u < 0.03 ? 1 : 0); return 0.42*hp*env + 0.12*sin(2*Double.pi*190*u)*exp(-u*30) } }
  func hat(_ t: Double, open: Bool, pan: Double) { var hp = 0.0, prev = 0.0
    put(t, open ? 0.25 : 0.05, pan: pan) { u in let x = rnd(); hp = 0.6*(hp + x - prev); prev = x; return (open ? 0.13 : 0.08)*hp*exp(-u*(open ? 11 : 70)) } }
  func tone(_ t: Double, _ f0: Double, _ dur: Double, _ amp: Double, harm: Int, decay: Double, bright: Double, pan: Double = 0, vib: Double = 0) {
    put(t, dur, pan: pan) { u in var v = 0.0
      let att = min(1, u/0.006), rel = min(1, (dur - u)/0.03), f = f0*(1 + vib*0.006*sin(2*Double.pi*5.5*u))
      for h in 1...harm { v += sin(2*Double.pi*f*Double(h)*u)/Double(h)*exp(-u*bright*Double(h - 1)) }
      return amp*v*exp(-u*decay)*att*rel } }
  let roots = [55.0, 43.65, 65.41, 49.0]                                       /* Am F C G */
  let chords = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
  /* the hook, in eighths over four bars (0 = rest): A minor pentatonic */
  let hook: [[Double]] = [[659.3, 0, 523.3, 587.3, 659.3, 0, 784.0, 659.3], [587.3, 0, 523.3, 440.0, 523.3, 0, 0, 0],
                          [659.3, 0, 523.3, 587.3, 659.3, 0, 784.0, 880.0], [784.0, 0, 659.3, 0, 587.3, 0, 523.3, 0]]
  let beats = Int((DUR - tm0)/P) + 1
  for k in 0..<beats {
    let t = tm0 + Double(k)*P, bar = k/4, inBar = k % 4, ch = bar % 4
    if t > DUR - 0.6 { break }
    kick(t); if inBar == 1 || inBar == 3 { clap(t) }
    hat(t + P/2, open: true, pan: 0.25); hat(t, open: false, pan: -0.2); hat(t + P/4, open: false, pan: -0.2); hat(t + 3*P/4, open: false, pan: -0.2)
    /* disco bass: root on the beat, octave on the "and" */
    tone(t, roots[ch], P*0.45, 0.32, harm: 6, decay: 5, bright: 0.9); tone(t + P/2, roots[ch]*2, P*0.4, 0.26, harm: 5, decay: 6, bright: 1.1)
    if inBar == 1 || inBar == 3 { for (n, f) in chords[ch].enumerated() { tone(t + P/2, f, 0.34, 0.07, harm: 5, decay: 7, bright: 1.6, pan: Double(n - 1)*0.4) } }
    if bar >= 2 { let line = hook[(bar - 2) % 4]
      for e in 0..<2 { let f = line[inBar*2 + e]; if f > 0 { tone(t + Double(e)*P/2, f, P*0.48, 0.09, harm: 3, decay: 3, bright: 0.8, pan: 0.1, vib: 1) } } }
  }
  /* fade out, then a soft limiter */
  let fadeAt = DUR - 1.4
  for j in 0..<total { let t = Double(j)/SR, g = Float(t > fadeAt ? max(0, 1 - (t - fadeAt)/1.2) : 1)
    ML[j] = tanhf(ML[j]*0.9)*0.88*g; MR[j] = tanhf(MR[j]*0.9)*0.88*g }
  let fmt = AVAudioFormat(standardFormatWithSampleRate: SR, channels: 2)!, buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(total))!
  buf.frameLength = AVAudioFrameCount(total)
  for j in 0..<total { buf.floatChannelData![0][j] = ML[j]; buf.floatChannelData![1][j] = MR[j] }
  try? FileManager.default.removeItem(at: aURL)
  do { let af = try AVAudioFile(forWriting: aURL, settings: fmt.settings); try af.write(from: buf) } catch { print("audio:", error); exit(1) }

  /* ---- the pictures ---- */
  try? FileManager.default.removeItem(at: vURL)
  let writer = try! AVAssetWriter(outputURL: vURL, fileType: .mp4)
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: PW, AVVideoHeightKey: PH,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000, AVVideoMaxKeyFrameIntervalKey: 30, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
  input.expectsMediaDataInRealTime = false
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: PW, kCVPixelBufferHeightKey as String: PH])
  writer.add(input); guard writer.startWriting() else { print("could not start writing:", String(describing: writer.error)); exit(1) }
  writer.startSession(atSourceTime: .zero)
  let frames = Int(DUR*FPS), zoomFrom = 1.7, zoomTo = 3.4, Z: CGFloat = 8.2, C = CGPoint(x: SW/2, y: SH*0.46)
  for f in 0..<frames {
    let t = Double(f)/FPS
    /* the look: idle with a blink, a little start when the song begins, then the dance fading in over a beat */
    var look = FaceLook(); look.l.px = 0.15; look.r.px = 0.15; look.l.py = 0.12; look.r.py = 0.12
    if t > 0.35 && t < 0.48 { look.l.closed = .blink; look.r.closed = .blink }
    let su = t - tm0
    if su >= 0 && su < 0.3 { look.l.scale = 1.05; look.r.scale = 1.05; look.l.pupil = 0.26; look.r.pupil = 0.26; look.hop = -CGFloat(sin(su/0.3*Double.pi))*2 }
    if su >= 0.15 { let amt = Double(min(1, (su - 0.15)/(P*1.2))); applyDance(&look, beat: startBeat + su/P, sure: 1, period: P, who: who, amt: amt) }
    while !input.isReadyForMoreMediaData { usleep(2000) }
    var pbo: CVPixelBuffer?
    if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbo) }
    else { CVPixelBufferCreate(nil, PW, PH, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pbo) }
    guard let pb = pbo else { print("no pixel buffer at frame", f); exit(1) }
    CVPixelBufferLockBaseAddress(pb, [])
    let g = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: PW, height: PH, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    g.translateBy(x: 0, y: CGFloat(PH)); g.scaleBy(x: S, y: -S)
    g.setFillColor(rgb(0.02, 0.02, 0.025)); g.fill(CGRect(x: 0, y: 0, width: SW, height: FH))
    /* the bezel carries one line while the song starts */
    if t < 3.4 { let a = CGFloat(min(1, t/0.3, (3.4 - t)/0.4))
      drawText(g, attributed("Put a song on.", 30, .heavy, NSColor(white: 1, alpha: 0.92*a), center: true), in: CGRect(x: 0, y: Y0*0.5 - 20, width: SW, height: 44)) }
    g.saveGState(); g.translateBy(x: 0, y: Y0); g.clip(to: CGRect(x: 0, y: 0, width: SW, height: SH))
    /* the camera: from the whole bar to their face, centred */
    let k = e3((t - zoomFrom)/(zoomTo - zoomFrom)), z = 1 + (Z - 1)*k
    let cx = HOME.x + (C.x - HOME.x)*k, cy = HOME.y + (C.y - HOME.y)*k
    g.translateBy(x: cx, y: cy); g.scaleBy(x: z, y: z); g.translateBy(x: -HOME.x, y: -HOME.y)
    linearL(g, [hex("#2a2f55"), hex("#151726")], [0, 1], from: CGPoint(x: 0, y: -SH), to: CGPoint(x: 0, y: SH*1.5))
    radial(g, [rgb(0.47, 0.39, 0.9, 0.35), rgb(0.47, 0.39, 0.9, 0)], [0, 1], from: CGPoint(x: SW*0.72, y: SH), 10, to: CGPoint(x: SW*0.72, y: SH), SW*0.6)
    g.setFillColor(rgb(0.055, 0.06, 0.095, 0.55)); g.fill(CGRect(x: -SW, y: 0, width: SW*3, height: notch.height))
    g.setFillColor(rgb(0, 0, 0)); g.addPath(CGPath(roundedRect: CGRect(x: NX - notch.width/2, y: -12, width: notch.width, height: notch.height + 12), cornerWidth: 12, cornerHeight: 12, transform: nil)); g.fillPath()
    drawText(g, attributed("Finder", 14, .bold, NSColor(white: 1, alpha: 0.86)), in: CGRect(x: 22, y: 9, width: 80, height: 20))
    let bx = SW - 34
    g.setStrokeColor(rgb(1, 1, 1, 0.8)); g.setLineWidth(1.4); g.stroke(CGRect(x: bx, y: notch.height/2 - 5, width: 20, height: 10))
    g.setFillColor(rgb(1, 1, 1, 0.8)); g.fill(CGRect(x: bx + 2, y: notch.height/2 - 3, width: 12, height: 6))
    let eh: CGFloat = 16, fw = eh*2.22
    drawFace(g, in: CGRect(x: HOME.x - fw/2, y: HOME.y - eh/2, width: fw, height: eh), look: look, who: who, ink: rgb(1, 1, 1), dark: true)
    g.restoreGState()
    /* the end card, the dance going on above the words */
    if t > tEnd { let a = CGFloat(min(1, (t - tEnd)/0.5))
      g.setFillColor(rgb(0.055, 0.06, 0.08, a)); g.fill(CGRect(x: 0, y: 0, width: SW, height: FH))
      g.saveGState(); g.setAlpha(a); let pop = popIn(t - tEnd - 0.05), ec = CGPoint(x: SW/2, y: FH*0.36)
      g.translateBy(x: ec.x, y: ec.y); g.scaleBy(x: pop, y: pop); g.translateBy(x: -ec.x, y: -ec.y)
      drawFace(g, in: CGRect(x: ec.x - 90, y: ec.y - 40, width: 180, height: 80), look: look, who: who, ink: rgb(1, 1, 1), dark: true); g.restoreGState()
      drawText(g, attributed("Roomie dances\nwhen you play music.", 32, .heavy, NSColor(white: 1, alpha: a), center: true), in: CGRect(x: 0, y: FH*0.5, width: SW, height: 90))
      drawText(g, attributed("Free for Mac\nlesheess.github.io/small-living-things", 15, .semibold, NSColor(white: 1, alpha: 0.7*a), center: true), in: CGRect(x: 0, y: FH*0.5 + 100, width: SW, height: 44)) }
    CVPixelBufferUnlockBaseAddress(pb, [])
    if !adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: CMTimeScale(FPS))) { print("append failed at frame", f, String(describing: writer.error)); break }
  }
  input.markAsFinished(); let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()
  guard writer.status == .completed else { print("video:", String(describing: writer.error)); exit(1) }

  /* ---- pictures and music together ---- */
  let comp = AVMutableComposition(), va = AVURLAsset(url: vURL), aa = AVURLAsset(url: aURL)
  let range = CMTimeRange(start: .zero, duration: CMTime(seconds: DUR, preferredTimescale: 600))
  guard let vt = va.tracks(withMediaType: .video).first, let at = aa.tracks(withMediaType: .audio).first,
        let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
        let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { print("no tracks"); exit(1) }
  try! cv.insertTimeRange(range, of: vt, at: .zero); try! ca.insertTimeRange(range, of: at, at: .zero)
  try? FileManager.default.removeItem(at: out)
  let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
  ex.outputURL = out; ex.outputFileType = .mp4
  let s2 = DispatchSemaphore(value: 0); ex.exportAsynchronously { s2.signal() }; s2.wait()
  try? FileManager.default.removeItem(at: base)
  print("wrote", args[i + 1], ex.status == .completed ? "" : "\(String(describing: ex.error))"); exit(0)
}
if let i = args.firstIndex(of: "--video"), i + 1 < args.count {
  /* the film for the launch, drawn by the app itself frame by frame: a close-up of a MacBook's menu bar, the walk nudge
     teleporting out of the bar into the notch, "Going" clicked, two minutes later the roommate catches you, and an end card.
     1920×1080, 30 fps, H.264. Usage: Roomie --video out.mp4 [madam|gentleman] [vertical]
     vertical: 1080×1920 for Reels; the lid's black bezel fills the top fifth (under the app's own buttons), the screen starts below it */
  let who: Who = args.count > i + 2 && args[i + 2] == "gentleman" ? .gentleman : .madam
  let vert = args.dropFirst(i + 2).contains("vertical")
  let PW = vert ? 1080 : 1920, PH = vert ? 1920 : 1080, FPS = 30.0, S: CGFloat = vert ? 2.5 : 2.6, SW = CGFloat(PW)/S, FH = CGFloat(PH)/S
  let Y0: CGFloat = vert ? (FH*0.2).rounded() : 0, SH = FH - Y0
  let notch = CGSize(width: 208, height: 37.5), NX = SW/2, HOME = CGPoint(x: NX + 104 + (vert ? 34 : 64), y: notch.height/2), DUR = 19.5
  let card = Card(kind: .move, text: who == .madam ? "Half an hour in that chair. Up you get: walk for five minutes." : "Thirty minutes seated. A five-minute walk would do you credit.", buttons: ["Going", "Later"])
  let goLine = who == .madam ? "Off you go. I'll be here." : "Very good. Take your time."
  let caughtLine = who == .madam ? "Going, you said. Darling, I can see you." : "A remarkably brief stroll, if I may say so."
  /* the scenes: what the island shows from when */
  let tOpen = 1.6, tClick = 3.9, tMsg = 4.0, tFold1 = 6.6, tCaught = 9.0, tFold2 = 16.0, tEnd = 16.7
  func phaseAt(_ t: Double) -> (Phase, Double) {
    if t >= tCaught && t < tFold2 { return (.caught, tCaught) }
    if t >= tMsg && t < tFold1 { return (.message, tMsg) }
    if t >= tOpen && t < tMsg { return (.open, tOpen) }
    return (.hidden, 0) }
  /* the pointer: wanders, goes to Going, clicks, types on (small jitters), then the end */
  func cursorAt(_ t: Double) -> CGPoint {
    let L = islandLayout(.open, text: card.text), w = max(L.size.width, notch.width + 2*EAR), x0 = NX - w/2 + (w - L.size.width)/2
    let going = CGPoint(x: x0 + L.buttons[0].midX, y: notch.height + L.buttons[0].midY + 2)
    let rest = CGPoint(x: SW*0.66, y: SH*0.62)
    func mix(_ a: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint { let e = CGFloat(k < 0.5 ? 4*k*k*k : 1 - pow(-2*k + 2, 3)/2); return CGPoint(x: a.x + (b.x - a.x)*e, y: a.y + (b.y - a.y)*e) }
    if t < 2.6 { return CGPoint(x: rest.x + CGFloat(sin(t*1.3))*30, y: rest.y + CGFloat(cos(t*0.9))*14) }
    if t < 3.6 { return mix(CGPoint(x: rest.x + CGFloat(sin(2.6*1.3))*30, y: rest.y + CGFloat(cos(2.6*0.9))*14), going, (t - 2.6)/1.0) }
    if t < 5.2 { return going }
    if t < 6.4 { return mix(going, CGPoint(x: SW*0.42, y: SH*0.7), (t - 5.2)/1.2) }
    let typing = CGPoint(x: SW*0.42, y: SH*0.7)
    if t < tCaught + 2.4 { return CGPoint(x: typing.x + CGFloat(sin(t*7))*2, y: typing.y + CGFloat(cos(t*5))*1.5) }
    return mix(typing, CGPoint(x: SW*0.58, y: SH*0.66), min(1, (t - tCaught - 2.4)/2.0)) }
  func e3(_ u: Double) -> CGFloat { CGFloat(u < 0.5 ? 4*u*u*u : 1 - pow(-2*u + 2, 3)/2) }
  func popIn(_ u: Double) -> CGFloat { u <= 0 ? 0 : u >= 0.6 ? 1 : CGFloat(1 - exp(-9*u)*cos(12*u)) }
  /* simulation state, stepped frame by frame like the app */
  var size = notch, vel = CGSize.zero, alpha: CGFloat = 0, lastPhase = Phase.hidden, arrivedAt = -100.0, leftAt = -100.0
  let url = URL(fileURLWithPath: args[i + 1]); try? FileManager.default.removeItem(at: url)
  let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: PW, AVVideoHeightKey: PH,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000, AVVideoMaxKeyFrameIntervalKey: 30, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
  input.expectsMediaDataInRealTime = false
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: PW, kCVPixelBufferHeightKey as String: PH])
  writer.add(input)
  guard writer.startWriting() else { print("could not start writing:", String(describing: writer.error)); exit(1) }
  writer.startSession(atSourceTime: .zero)
  let frames = Int(DUR*FPS), skip = vert ? Int(1.2*FPS) : 0   /* Reels: the first second of an empty bar is where people scroll away; start just before the card springs out */
  for f in 0..<frames {
    let t = Double(f)/FPS, dt = 1/FPS
    let (ph, since) = phaseAt(t), age = t - since
    let faceful = Island.faceful.contains(ph), wasFaceful = Island.faceful.contains(lastPhase)
    if faceful && !wasFaceful { arrivedAt = t }; if !faceful && wasFaceful { leftAt = t }
    if ph != lastPhase { alpha = 0 }; lastPhase = ph
    let text = ph == .open ? card.text : ph == .message ? goLine : ph == .caught ? caughtLine : ""
    let L = islandLayout(ph, text: text)
    let tg = ph == .hidden ? notch : CGSize(width: max(L.size.width, notch.width + 2*EAR), height: notch.height + L.size.height)
    let opening = tg.height > size.height, kw: CGFloat = opening ? 200 : 260, cw: CGFloat = opening ? 24 : 26, kh: CGFloat = opening ? 270 : 220, ch: CGFloat = opening ? 19 : 24
    for _ in 0..<8 { let h = CGFloat(dt)/8
      vel.width += (kw*(tg.width - size.width) - cw*vel.width)*h; size.width += vel.width*h
      vel.height += (kh*(tg.height - size.height) - ch*vel.height)*h; size.height += vel.height*h }
    let near = abs(size.height - tg.height) < max(4, tg.height*0.12) && abs(size.width - tg.width) < max(4, tg.width*0.12)
    alpha = near && ph != .hidden ? min(1, alpha + CGFloat(dt)*7) : max(0, alpha - CGFloat(dt)*14)
    let cur = cursorAt(t)
    if f < skip { continue }
    while !input.isReadyForMoreMediaData { usleep(2000) }
    var pbo: CVPixelBuffer?
    if let pool = adaptor.pixelBufferPool { CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbo) }
    else { CVPixelBufferCreate(nil, PW, PH, kCVPixelFormatType_32BGRA, [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pbo) }
    guard let pb = pbo else { print("no pixel buffer at frame", f); exit(1) }
    CVPixelBufferLockBaseAddress(pb, [])
    let g = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: PW, height: PH, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    g.translateBy(x: 0, y: CGFloat(PH)); g.scaleBy(x: S, y: -S)
    if vert { g.setFillColor(rgb(0.02, 0.02, 0.025)); g.fill(CGRect(x: 0, y: 0, width: SW, height: Y0)); g.translateBy(x: 0, y: Y0) }
    /* the desktop and the menu bar */
    g.saveGState(); g.clip(to: CGRect(x: 0, y: 0, width: SW, height: SH))
    linearL(g, [hex("#2a2f55"), hex("#151726")], [0, 1], from: .zero, to: CGPoint(x: 0, y: SH))
    radial(g, [rgb(0.47, 0.39, 0.9, 0.35), rgb(0.47, 0.39, 0.9, 0)], [0, 1], from: CGPoint(x: SW*0.72, y: SH), 10, to: CGPoint(x: SW*0.72, y: SH), SW*0.6)
    g.restoreGState()
    g.setFillColor(rgb(0.055, 0.06, 0.095, 0.55)); g.fill(CGRect(x: 0, y: 0, width: SW, height: notch.height))
    drawText(g, attributed("Finder", 14, .bold, NSColor(white: 1, alpha: 0.86)), in: CGRect(x: 22, y: 9, width: 80, height: 20))
    if !vert {
      for (k, w) in ["File", "Edit"].enumerated() { drawText(g, attributed(w, 14, .medium, NSColor(white: 1, alpha: 0.72)), in: CGRect(x: 84 + CGFloat(k)*46, y: 9, width: 60, height: 20)) }
      drawText(g, attributed("Mon 16:20", 14, .semibold, NSColor(white: 1, alpha: 0.86)), in: CGRect(x: SW - 96, y: 9, width: 90, height: 20)) }
    let bx = vert ? SW - 34 : SW - 136
    g.setStrokeColor(rgb(1, 1, 1, 0.8)); g.setLineWidth(1.4); g.stroke(CGRect(x: bx, y: notch.height/2 - 5, width: 20, height: 10))
    g.setFillColor(rgb(1, 1, 1, 0.8)); g.fill(CGRect(x: bx + 2, y: notch.height/2 - 3, width: 12, height: 6))
    /* the roommate in the bar: following the pointer, blinking; teleporting out and back */
    var tScale: CGFloat = 1, tSquash: CGFloat = 0, tPuff = -1.0
    if faceful { let u = t - arrivedAt
      if u < 0.05 { tScale = 1 + 0.08*e3(u/0.05) } else if u < 0.14 { let k = e3((u - 0.05)/0.09); tScale = 1.08*(1 - k); tSquash = k } else { tScale = 0 }
      if u >= 0.1 { tPuff = u - 0.1 } }
    else { let u = t - leftAt - 0.12; if u < 0 { tScale = 0 } else if u < 0.6 { tScale = popIn(u); tPuff = u } }
    var bar = FaceLook(); let dx = cur.x - HOME.x, dy = cur.y - HOME.y, d = max(1, hypot(dx, dy)), k = min(1, d/260)*0.68
    for kp in [\FaceLook.l, \FaceLook.r] { bar[keyPath: kp].px = dx/d*k; bar[keyPath: kp].py = dy/d*k }
    if [1.1, 5.9, 8.1, 17.2].contains(where: { t >= $0 && t < $0 + 0.13 }) { bar.l.closed = .blink; bar.r.closed = .blink }
    let eh: CGFloat = 16, fw = eh*2.22
    if tScale > 0.01 { g.saveGState(); g.translateBy(x: HOME.x, y: HOME.y); g.scaleBy(x: max(0.01, tScale + 0.5*tSquash), y: max(0.01, tScale*(1 - 0.85*tSquash))); g.translateBy(x: -HOME.x, y: -HOME.y)
      drawFace(g, in: CGRect(x: HOME.x - fw/2, y: HOME.y - eh/2, width: fw, height: eh), look: bar, who: who, ink: rgb(1, 1, 1), dark: true); g.restoreGState() }
    if tPuff >= 0 && tPuff < 0.35 { let kk = CGFloat(tPuff/0.35), dd = 4 + 9*CGFloat(1 - exp(-6*tPuff/0.35)), cols = [rgb(1, 1, 1), FX_SPIN, FX_HEART, rgb(1, 1, 1)]
      for j in 0..<4 { let a = CGFloat(j)*CGFloat.pi/2 + 0.4; drawSparkle(g, at: CGPoint(x: HOME.x + cos(a)*dd*1.3, y: HOME.y + sin(a)*dd*0.55), r: 2.6*(1 - kk), color: cols[j].copy(alpha: 1 - kk)!) } }
    /* the island */
    var cardLook = FaceLook()
    if ph == .message { let hu = t - (tMsg + 0.2); if hu >= 0 && hu < Brain.loveFor { var x = 1 - exp(-7*hu)*cos(15*hu); for b in [0.85, 1.1, 1.55, 1.8] { let dd2 = hu - b; if dd2 > 0 && dd2 < 0.2 { x += 0.24*sin(dd2/0.2 * .pi) } }
      let out = Brain.loveFor - 0.28; if hu > out { let kk = (hu - out)/0.28; x *= 1 - kk*kk }; cardLook.l.heart = CGFloat(max(0, x)); cardLook.r.heart = CGFloat(max(0, x)) } }
    let fu = t - arrivedAt - 0.1, faceScale: CGFloat = fu <= 0 ? 0 : fu >= 0.6 ? 1 : CGFloat(1 - exp(-9*fu)*cos(12*fu))
    let fl: CGFloat = 6, ox = NX - (size.width + 2*fl)/2
    /* where the face sits, for the caught card's gaze */
    var gaze = CGPoint.zero
    if ph == .caught { let fcx = ox + fl + (size.width - L.size.width)/2 + L.face.midX, fcy = notch.height + L.face.midY
      let gdx = cur.x - fcx, gdy = cur.y - fcy, gd = max(1, hypot(gdx, gdy)), gk = min(1, gd/260); gaze = CGPoint(x: gdx/gd*gk, y: gdy/gd*gk) }
    let hover = ph == .open && t >= 3.4 ? 0 : -1
    g.saveGState(); g.translateBy(x: ox, y: 0)
    paintIsland(g, size: size, phase: ph, text: text, buttons: ph == .open ? card.buttons : [], who: who, alpha: alpha, t: t, left: 0, hover: hover,
                notch: notch, kind: .move, look: cardLook, burst: t - (tMsg + 0.25), age: age, gaze: gaze, faceScale: faceScale)
    g.restoreGState()
    /* "two minutes later" */
    if t > 7.0 && t < 9.2 { let a = CGFloat(min(1, (t - 7.0)/0.4, (9.2 - t)/0.4))
      drawText(g, attributed("Two minutes later…", 22, .semibold, NSColor(white: 1, alpha: 0.9*a), center: true), in: CGRect(x: 0, y: SH*(vert ? 0.56 : 0.8), width: SW, height: 34)) }
    /* the pointer, with a little press on the click */
    if t < tEnd + 0.2 { let press: CGFloat = abs(t - tClick) < 0.12 ? 0.85 : 1
      g.saveGState(); g.translateBy(x: cur.x, y: cur.y); g.scaleBy(x: 1.15*press, y: 1.15*press)
      let arrow = CGMutablePath(); arrow.move(to: .zero); [CGPoint(x: 0, y: 17), CGPoint(x: 4.2, y: 13), CGPoint(x: 7, y: 19.5), CGPoint(x: 9.6, y: 18.4), CGPoint(x: 6.9, y: 12.2), CGPoint(x: 12.4, y: 12.2)].forEach { arrow.addLine(to: $0) }; arrow.closeSubpath()
      g.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: rgb(0, 0, 0, 0.4)); g.addPath(arrow); g.setFillColor(rgb(0, 0, 0)); g.fillPath()
      g.setShadow(offset: .zero, blur: 0, color: nil); g.addPath(arrow); g.setStrokeColor(rgb(1, 1, 1)); g.setLineWidth(1.3); g.strokePath(); g.restoreGState() }
    /* the end card */
    if t > tEnd { let a = CGFloat(min(1, (t - tEnd)/0.6))
      g.translateBy(x: 0, y: -Y0); let SH = FH
      g.setFillColor(rgb(0.055, 0.06, 0.08, a)); g.fill(CGRect(x: 0, y: 0, width: SW, height: SH))
      var end = FaceLook(); end.l.px = 0.25; end.r.px = 0.25; end.l.py = 0.1; end.r.py = 0.1; if t > tEnd + 1.6 && t < tEnd + 1.75 { end.l.closed = .blink; end.r.closed = .blink }
      g.saveGState(); g.setAlpha(a); let pop = popIn(t - tEnd - 0.1), ec = CGPoint(x: SW/2, y: SH*0.36)
      g.translateBy(x: ec.x, y: ec.y); g.scaleBy(x: pop, y: pop); g.translateBy(x: -ec.x, y: -ec.y)
      drawFace(g, in: CGRect(x: ec.x - 90, y: ec.y - 40, width: 180, height: 80), look: end, who: who, ink: rgb(1, 1, 1), dark: true); g.restoreGState()
      if vert {
        drawText(g, attributed("Roomie lives in\nyour menu bar.", 34, .heavy, NSColor(white: 1, alpha: a), center: true), in: CGRect(x: 0, y: SH*0.47, width: SW, height: 90))
        drawText(g, attributed("Free for Mac\nlesheess.github.io/small-living-things", 15, .semibold, NSColor(white: 1, alpha: 0.7*a), center: true), in: CGRect(x: 0, y: SH*0.47 + 100, width: SW, height: 44)) }
      else {
        drawText(g, attributed("Roomie lives in your menu bar.", 30, .heavy, NSColor(white: 1, alpha: a), center: true), in: CGRect(x: 0, y: SH*0.56, width: SW, height: 44))
        drawText(g, attributed("Free for Mac · lesheess.github.io/small-living-things", 15, .semibold, NSColor(white: 1, alpha: 0.7*a), center: true), in: CGRect(x: 0, y: SH*0.56 + 50, width: SW, height: 24)) } }
    CVPixelBufferUnlockBaseAddress(pb, [])
    if !adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(f - skip), timescale: CMTimeScale(FPS))) { print("append failed at frame", f, String(describing: writer.error)); break }
  }
  input.markAsFinished(); let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()
  print("wrote", args[i + 1], writer.status == .completed ? "" : "\(String(describing: writer.error))"); exit(0)
}
if let i = args.firstIndex(of: "--extra"), i + 1 < args.count {
  /* asleep with drifting z's and low battery with its badge, big and at menu-bar size, on dark and light */
  var sl = FaceLook(); sl.l.closed = .sleep; sl.r.closed = .sleep; sl.zzz = 0.7
  var lb = FaceLook(); lb.l.up = 0.3; lb.r.up = 0.3; lb.l.ang = -0.2; lb.r.ang = 0.2; lb.l.px = 0.6; lb.r.px = 0.6; lb.battery = 0.1
  let looks = [(Who.madam, sl), (.gentleman, sl), (.madam, lb), (.gentleman, lb)]
  let img = bitmap(CGSize(width: 1000, height: 300)) { g in
    for (row, dark) in [true, false].enumerated() {
      g.setFillColor(dark ? rgb(0.15, 0.15, 0.17) : rgb(0.91, 0.91, 0.93)); g.fill(CGRect(x: 0, y: CGFloat(row)*150, width: 1000, height: 150))
      for (k, l) in looks.enumerated() {
        drawFace(g, in: CGRect(x: 30 + CGFloat(k)*245, y: CGFloat(row)*150 + 30, width: 64*2.22, height: 64), look: l.1, who: l.0, ink: dark ? rgb(1, 1, 1) : rgb(0, 0, 0), dark: dark)
        drawFace(g, in: CGRect(x: 30 + CGFloat(k)*245 + 160, y: CGFloat(row)*150 + 60, width: 16*2.22, height: 16), look: l.1, who: l.0, ink: dark ? rgb(1, 1, 1) : rgb(0, 0, 0), dark: dark) } } }
  writePNG(img, args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--tele"), i + 1 < args.count {
  /* the teleport in the menu bar, frame by frame: leaving (swell, squeeze, puff) and coming back (pop, puff) */
  let frames: [(CGFloat, CGFloat, Double)] = [(1, 0, -1), (1.1, 0, -1), (0.7, 0.55, -1), (0.15, 0.95, 0.05), (0, 0, 0.2), (0, 0, 0.4), (0.6, 0, 0.08), (1.12, 0, 0.2), (1, 0, 0.45)]
  let fw: CGFloat = EyesView.eyeH*2.22 + 10, sc: CGFloat = 4
  let img = bitmap(CGSize(width: fw*sc*CGFloat(frames.count), height: 22*sc)) { g in
    g.setFillColor(rgb(0.15, 0.15, 0.17)); g.fill(CGRect(x: 0, y: 0, width: fw*sc*CGFloat(frames.count), height: 22*sc))
    for (k, f) in frames.enumerated() {
      let im = glyphImage(FaceLook(), who: .madam, scale: f.0, squash: f.1, puff: f.2)
      NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: true)
      im.draw(in: NSRect(x: fw*sc*CGFloat(k), y: 0, width: fw*sc, height: 22*sc), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
      NSGraphicsContext.restoreGraphicsState() } }
  writePNG(img, args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--say"), i + 1 < args.count {
  /* the passing remarks: each roommate, under the notch, in three moods */
  let notch = CGSize(width: 208, height: 37.5), rows: [(Who, Reaction)] = [(.madam, .back), (.madam, .cry), (.gentleman, .dizzy), (.gentleman, .hot), (.madam, .music), (.gentleman, .music)]
  let W: CGFloat = 560, RH = notch.height + 40 + 40
  let img = bitmap(CGSize(width: W, height: RH*CGFloat(rows.count))) { g in
    g.setFillColor(rgb(0.2, 0.22, 0.27)); g.fill(CGRect(x: 0, y: 0, width: W, height: RH*CGFloat(rows.count)))
    for (k, row) in rows.enumerated() {
      let text = Lines.react(row.1, row.0), L = islandLayout(.say, text: text), w = max(L.size.width, notch.width + 2*EAR)
      var look = FaceLook()
      switch row.1 { case .back: look.l.heart = 1.1; look.r.heart = 1.1; case .cry: look.tear = 0.3; look.l.ang = -0.42; look.r.ang = 0.42; look.l.up = 0.3; look.r.up = 0.3
                     case .dizzy: look.l.spiral = 1; look.r.spiral = 1; case .hot: look.sweat = 0.5; case .battery: break; case .music: look.l.closed = .joy; look.r.closed = .joy }
      g.saveGState(); g.translateBy(x: (W - w - 12)/2, y: RH*CGFloat(k) + 10)
      paintIsland(g, size: CGSize(width: w, height: notch.height + L.size.height), phase: .say, text: text, buttons: [], who: row.0, alpha: 1, t: 1, left: 0, hover: -1, notch: notch, look: look, age: k == 0 ? 0.5 : k == 1 ? 0.85 : 99)
      g.restoreGState() } }
  writePNG(img, args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--caught"), i + 1 < args.count {
  /* caught: the pill under the notch at moments of its life, Madam above, the Gentleman below; the pointer is down and right */
  let ages = [0.45, 1.4, 2.2, 3.4, 6.2, 8.0], notch = CGSize(width: 208, height: 37.5), cw: CGFloat = 372
  let L = islandLayout(.caught, text: Lines.caught(.gentleman)), ch = notch.height + L.size.height + 16
  let img = bitmap(CGSize(width: cw*CGFloat(ages.count), height: ch*2)) { g in
    g.setFillColor(rgb(0.2, 0.22, 0.27)); g.fill(CGRect(x: 0, y: 0, width: cw*CGFloat(ages.count), height: ch*2))
    for (row, who) in [Who.madam, .gentleman].enumerated() {
      let L = islandLayout(.caught, text: Lines.caught(who))
      for (k, u) in ages.enumerated() {
        g.saveGState(); g.translateBy(x: cw*CGFloat(k) + (cw - CARD_W - 12)/2, y: ch*CGFloat(row))
        paintIsland(g, size: CGSize(width: CARD_W, height: notch.height + L.size.height), phase: .caught, text: Lines.caught(who), buttons: [], who: who,
                    alpha: 1, t: u, left: 0, hover: -1, notch: notch, age: u, gaze: CGPoint(x: 0.45, y: 0.75))
        g.restoreGState() } } }
  writePNG(img, args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--site"), i + 1 < args.count {
  /* pictures for the site, drawn by the app itself: each roommate in seven moods, and a nudge under the bar */
  let dir = args[i + 1], fh: CGFloat = 64, fw = fh*2.22, cell = fw + 44
  func f(_ m: (inout FaceLook) -> Void) -> FaceLook { var x = FaceLook(); m(&x); return x }
  for who in [Who.madam, .gentleman] {
    let open: CGFloat = who == .gentleman ? -0.55 : -0.25
    let moods: [FaceLook] = [
      f { $0.l.px = 0.32; $0.r.px = 0.32; $0.l.py = 0.18; $0.r.py = 0.18 },
      f { $0.l.heart = 1.12; $0.r.heart = 1.12; $0.l.up = open; $0.r.up = open },
      f { $0.l.closed = .joy; $0.r.closed = .joy },
      f { $0.l.closed = .sleep; $0.r.closed = .sleep },
      f { $0.l.spiral = 1; $0.r.spiral = 1; $0.r.spin = 2 },
      f { for k in [\FaceLook.l, \FaceLook.r] { $0[keyPath: k].up = 0.3; $0[keyPath: k].py = 0.4; $0[keyPath: k].pupil = 0.33 }; $0.l.ang = -0.42; $0.r.ang = 0.42; $0.tear = 0.25 },
      f { for k in [\FaceLook.l, \FaceLook.r] { $0[keyPath: k].pupil = 0.26; $0[keyPath: k].px = -0.1 }; $0.sweat = 0.45 }]
    let img = bitmap(CGSize(width: cell*CGFloat(moods.count), height: fh*1.9)) { g in
      for (k, m) in moods.enumerated() {
        drawFace(g, in: CGRect(x: cell*CGFloat(k) + 22, y: fh*0.4, width: fw, height: fh), look: m, who: who, ink: rgb(1, 1, 1), dark: true) } }
    writePNG(img, dir + "/" + who.rawValue + ".png") }
  /* a nudge: the bar, the eyes glancing down at the black pill, the pill open with her line */
  let W: CGFloat = 640, BH: CGFloat = 30
  let card = Lines.card(.eyes, .madam), L = islandLayout(.open, text: card.text)
  let img = bitmap(CGSize(width: W, height: BH + L.size.height + 40)) { g in
    g.setFillColor(rgb(0.086, 0.09, 0.12)); g.fill(CGRect(x: 0, y: 0, width: W, height: BH + L.size.height + 40))
    g.setFillColor(rgb(0.13, 0.135, 0.17)); g.fill(CGRect(x: 0, y: 0, width: W, height: BH))
    let eh: CGFloat = 16, efw = eh*2.22, ex = W - 260
    var look = FaceLook(); look.l.py = 0.62; look.r.py = 0.62; look.l.px = 0.05; look.r.px = 0.05
    drawFace(g, in: CGRect(x: ex - efw/2, y: BH/2 - eh/2, width: efw, height: eh), look: look, who: .madam, ink: rgb(1, 1, 1), dark: true)
    let ink = rgb(1, 1, 1, 0.86); g.setStrokeColor(ink); g.setLineWidth(1.5)
    var x = ex + 40
    g.strokeEllipse(in: CGRect(x: x, y: BH/2 - 7, width: 14, height: 14)); x += 32
    for r in [CGFloat(3.5), 7, 10.5] { g.beginPath(); g.addArc(center: CGPoint(x: x + 10, y: BH/2 + 5), radius: r, startAngle: -.pi*0.78, endAngle: -.pi*0.22, clockwise: false); g.strokePath() }
    x += 36; g.stroke(CGRect(x: x, y: BH/2 - 5, width: 21, height: 10)); x += 34
    drawText(g, attributed("19 Nov  16:20", 13, .semibold, NSColor(white: 1, alpha: 0.86)), in: CGRect(x: x, y: BH/2 - 8, width: 140, height: 16))
    g.saveGState(); g.translateBy(x: ex - L.size.width/2, y: BH)
    paintIsland(g, size: L.size, phase: .open, text: card.text, buttons: card.buttons, who: .madam, alpha: 1, t: 1, left: 0, hover: -1); g.restoreGState() }
  writePNG(img, dir + "/nudge.png")
  /* the shelf's plate: the two of them, side by side, looking at you */
  let shelf = bitmap(CGSize(width: 890, height: 340)) { g in
    g.setFillColor(rgb(0.083, 0.086, 0.114)); g.fill(CGRect(x: 0, y: 0, width: 890, height: 340))
    let h: CGFloat = 92, w = h*2.22
    var m = FaceLook(); m.l.px = 0.28; m.r.px = 0.28; m.l.py = 0.12; m.r.py = 0.12
    var gl = FaceLook(); gl.l.px = -0.3; gl.r.px = -0.3; gl.l.py = 0.1; gl.r.py = 0.1
    drawFace(g, in: CGRect(x: 445 - 40 - w, y: 170 - h/2, width: w, height: h), look: m, who: .madam, ink: rgb(1, 1, 1), dark: true)
    drawFace(g, in: CGRect(x: 445 + 40, y: 170 - h/2, width: w, height: h), look: gl, who: .gentleman, ink: rgb(1, 1, 1), dark: true) }
  writePNG(shelf, dir + "/shelf.png")
  /* caught: Madam's card under the notch, mid-squint, her dry line under the eyes */
  do { let notch = CGSize(width: 208, height: 37.5), text = "Going, you said. Darling, I can see you.", L = islandLayout(.caught, text: text)
    let W: CGFloat = 640, H = notch.height + L.size.height + 24
    let img = bitmap(CGSize(width: W, height: H)) { g in
      g.setFillColor(rgb(0.086, 0.09, 0.12)); g.fill(CGRect(x: 0, y: 0, width: W, height: H))
      g.setFillColor(rgb(0.13, 0.135, 0.17)); g.fill(CGRect(x: 0, y: 0, width: W, height: notch.height))
      g.translateBy(x: (W - CARD_W - 12)/2, y: 0)
      paintIsland(g, size: CGSize(width: CARD_W, height: notch.height + L.size.height), phase: .caught, text: text, buttons: [], who: .madam,
                  alpha: 1, t: 3.4, left: 0, hover: -1, notch: notch, age: 3.4, gaze: CGPoint(x: 0.55, y: 0.6)) }
    writePNG(img, dir + "/caught.png") }
  print("wrote", dir); exit(0)
}
if let i = args.firstIndex(of: "--island"), i + 1 < args.count {
  /* the island in the notch: at rest, compact, open, counting, choosing; on a strip of menu bar */
  _ = NSApplication.shared
  for scr in NSScreen.screens { print("screen", scr.localizedName, scr.frame, "notch", notchRect(scr).map { "\($0)" } ?? "none") }
  let notch = CGSize(width: 185, height: 32), W: CGFloat = 520
  let card = Lines.card(.eyes, .madam)
  let rows: [(Phase, String, [String], Kind?)] = [(.hint, "", [], .eyes), (.open, card.text, card.buttons, nil),
                                                  (.counting, Lines.counting(.madam), [], nil), (.message, Lines.eyesDone(.madam), [], nil), (.choose, "", [], nil),
                                                  { let c = Lines.card(.late, .gentleman); return (.open, c.text, c.buttons, nil) }()]
  let rowH: CGFloat = 230
  let img = bitmap(CGSize(width: W, height: rowH*CGFloat(rows.count))) { g in
    for (k, r) in rows.enumerated() {
      let y0 = rowH*CGFloat(k)
      g.setFillColor(rgb(0.3, 0.38, 0.55)); g.fill(CGRect(x: 0, y: y0, width: W, height: rowH))
      g.setFillColor(rgb(0.2, 0.25, 0.38)); g.fill(CGRect(x: 0, y: y0, width: W, height: notch.height))
      let L = islandLayout(r.0, text: r.1)
      let size: CGSize = r.0 == .hidden ? notch : r.0 == .hint ? CGSize(width: notch.width + 2*EAR, height: notch.height) : CGSize(width: max(L.size.width, notch.width + 2*EAR), height: notch.height + L.size.height)
      g.saveGState(); g.translateBy(x: W/2 - size.width/2 - 6, y: y0)
      var lk = FaceLook(); if r.0 == .message { lk.l.heart = 1.1; lk.r.heart = 1.1; lk.l.up = -0.25; lk.r.up = -0.25 }
      paintIsland(g, size: size, phase: r.0, text: r.1, buttons: r.2, who: .madam, alpha: 1, t: 0.4, left: 13, hover: -1, notch: notch, kind: r.3, look: lk, burst: r.0 == .message ? 0.45 : -1)
      if r.0 == .hint { var sl = FaceLook(); sl.l.closed = .joy; sl.r.closed = .joy; sl.sparkle = 0.2
        drawFace(g, in: CGRect(x: 30, y: y0 + 90, width: 64*2.22, height: 64), look: sl, who: .madam, ink: rgb(1, 1, 1), dark: true)
        var hl = FaceLook(); hl.l.heart = 1.1; hl.r.heart = 1.1; hl.sparkle = 0.35
        drawFace(g, in: CGRect(x: W - 30 - 64*2.22, y: y0 + 90, width: 64*2.22, height: 64), look: hl, who: .gentleman, ink: rgb(1, 1, 1), dark: true) }
      g.restoreGState()
      /* the notch itself, drawn as a faint outline to see that the island covers it */
      g.setStrokeColor(rgb(1, 0, 0, 0.5)); g.setLineWidth(0.5); g.stroke(CGRect(x: W/2 - notch.width/2, y: y0, width: notch.width, height: notch.height)) } }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--pg"), i + 1 < args.count {
  /* the Playground's picture, without the window: madam in love */
  let v = PlaygroundView(frame: NSRect(x: 0, y: 0, width: 640, height: 402)); v.who = .madam
  var f = FaceLook(); f.l.heart = 1.1; f.r.heart = 1.1; f.l.up = -0.25; f.r.up = -0.25; v.look = f
  let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!; v.cacheDisplay(in: v.bounds, to: rep)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[i + 1])); print("wrote", args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--bar"), i + 1 < args.count {
  /* his notched MacBook's bar: 37 pt, glass over a blue wallpaper and over a light one; white glyphs about 16 pt beside the eyes */
  let W: CGFloat = 760, BH: CGFloat = 37
  let looks: [(Who, FaceLook)] = [(.madam, FaceLook()), (.gentleman, FaceLook()), (.madam, { var f = FaceLook(); f.l.closed = .joy; f.r.closed = .joy; return f }()),
                                  (.gentleman, { var f = FaceLook(); f.l.px = 0.3; f.r.px = 0.3; f.l.py = 0.4; f.r.py = 0.4; return f }()),
                                  (.madam, { var f = FaceLook(); f.tear = 0.3; f.l.py = 0.5; f.r.py = 0.5; f.l.up = 0.2; f.r.up = 0.2; return f }()),
                                  (.gentleman, { var f = FaceLook(); f.l.heart = 1.1; f.r.heart = 1.1; f.l.up = -0.55; f.r.up = -0.55; f.sweat = 0.5; return f }()),
                                  (.madam, { var f = FaceLook(); f.l.spiral = 1; f.r.spiral = 1; f.r.spin = 2; return f }())]
  let ZH: CGFloat = 130
  let img = bitmap(CGSize(width: W, height: BH*CGFloat(looks.count)*3 + 10 + ZH*2)) { g in
    for (k, darkBar) in [true, false].enumerated() {
      let y = BH*CGFloat(looks.count)*3 + 10 + ZH*CGFloat(k), glyph = darkBar ? rgb(1, 1, 1) : rgb(0.1, 0.1, 0.12)
      g.setFillColor(darkBar ? rgb(0.34, 0.42, 0.58) : rgb(0.9, 0.91, 0.93)); g.fill(CGRect(x: 0, y: y, width: W, height: ZH))
      for (j, l) in looks.enumerated() { let fh: CGFloat = 70, fw = fh*2.22
        drawFace(g, in: CGRect(x: 12 + CGFloat(j)*(fw + 14), y: y + (ZH - fh)/2, width: fw, height: fh), look: l.1, who: l.0, ink: glyph, dark: darkBar) } }
    for (row, l) in looks.enumerated() { for (k, darkBar) in [true, false, true].enumerated() {
      let y = (CGFloat(row)*3 + CGFloat(k))*BH, dim = k == 2
      g.setFillColor(darkBar ? rgb(0.34, 0.42, 0.58) : rgb(0.9, 0.91, 0.93)); g.fill(CGRect(x: 0, y: y, width: W, height: BH))
      let glyph = dim ? rgb(1, 1, 1, 0.45) : darkBar ? rgb(1, 1, 1) : rgb(0.1, 0.1, 0.12)
      var x: CGFloat = 150
      let fw = EyesView.eyeH*2.22
      drawFace(g, in: CGRect(x: x, y: y + BH/2 - EyesView.eyeH/2, width: fw, height: EyesView.eyeH), look: l.1, who: l.0, ink: glyph, dark: darkBar); x += fw + 26
      /* stand-ins for the glyphs beside them: a play circle, a cloud with text, a wifi fan, a battery */
      g.setStrokeColor(glyph); g.setFillColor(glyph); g.setLineWidth(1.6)
      g.strokeEllipse(in: CGRect(x: x, y: y + BH/2 - 8, width: 16, height: 16)); x += 40
      drawText(g, attributed("7°C", 14, .medium, NSColor(cgColor: glyph)!), in: CGRect(x: x, y: y + BH/2 - 9, width: 40, height: 18)); x += 60
      for r in [CGFloat(4), 8, 12] { g.beginPath(); g.addArc(center: CGPoint(x: x + 12, y: y + BH/2 + 6), radius: r, startAngle: -.pi*0.78, endAngle: -.pi*0.22, clockwise: false); g.strokePath() }
      x += 46; g.stroke(CGRect(x: x, y: y + BH/2 - 6, width: 24, height: 12)); x += 50
      drawText(g, attributed("19 Nov 13:56", 14, .medium, NSColor(cgColor: glyph)!), in: CGRect(x: x, y: y + BH/2 - 9, width: 120, height: 18)) } }
  }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
  let n: CGFloat = 1024
  let img = bitmap(CGSize(width: n, height: n), scale: 1) { g in
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    g.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)); g.clip()
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: cs, colors: [rgb(0.16, 0.17, 0.23), rgb(0.06, 0.065, 0.09)] as CFArray, locations: [0, 1])!
    g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    var f = FaceLook(); f.l.px = 0.22; f.l.py = -0.2; f.r.px = 0.22; f.r.py = -0.2
    drawFace(g, in: CGRect(x: 512 - 290*2.22/2, y: 512 - 145, width: 290*2.22, height: 290), look: f, who: nil, ink: rgb(1, 1, 1), dark: true)
  }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
/* a square profile picture: the icon's eyes on a full-bleed tile, sized to sit inside a circle crop */
if let i = args.firstIndex(of: "--avatar"), i + 1 < args.count {
  let n: CGFloat = 1024
  let img = bitmap(CGSize(width: n, height: n), scale: 1) { g in
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let grad = CGGradient(colorsSpace: cs, colors: [rgb(0.16, 0.17, 0.23), rgb(0.06, 0.065, 0.09)] as CFArray, locations: [0, 1])!
    g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: n), options: [])
    var f = FaceLook(); f.l.px = 0.22; f.l.py = -0.2; f.r.px = 0.22; f.r.py = -0.2
    let h: CGFloat = 300
    drawFace(g, in: CGRect(x: 512 - h*2.22/2, y: 512 - h/2, width: h*2.22, height: h), look: f, who: nil, ink: rgb(1, 1, 1), dark: true)
  }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
if let i = args.firstIndex(of: "--dance"), i + 1 < args.count {
  /* a filmstrip of the dance: both roommates at moments through an eight-bar phrase, big and at menu-bar size, on a dark bar */
  _ = NSApplication.shared
  let beats: [Double] = [0, 0.5, 1, 2, 6.5, 23.2, 24.5, 28.3], labels = ["beat", "after", "beat", "sway", "pleased", "wink / —", "— / brow", "hearts / savour"]
  let cw: CGFloat = 150, W = cw*CGFloat(beats.count), rowH: CGFloat = 150, smallH: CGFloat = 40
  let img = bitmap(CGSize(width: W, height: (rowH + smallH)*2 + 24)) { g in
    g.setFillColor(rgb(0.1, 0.1, 0.12)); g.fill(CGRect(x: 0, y: 0, width: W, height: (rowH + smallH)*2 + 24))
    for (k, lab) in labels.enumerated() { drawText(g, attributed(lab, 11, .medium, NSColor(white: 1, alpha: 0.5), center: true), in: CGRect(x: CGFloat(k)*cw, y: 5, width: cw, height: 16)) }
    for (r, w) in [Who.madam, .gentleman].enumerated() {
      let y0 = 24 + CGFloat(r)*(rowH + smallH)
      for (k, b) in beats.enumerated() {
        var f = FaceLook(); f.l.px = 0; f.r.px = 0; f.l.py = 0; f.r.py = 0
        applyDance(&f, beat: b, sure: 1, period: 60/112, who: w, amt: 1)
        let x0 = CGFloat(k)*cw, fh: CGFloat = 52, fw = fh*2.22
        g.setFillColor(rgb(0, 0, 0)); g.fill(CGRect(x: x0 + 2, y: y0, width: cw - 4, height: rowH - 4))
        drawFace(g, in: CGRect(x: x0 + cw/2 - fw/2, y: y0 + rowH/2 - fh/2 + 6, width: fw, height: fh), look: f, who: w, dark: true)
        g.setFillColor(rgb(0.15, 0.15, 0.17)); g.fill(CGRect(x: x0 + 2, y: y0 + rowH, width: cw - 4, height: smallH - 6))
        let eh = EyesView.eyeH; drawFace(g, in: CGRect(x: x0 + cw/2 - eh*1.11, y: y0 + rowH + (smallH - 6)/2 - eh/2, width: eh*2.22, height: eh), look: f, who: w, dark: true) } } }
  writePNG(img, args[i + 1]); print("wrote", args[i + 1]); exit(0)
}
if args.contains("--beattest") {
  /* the beat tracker on made-up drums: a kick on every beat, a snare on 2 and 4, hats, and noise; prints what it hears */
  for bpm in [84.0, 112.0, 128.0, 150.0] {
    let rate = 48000.0, period = 60/bpm, tr = BeatTracker(); var sig = [Float](repeating: 0, count: Int(rate*12))
    for i in 0..<sig.count { let t = Double(i)/rate, ph = t.truncatingRemainder(dividingBy: period), half = t.truncatingRemainder(dividingBy: period/2)
      var x = Float.random(in: -0.02...0.02)
      x += Float(0.8*exp(-ph*30)*sin(2*Double.pi*(60 + 90*exp(-ph*25))*ph))                       /* kick */
      if Int(t/period) % 2 == 1 { x += Float.random(in: -1...1)*Float(0.3*exp(-ph*40)) }           /* snare */
      x += Float.random(in: -1...1)*Float(0.08*exp(-half*120))                                      /* hats */
      sig[i] = x }
    var t = 0.0; while t < 11.9 { let end = Int(t*rate); if end >= 1024 { tr.feed(Array(sig[(end - 1024)..<end]), rate: rate, t: t) }; t += 1.0/60 }
    var ph = (tr.beat(12) - 12/period).truncatingRemainder(dividingBy: 1); if ph < -0.5 { ph += 1 }
    if args.contains("-v") { let g = (tr.t0/period).truncatingRemainder(dividingBy: 1); print(String(format: "  t0 %.3f on the grid at %.2f; period %.4f vs %.4f", tr.t0, g, tr.period, period)) }
    print(String(format: "played %3.0f bpm: heard %5.1f bpm, sure %.2f, phase error %+.2f beat", bpm, 60/tr.period, tr.conf, ph > 0.5 ? ph - 1 : ph)) }
  exit(0)
}
if args.contains("--selftest") {
  /* a made-up working day through the rules, one second at a time; every nudge is accepted at once */
  let c = Coach(fast: false); var t = 0.0
  func run(_ label: String, minutes: Double, idle: Double = 1, hour: Double = 10, answer: (Kind) -> Void) {
    print("— \(label)"); let end = t + minutes*60
    while t < end { t += 1; if let k = c.update(now: t, dt: 1, idle: idle, hour: hour) { print(String(format: "   %5.1f min  %@", t/60, "\(k)")); answer(k) } } }
  run("working, every nudge taken", minutes: 95) { k in c.done(k, now: t) }
  run("working, every nudge put off", minutes: 40) { _ in c.later(now: t) }
  run("away for six minutes", minutes: 6, idle: 400) { _ in }
  run("back at work", minutes: 25) { k in c.done(k, now: t) }
  run("after midnight", minutes: 100, hour: 1.2) { k in if k == .late { c.later(now: t) } else { c.done(k, now: t) } }
  exit(0)
}

// MARK: - tears, a z, a heart fall out of the menu bar and down the screen

struct Bit { var kind: Int; var x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat; var age: CGFloat = 0; var life: CGFloat; var size: CGFloat }   /* kind: 0 tear, 1 z, 2 heart, 3 splash */
final class RainView: NSView {
  var bits: [Bit] = []
  override var isFlipped: Bool { true }
  override func draw(_ dirtyRect: NSRect) {
    guard let g = NSGraphicsContext.current?.cgContext else { return }
    for b in bits where b.age >= 0 {
      let a = max(0, min(1, (b.life - b.age)/0.35)); g.saveGState(); g.setAlpha(a)
      switch b.kind {
      case 1:
        NSAttributedString(string: "z", attributes: [.font: rounded(b.size*(1 + b.age*0.35), .heavy), .foregroundColor: NSColor.white.withAlphaComponent(a),
          .strokeColor: NSColor(white: 0.1, alpha: a), .strokeWidth: -5]).draw(at: CGPoint(x: b.x, y: b.y))
      case 2: drawHeart(g, at: CGPoint(x: b.x, y: b.y), r: b.size)
      default: drawDrop(g, at: CGPoint(x: b.x, y: b.y), r: b.size, color: FX_TEAR)
      }
      g.restoreGState()
    }
  }
}
/* a narrow see-through window under them, from the menu bar to the Dock. Clicks pass through it; it exists only while something is falling */
final class Rain {
  let win: NSWindow, view = RainView()
  var timer: Timer? = nil, floorY: CGFloat = 600
  init() {
    win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 140, height: 600), styleMask: .borderless, backing: .buffered, defer: true)
    win.isOpaque = false; win.backgroundColor = .clear; win.hasShadow = false; win.ignoresMouseEvents = true; win.level = .statusBar
    win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]; win.isReleasedWhenClosed = false
    win.contentView = view
  }
  func place(under item: NSRect, on screen: NSScreen) {
    let bottom = screen.visibleFrame.minY, top = min(item.minY, screen.visibleFrame.maxY)
    win.setFrame(NSRect(x: item.midX - 70, y: bottom, width: 140, height: max(60, top - bottom)), display: false); floorY = win.frame.height }
  func add(_ b: Bit) { view.bits.append(b)
    if timer == nil { win.orderFrontRegardless()
      let t = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in self?.step(1.0/60) }; RunLoop.main.add(t, forMode: .common); timer = t } }
  func step(_ dt: CGFloat) {
    var out: [Bit] = []
    for var b in view.bits { b.age += dt
      if b.age < 0 { out.append(b); continue }
      switch b.kind {
      case 0: b.vy += TEARS.gravity*dt; b.y += b.vy*dt
        if b.y >= floorY - 3 {
          for k in -1...1 { out.append(Bit(kind: 3, x: b.x, y: floorY - 4, vx: CGFloat(k)*70 + CGFloat.random(in: -20...20), vy: -CGFloat.random(in: 150...230), life: 0.5, size: b.size*0.42)) }
          continue }
      case 3: b.vy += 1100*dt; b.x += b.vx*dt; b.y += b.vy*dt
      default: b.x += b.vx*dt + sin(b.age*4)*0.25; b.y += b.vy*dt
      }
      if b.age < b.life { out.append(b) } }
    view.bits = out; view.needsDisplay = true
    if out.isEmpty { timer?.invalidate(); timer = nil; win.orderOut(nil) }
  }
}

// MARK: - living in the menu bar

final class EyesView: NSView {
  var look = FaceLook(), who: Who? = nil
  override var isFlipped: Bool { true }
  override func hitTest(_ point: NSPoint) -> NSView? { nil }      /* clicks go to the menu-bar button */
  /* as tall as the system's own glyphs (about 16 pt), centred, not the whole height of the bar */
  static let eyeH: CGFloat = 16
  override func draw(_ dirtyRect: NSRect) { guard let g = NSGraphicsContext.current?.cgContext else { return }
    let h = min(EyesView.eyeH, bounds.height - 3), w = h*2.22
    drawFace(g, in: CGRect(x: bounds.midX - w/2, y: bounds.midY - h/2, width: w, height: h), look: look, who: who) }
}

/* the camera notch of a screen, in screen coordinates (y up); nil where there is none */
func notchRect(_ s: NSScreen) -> CGRect? {
  guard #available(macOS 12, *), s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea else { return nil }
  let nw = s.frame.width - l.width - r.width
  guard nw > 40, nw < s.frame.width/2 else { return nil }
  return CGRect(x: s.frame.minX + l.width, y: s.frame.maxY - s.safeAreaInsets.top, width: nw, height: s.safeAreaInsets.top)
}

// MARK: - the Playground: every reaction on a button, big and at real size, on a dark and a light bar

final class Btn: NSButton { var run: () -> Void = {}
  convenience init(_ t: String, _ f: @escaping () -> Void) { self.init(title: t, target: nil, action: nil); run = f; target = self; action = #selector(go); bezelStyle = .rounded }
  @objc func go() { run() } }

final class PlaygroundView: NSView {
  var look = FaceLook(), who: Who? = nil
  override var isFlipped: Bool { true }
  /* only where the faces are */
  func refresh() { let W = bounds.width
    setNeedsDisplay(NSRect(x: W/2 - 170, y: 0, width: 340, height: 300)); setNeedsDisplay(NSRect(x: W/2 - 100, y: 300, width: 70, height: 102)) }
  override func draw(_ dirtyRect: NSRect) { guard let g = NSGraphicsContext.current?.cgContext else { return }
    let W = bounds.width
    g.setFillColor(rgb(0.1, 0.1, 0.11)); g.fill(bounds)
    /* big: the drawing, on a dark and on a light bar */
    for (k, darkBar) in [true, false].enumerated() {
      let r = CGRect(x: 0, y: CGFloat(k)*150, width: W, height: 150)
      g.setFillColor(darkBar ? rgb(0.15, 0.15, 0.17) : rgb(0.91, 0.91, 0.93)); g.fill(r)
      let fh: CGFloat = 92, fw = fh*2.22
      drawFace(g, in: CGRect(x: r.midX - fw/2, y: r.midY - fh/2, width: fw, height: fh), look: look, who: who, ink: darkBar ? rgb(1, 1, 1) : rgb(0, 0, 0, 0.85), dark: darkBar) }
    /* real size: a dark bar, glass over a blue wallpaper (like his), a light bar */
    let bars: [(CGColor, Bool)] = [(rgb(0.15, 0.15, 0.17), true), (rgb(0.34, 0.42, 0.58), true), (rgb(0.91, 0.91, 0.93), false)]
    for (k, b) in bars.enumerated() {
      let r = CGRect(x: 0, y: 300 + CGFloat(k)*34, width: W, height: 34)
      g.setFillColor(b.0); g.fill(r)
      let ink = b.1 ? rgb(1, 1, 1) : rgb(0, 0, 0, 0.85), eh = EyesView.eyeH, fw = eh*2.22
      var x = W/2 - 80
      drawFace(g, in: CGRect(x: x, y: r.midY - eh/2, width: fw, height: eh), look: look, who: who, ink: ink, dark: b.1); x += fw + 22
      g.setStrokeColor(ink); g.setLineWidth(1.6); g.strokeEllipse(in: CGRect(x: x, y: r.midY - 8, width: 16, height: 16)); x += 34
      for rr in [CGFloat(4), 8, 12] { g.beginPath(); g.addArc(center: CGPoint(x: x + 12, y: r.midY + 6), radius: rr, startAngle: -.pi*0.78, endAngle: -.pi*0.22, clockwise: false); g.strokePath() }
      x += 40; g.stroke(CGRect(x: x, y: r.midY - 6, width: 24, height: 12)) }
  }
}

final class Playground {
  let win: NSPanel, view = PlaygroundView()
  var steps: [DispatchWorkItem] = []
  init(_ app: App) {
    let W: CGFloat = 640, H: CGFloat = 402 + 136
    win = NSPanel(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
    win.title = "Roomie Playground"; win.isReleasedWhenClosed = false; win.appearance = NSAppearance(named: .darkAqua); win.level = .floating
    let root = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H)); win.contentView = root
    view.frame = NSRect(x: 0, y: 136, width: W, height: 402); root.addSubview(view)
    /* plain 8-bit sRGB: the default wide 16-bit backing made every frame cost half a core */
    win.colorSpace = .sRGB; view.wantsLayer = true; view.layerContentsRedrawPolicy = .onSetNeedsDisplay; view.layer?.contentsFormat = .RGBA8Uint
    let now = { CACurrentMediaTime() }
    let acts: [(String, () -> Void)] = [
      ("Hearts", { app.brain.love(now()); app.say(.back, now: now()) }),
      ("Poke", { app.brain.poke(now()) }),
      ("Cry", { let t = now(); for _ in 0..<3 { app.brain.poke(t) } }),
      ("Dizzy", { app.brain.dizzy = 1.7 }),
      ("Sweat", { app.brain.demoHotUntil = now() + 5; app.say(.hot, now: now()) }),
      ("Low battery", { app.brain.demoHungryUntil = now() + 5; app.say(.battery, now: now()) }),
      ("Sleep, wake", { app.brain.demoSleepUntil = now() + 4 }),
      ("Nudge", { app.demoNudge() }),
      ("Caught", { app.caught(now()) }),
      ("Dance", { app.demoDance() })]
    /* buttons in rows that wrap, so none is cut off at the window's edge */
    func row(_ items: [NSControl], y: CGFloat) { var x: CGFloat = 12, yy = y
      for v in items { v.sizeToFit(); if x + v.frame.width > W - 12 { x = 12; yy -= 38 }
        v.frame.origin = CGPoint(x: x, y: yy); root.addSubview(v); x += v.frame.width + 6 } }
    row(acts.map { a in Btn(a.0) { [weak self] in self?.stop(); a.1(); app.wake() } }, y: 92)
    let play = Btn("▶ Play all") { [weak self] in self?.playAll(app, acts) }
    let madam = Btn("Madam") { if app.who != .madam { app.choose(.madam) } }, gent = Btn("Gentleman") { if app.who != .gentleman { app.choose(.gentleman) } }
    let note = NSTextField(labelWithString: "Falling tears and the nudge show under your real menu bar.")
    note.textColor = .secondaryLabelColor; note.font = .systemFont(ofSize: 11)
    row([play, madam, gent, note], y: 14)
    win.center()
  }
  func show() { NSApp.activate(ignoringOtherApps: true); win.makeKeyAndOrderFront(nil) }
  var visible: Bool { win.isVisible }
  func stop() { steps.forEach { $0.cancel() }; steps = [] }
  func playAll(_ app: App, _ acts: [(String, () -> Void)]) {
    stop()
    let gaps: [Double] = [3, 1.6, 6.5, 5, 5.5, 5.5, 8, 9, 12, 15]                /* how long each one is given before the next */
    var at = 0.0
    for (i, a) in acts.enumerated() {
      let w = DispatchWorkItem { a.1(); app.wake() }; steps.append(w)
      DispatchQueue.main.asyncAfter(deadline: .now() + at, execute: w); at += gaps[i] }
  }
}

final class App: NSObject, NSApplicationDelegate {
  var item: NSStatusItem!, view = EyesView(), brain = Brain(), coach = Coach(fast: FAST), island = Island(), rain = Rain()
  var who: Who? = Who(rawValue: defaults.string(forKey: "who") ?? "") { didSet { view.who = who; island.who = who; lastSig = [] } }
  var last = CACurrentMediaTime(), coachLast = CACurrentMediaTime(), lastMouse = NSEvent.mouseLocation, sign = 0.0, reversals: [Double] = [], clicks: [Double] = []
  var movedAt = 0.0, lastSig: [Int] = [], dropAt = 0.0, dropLeft = true, lastImgAt = 0.0
  /* 0.9: the face is a layer inside the status button; swapping its contents is cheap, setting the button's image every frame cost a twelfth of a core */
  let faceLayer = CALayer(); var lastDark = true
  var signals: [DispatchSourceSignal] = []
  lazy var playground = Playground(self)
  var pgSig: [Int] = []
  func wake() { movedAt = CACurrentMediaTime() }
  /* the Playground's nudge: the pill shows, opens a moment later, and closes without touching the real schedule */
  func demoNudge() {
    let now = CACurrentMediaTime(), was = coach.pending
    coach.pending = .eyes; island.kind = .eyes; openCard(); _ = now
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in guard let s = self, s.island.phase == .open else { return }
      s.coach.pending = was; s.island.go(.hidden, now: CACurrentMediaTime()) } }
  @objc func openPlayground() { playground.show() }
  var cpuPrev: (UInt32, UInt32, UInt32, UInt32)? = nil, hotCount = 0, isHot = false, battery: Double? = nil, charging = true
  /* manners: on a call or in full screen they keep counting but say nothing; the quiet hour is the user's own */
  var busyElsewhere = false, quietUntil: Date? = nil, lastDim = false, lastTele: [Int] = []
  var quiet: Bool { busyElsewhere || (quietUntil.map { Date() < $0 } ?? false) }
  /* 0.9: music. They dance in their own way when a player says a song is on; to the beat if asked to listen */
  let music = Music(), tracker = BeatTracker()
  var danceMode = DanceMode(rawValue: defaults.string(forKey: "dance") ?? "") ?? .own
  var ear: AnyObject? = nil, earTriedAt = -1e9, outAt = -1e9, outCheck = -1e9, outLat = 0.0
  var demoDanceAt = -1e9, demoDanceUntil = -1e9, lastMusicSay = -1e9
  var earRunning: Bool { if #available(macOS 14.2, *) { return (ear as? SystemEar)?.running ?? false }; return false }
  @discardableResult func listen(_ on: Bool) -> Bool {
    guard #available(macOS 14.2, *) else { return false }
    if !on { (ear as? SystemEar)?.stop(); tracker.reset(); return true }
    let e = (ear as? SystemEar) ?? SystemEar(); ear = e; earTriedAt = CACurrentMediaTime(); let ok = e.start()
    if LOG { FileHandle.standardError.write("ear \(ok ? "listening" : "failed")\n".data(using: .utf8)!) }
    return ok }
  /* where the beat is now, if a song is on and they may dance */
  var hearing = false, clockBeat = 0.0, clockPeriod = 0.5, clockSure = 0.0, clockAt = -1e9
  func rawBeat(_ now: Double) -> (Double, Double, Double)? {
    if now < demoDanceUntil { let len = 60.0/112; return ((now - demoDanceAt)/len, 1, len) }
    guard danceMode != .off, who != nil, now - outAt < 3, !busyElsewhere else { hearing = false; return nil }
    /* a song heard in the sound: start when fairly sure, keep going until really unsure, so the dance doesn't flicker */
    hearing = danceMode == .beat && earRunning && tracker.conf > (hearing ? 0.18 : 0.4)
    guard music.playing || hearing else { return nil }
    if hearing { return (tracker.beat(now), sm(0.25, 0.65, tracker.conf), tracker.period) }
    return (now*1.55, 0, 1/1.55) }
  /* the dance's own clock: it never jumps; it glides towards the tempo and the phase it hears (the tracker re-locks now and then) */
  func beatNow(_ now: Double) -> (Double, Double, Double)? {
    guard let r = rawBeat(now) else { return nil }
    let dt = min(0.1, now - clockAt); clockAt = now
    if dt <= 0 || dt >= 0.1 { clockBeat = brain.danceBeat; clockPeriod = r.2; clockSure = r.1 }      /* (re)starting: carry on from where the dance is */
    clockPeriod += (r.2 - clockPeriod)*min(1, dt*1.5)
    clockBeat += dt/max(0.25, clockPeriod)
    var err = (r.0 - clockBeat).truncatingRemainder(dividingBy: 1); if err > 0.5 { err -= 1 } else if err < -0.5 { err += 1 }
    clockBeat += err*min(1, dt*2.5)
    clockSure += (r.1 - clockSure)*min(1, dt*2)
    return (clockBeat, clockSure, clockPeriod) }
  /* a song comes on after three quiet minutes (from a player or heard in the sound): one light line, at most every 20 minutes */
  var songAt: Double? = nil, songEnd = -1e9
  func song(_ on: Bool, now: Double) {
    if on && songAt == nil { songAt = now
      if now - songEnd > 180 && now - lastMusicSay > 20*60 && now >= demoDanceUntil, let w = who {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in guard let s = self, s.songAt != nil else { return }
          if s.say(.music, now: CACurrentMediaTime(), text: Lines.music(w, artist: s.music.playing ? s.music.artist : nil)) { s.lastMusicSay = now } } } }
    else if !on && songAt != nil { songAt = nil; songEnd = now } }
  func demoDance() { let now = CACurrentMediaTime(); demoDanceAt = now; demoDanceUntil = now + 14; wake()
    if let w = who { say(.music, now: now, text: Lines.music(w, artist: nil)) } }

  func applicationDidFinishLaunching(_ n: Notification) {
    if CommandLine.arguments.contains("--playground") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.playground.show() } }
    /* for trying effects by hand: `pkill -USR1 Roomie` shows the hearts, `-USR2` makes them cry, `-INFO` shows a nudge */
    for (sig, act) in [(SIGUSR1, { [weak self] in guard let s = self else { return }; s.brain.love(CACurrentMediaTime()); s.movedAt = CACurrentMediaTime() }),
                       (SIGUSR2, { [weak self] in guard let s = self else { return }; let t = CACurrentMediaTime(); for _ in 0..<3 { s.brain.poke(t) }; s.movedAt = t }),
                       (SIGINFO, { [weak self] in self?.demoNudge(); self?.wake() }),
                       (SIGHUP, { [weak self] in self?.caught(CACurrentMediaTime()) })] as [(Int32, () -> Void)] {
      signal(sig, SIG_IGN); let src = DispatchSource.makeSignalSource(signal: sig, queue: .main); src.setEventHandler(handler: act); src.resume(); signals.append(src) }
    let h = NSStatusBar.system.thickness
    item = NSStatusBar.system.statusItem(withLength: EyesView.eyeH*2.22 + 10); _ = h
    if let b = item.button { b.imagePosition = .imageOnly; b.toolTip = "Roomie"
      b.wantsLayer = true; faceLayer.frame = b.bounds; faceLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
      faceLayer.contentsGravity = .center; faceLayer.contentsScale = b.window?.backingScaleFactor ?? 2; b.layer?.addSublayer(faceLayer)
      b.target = self; b.action = #selector(clicked); b.sendAction(on: [.leftMouseUp, .rightMouseUp]) }
    view.who = who; island.who = who
    island.onOpen = { [weak self] in self?.openCard() }
    island.onButton = { [weak self] i in self?.answer(i) }
    island.onChoose = { [weak self] w in self?.choose(w) }
    island.onCounted = { [weak self] in guard let s = self, let w = s.who else { return }
      let now = CACurrentMediaTime(); s.coach.done(.eyes, now: now); s.island.go(.message, note: Lines.eyesDone(w), now: now); s.cheer(now); s.brain.love(now + 0.2)
      if !s.busyElsewhere { NSSound(named: "Glass")?.play() } }
    readSlow()
    NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in self?.clicks.append(CACurrentMediaTime()) }
    let tick = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in self?.tick() }; tick.tolerance = 0; RunLoop.main.add(tick, forMode: .common)
    let slow = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.readSlow() }; RunLoop.main.add(slow, forMode: .common)
    /* the first time, they ask who moves in */
    if who == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.island.go(.choose, now: CACurrentMediaTime()) } }
  }

  // ---- talking
  func openCard() { guard let w = who, let k = coach.pending else { return }
    island.go(.open, card: Lines.card(k, w), now: CACurrentMediaTime()) }
  func answer(_ i: Int) {
    guard let w = who, let c = island.card else { return }
    let now = CACurrentMediaTime()
    switch (c.kind, i) {
    case (.eyes, 0): island.go(.counting, note: Lines.counting(w), now: now)
    case (.move, 0): coach.done(.move, now: now); island.go(.message, note: Lines.moveGo(w), now: now); cheer(now); walkAt = now
    case (.late, 0): coach.goodNight(now: now); island.go(.message, note: Lines.night(w), now: now); cheer(now)
    default: coach.later(now: now); island.go(.message, note: Lines.later(w), now: now)
    }
  }
  func choose(_ w: Who) { who = w; defaults.set(w.rawValue, forKey: "who")
    let now = CACurrentMediaTime(); island.go(.message, note: Lines.card(.hello, w).text, now: now); island.messageEnd = now + 5; cheer(now); brain.love(now + 0.6) }
  /* pleased with you: stars out of the face in the card, and twinkles round the eyes in the bar */
  /* a passing remark from the notch, for the rare moments: not on calls, not in the quiet hour, never over a nudge, at most every two minutes */
  var lastSay = -1e9, lastCry = 0.0, wasDizzy = false, saidBattery = false, lastHot = -1e9, wasHot = false
  @discardableResult func say(_ r: Reaction, now: Double, text: String? = nil) -> Bool {
    guard let w = who, island.phase == .hidden, !quiet, now - lastSay > (playground.visible ? 3 : 120) else { return false }
    lastSay = now; island.go(.say, note: text ?? Lines.react(r, w), now: now); return true }
  func reactions(now: Double) {
    if brain.cameBack { say(.back, now: now) }
    if brain.cryUntil > lastCry + 0.5 && brain.cryUntil > now { lastCry = brain.cryUntil; say(.cry, now: now) }
    let dz = brain.dizzy > 0.9; if dz && !wasDizzy { say(.dizzy, now: now) }; wasDizzy = dz
    if let b = battery, !charging { if b < 15 && !saidBattery { saidBattery = true; say(.battery, now: now) } } else { saidBattery = false }
    if isHot && !wasHot && now - lastHot > 1800 { lastHot = now; say(.hot, now: now) }; wasHot = isHot
  }
  func cheer(_ now: Double) { island.burst(now + 0.25); brain.sparkleUntil = now + 3; wake() }
  /* "Going," and two and a half minutes later still at the Mac, never away for 40 seconds: caught.
     They narrow their eyes and follow you, then say one dry line. The walk is not asked again any sooner. */
  var walkAt: Double? = nil
  func watchWalk(now: Double, idle: Double) {
    guard let at = walkAt else { return }
    if idle > 40 { walkAt = nil; return }                                   /* they went */
    if now - at > max(12, 150*coach.k) && island.phase == .hidden { walkAt = nil; caught(now) }
  }
  func caught(_ now: Double) {
    guard let w = who, island.phase == .hidden else { return }
    brain.suspectUntil = now + CAUGHT_FOR; wake()
    island.go(.caught, note: Lines.caught(w), now: now)
  }

  // ---- the button: a left click opens what they have to say, or pokes them; a right click is the menu
  @objc func clicked() {
    let e = NSApp.currentEvent
    if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true { showMenu(); return }
    let now = CACurrentMediaTime()
    if who == nil { island.go(.choose, now: now); return }
    if island.phase == .hint { openCard(); return }
    if island.phase == .open || island.phase == .message { return }
    brain.poke(now)
  }
  func showMenu() {
    let m = NSMenu()
    for (title, w) in [("Madam lives here", Who.madam), ("The Gentleman lives here", .gentleman)] {
      let it = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: ""); it.target = self; it.representedObject = w.rawValue
      it.state = who == w ? .on : .off; m.addItem(it) }
    m.addItem(.separator())
    let qt: String = { if let u = quietUntil, Date() < u { return "Quiet until \(clockText(u))" }; return "Quiet for an Hour" }()
    /* Nudges: how much care, for good; Quiet below is just for now */
    let nm = NSMenuItem(title: "Nudges", action: nil, keyEquivalent: ""), sub = NSMenu()
    for (title, mode) in [("All", NudgeMode.all), ("Only Walks and Bed", .fewer), ("None, Just Company", .none)] {
      let it = NSMenuItem(title: title, action: #selector(pickNudges(_:)), keyEquivalent: ""); it.target = self; it.representedObject = mode.rawValue
      it.state = coach.mode == mode ? .on : .off; sub.addItem(it) }
    nm.submenu = sub; m.addItem(nm)
    /* Dancing: in their own way needs nothing; to the beat asks macOS once to let them hear the sound */
    let dm = NSMenuItem(title: "Dancing", action: nil, keyEquivalent: ""), dsub = NSMenu()
    var modes: [(String, DanceMode)] = [("In Their Own Way", .own), ("Off", .off)]
    if #available(macOS 14.2, *) { modes.insert(("To the Beat", .beat), at: 0) }
    for (title, mode) in modes {
      let it = NSMenuItem(title: title, action: #selector(pickDance(_:)), keyEquivalent: ""); it.target = self; it.representedObject = mode.rawValue
      it.state = danceMode == mode ? .on : .off; dsub.addItem(it) }
    dm.submenu = dsub; m.addItem(dm)
    let qi = NSMenuItem(title: qt, action: #selector(toggleQuiet), keyEquivalent: ""); qi.target = self
    qi.state = quietUntil.map { Date() < $0 } == true ? .on : .off; m.addItem(qi)
    let pg = NSMenuItem(title: "Playground…", action: #selector(openPlayground), keyEquivalent: ""); pg.target = self; m.addItem(pg)
    let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: ""); login.target = self
    login.state = SMAppService.mainApp.status == .enabled ? .on : .off; m.addItem(login)
    m.addItem(.separator())
    let q = NSMenuItem(title: "Quit Roomie", action: #selector(quit), keyEquivalent: "q"); q.target = self; m.addItem(q)
    item.menu = m; item.button?.performClick(nil); item.menu = nil
  }
  @objc func pickNudges(_ s: NSMenuItem) {
    guard let r = s.representedObject as? String, let m = NudgeMode(rawValue: r) else { return }
    coach.mode = m; defaults.set(r, forKey: "nudges")
    /* a card about something now switched off folds away */
    if island.phase == .open, let k = island.card?.kind, m == .none || (m == .fewer && k == .eyes) { coach.later(now: CACurrentMediaTime()); island.go(.hidden, now: CACurrentMediaTime()) }
  }
  @objc func pickDance(_ s: NSMenuItem) {
    guard let r = s.representedObject as? String, let m = DanceMode(rawValue: r) else { return }
    danceMode = m; defaults.set(r, forKey: "dance")
    if m == .beat { if !listen(true) { danceMode = .own; defaults.set(DanceMode.own.rawValue, forKey: "dance")
        let a = NSAlert(); a.messageText = "Roomie can't hear the music."
        a.informativeText = "To dance to the beat, let Roomie hear your Mac's sound: System Settings > Privacy & Security > Screen & System Audio Recording > System Audio Recording Only > Roomie.\n\nUntil then they dance in their own way."
        NSApp.activate(ignoringOtherApps: true); a.runModal() } }
    else { listen(false) } }
  @objc func toggleQuiet() { if let u = quietUntil, Date() < u { quietUntil = nil } else { quietUntil = Date().addingTimeInterval(3600) } }
  @objc func pick(_ s: NSMenuItem) { if let r = s.representedObject as? String, let w = Who(rawValue: r), w != who { choose(w) } }
  @objc func toggleLogin() {
    do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } }
    catch { let a = NSAlert(); a.messageText = "Roomie couldn't change this."
      a.informativeText = "Add him by hand: System Settings > General > Login Items > the + under Open at Login > Roomie.\n\n\(error.localizedDescription)"; a.runModal() } }
  @objc func quit() { NSApp.terminate(nil) }

  // ---- what they read
  func readSlow() {
    busyElsewhere = micInUse() || frontIsFullScreen()
    outLat = outputLatency()
    battery = nil
    let snap = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    for ps in IOPSCopyPowerSourcesList(snap).takeRetainedValue() as [CFTypeRef] {
      if let d = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any],
         let cur = d[kIOPSCurrentCapacityKey] as? Int, let mx = d[kIOPSMaxCapacityKey] as? Int, mx > 0 {
        battery = Double(cur)/Double(mx)*100; charging = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue } }
    if battery == nil { charging = true }
    var info = host_cpu_load_info(); var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride)
    let kr = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) } }
    var load = 0.0
    if kr == KERN_SUCCESS { let t = info.cpu_ticks
      if let p = cpuPrev { let u = Double(t.0 &- p.0), sy = Double(t.1 &- p.1), id = Double(t.2 &- p.2), ni = Double(t.3 &- p.3), all = u + sy + id + ni; if all > 0 { load = (u + sy + ni)/all } }
      cpuPrev = t }
    hotCount = load > 0.85 ? hotCount + 1 : 0
    isHot = hotCount >= 4 || ProcessInfo.processInfo.thermalState.rawValue >= 2
  }
  func heart(delay: CGFloat) { guard let w = item.button?.window, let scr = w.screen ?? NSScreen.main else { return }
    rain.place(under: w.frame, on: scr); rain.add(Bit(kind: 2, x: 70, y: 8, vx: 0, vy: 34, age: -delay, life: 2.4, size: 7)) }

  func tick() {
    let now = CACurrentMediaTime(), here = NSEvent.mouseLocation
    let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    /* the rules run on the wall clock, whatever the drawing does */
    let cdt = now - coachLast; coachLast = now
    let d = Date(), c = Calendar.current.dateComponents([.hour, .minute], from: d), hour = Double(c.hour ?? 12) + Double(c.minute ?? 0)/60
    if who != nil && island.phase == .hidden, let due = coach.update(now: now, dt: cdt, idle: FAST ? 0 : idle, hour: hour, hold: quiet) { island.kind = due; openCard() }
    /* a call starts, or a film goes full screen, while a card is out: it slips away and they ask later */
    if busyElsewhere && island.phase == .open && island.card?.kind != .hello { coach.later(now: now); island.go(.hidden, now: now) }
    /* 0.7: a nudge opens straight into its card (he found the small pill with a symbol a riddle).
       Left unanswered for two minutes, it folds quietly back into the notch and they try again later */
    if island.phase == .open && island.card?.kind != .hello && now - island.since > 120*coach.k { coach.later(now: now); island.go(.hidden, now: now) }
    watchWalk(now: now, idle: FAST ? 0 : idle)
    if let w = item.button?.window, let scr = w.screen ?? NSScreen.main { island.place(x: w.frame.midX, top: min(w.frame.minY, scr.visibleFrame.maxY), notch: notchRect(scr)) }
    if hypot(here.x - lastMouse.x, here.y - lastMouse.y) > 0.5 { movedAt = now }
    /* music: is sound going out (once a second), and, when asked to listen, where its beat is */
    if now - outCheck > 1 { outCheck = now; if outputRunning() { outAt = now } }
    if danceMode == .beat {
      let sounding = now - outAt < 15
      if sounding && !earRunning && now - earTriedAt > 30 { listen(true) } else if !sounding && earRunning { listen(false) }
      if #available(macOS 14.2, *), now - outAt < 3, let e = ear as? SystemEar, e.running { tracker.feed(e.latest(1024), rate: e.rate, t: now + outLat) } }
    let bn = beatNow(now); song(bn != nil, now: now)
    if LOG && Int(now) != Int(now - 1.0/60) { FileHandle.standardError.write("ear \(earRunning ? "on" : "off") conf \(String(format: "%.2f bpm %.0f", tracker.conf, 60/tracker.period)) out \(now - outAt < 3) | dance \(bn.map { String(format: "beat %.1f sure %.2f", $0.0, $0.1) } ?? "none") amt \(String(format: "%.2f", brain.danceAmt))\n".data(using: .utf8)!) }
    let pgOn = playground.visible
    if now - movedAt > 1.2 && !brain.busy(now) && bn == nil && !island.animating && now - island.leftAt > 0.8 && !pgOn && now - last < 0.25 { return }
    let dt = min(0.05, now - last); last = now
    var s = Senses()
    s.idle = idle; s.hour = hour; s.battery = battery; s.charging = charging; s.hot = isHot
    if let b = bn { s.beat = b.0; s.beatSure = b.1; s.beatLen = b.2 }
    if let w = item.button?.window { let f = w.frame, dx = here.x - f.midX, dy = f.midY - here.y, dist = max(1, hypot(dx, dy)), k = min(1, dist/420)
      s.gaze = CGPoint(x: dx/dist*k, y: dy/dist*k) }
    if island.showing, let w = item.button?.window { let c = island.center, dx = c.x - w.frame.midX, dy = w.frame.midY - c.y, d = max(1, hypot(dx, dy))
      s.islandDir = CGPoint(x: dx/d, y: dy/d) }
    let vx = Double(here.x - lastMouse.x)/max(0.001, dt); lastMouse = here
    let sg = abs(vx) > 1300 ? (vx > 0 ? 1.0 : -1.0) : 0
    if sg != 0 && sg != sign { if sign != 0 { reversals.append(now) }; sign = sg }
    reversals = reversals.filter { now - $0 < 0.9 }
    if reversals.count >= 4 && sg != 0 { s.shake = 0.07 }
    clicks = clicks.filter { now - $0 < 1.5 }
    if clicks.count >= 6 { s.rage = true; clicks.removeAll() }
    let attend: Attend
    switch island.phase { case .hint: attend = .hint(island.since); case .open, .message, .choose, .caught: attend = .card; case .counting: attend = .far; case .hidden, .say: attend = .none }
    let look = brain.step(now: now, dt: dt, s: s, who: who ?? .madam, attend: attend), sig = signature(look)
    var il = look; il.beat = nil; island.look = il                       /* no notes in the pill: they would sit on the words */
    /* on a display that is not the active one, the menu bar dims its icons; so do they */
    let dim: Bool = { guard NSScreen.screens.count > 1, let s = item.button?.window?.screen, let m = NSScreen.main else { return false }; return s != m }()
    /* teleport: while their face is in the island the bar is empty; they leave with a swell and a squeeze, come back with a pop */
    var tScale: CGFloat = 1, tSquash: CGFloat = 0, tPuff = -1.0
    func e3(_ u: Double) -> CGFloat { CGFloat(u < 0.5 ? 4*u*u*u : 1 - pow(-2*u + 2, 3)/2) }
    if island.hasFace { let u = now - island.arrivedAt
      if u < 0.05 { tScale = 1 + 0.08*e3(u/0.05) } else if u < 0.14 { let k = e3((u - 0.05)/0.09); tScale = 1.08*(1 - k); tSquash = k } else { tScale = 0 }
      if u >= 0.1 { tPuff = u - 0.1 } }
    else { let u = now - island.leftAt - 0.12
      if u < 0 { tScale = 0 } else if u < 0.6 { tScale = CGFloat(1 - exp(-9*u)*cos(12*u)); tPuff = u } }
    let tKey = [Int((tScale*40).rounded()), Int((tSquash*20).rounded()), tPuff >= 0 && tPuff < 0.35 ? Int(tPuff*30) : -1]
    /* dancing changes the face every frame; the menu bar gets it at most 30 times a second */
    let barDark = item.button.map { $0.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua } ?? true
    let danceThrottle = brain.danceAmt > 0.002 && now - lastImgAt < 1.0/60 && tKey == lastTele && dim == lastDim
    if !danceThrottle && (sig != lastSig || dim != lastDim || tKey != lastTele || barDark != lastDark) { lastSig = sig; lastDim = dim; lastTele = tKey; lastImgAt = now; lastDark = barDark
      let px = item.button?.window?.backingScaleFactor ?? 2
      CATransaction.begin(); CATransaction.setDisableActions(true)
      faceLayer.contentsScale = px; faceLayer.contents = glyphCG(look, who: who, dim: dim, scale: tScale, squash: tSquash, puff: tPuff, dark: barDark, px: px)
      CATransaction.commit() }
    /* the Playground is big: every frame, not only when the menu-bar picture changes */
    /* the Playground is big: it redraws on a four times finer step than the menu bar, and only when something moved */
    if pgOn { let fs = signature(look, fine: 4); if fs != pgSig { pgSig = fs; playground.view.look = look; playground.view.who = who; playground.view.refresh() } }
    reactions(now: now)
    if brain.cameBack { brain.cameBack = false }
    if brain.crying && !island.hasFace && now - dropAt > TEARS.every, let w = item.button?.window, let scr = w.screen ?? NSScreen.main {
      dropAt = now; dropLeft.toggle(); rain.place(under: w.frame, on: scr)
      rain.add(Bit(kind: 0, x: 70 + (dropLeft ? -1 : 1)*NSStatusBar.system.thickness*0.45, y: 0, vx: 0, vy: 30, life: 30, size: 4.5)) }
  }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
