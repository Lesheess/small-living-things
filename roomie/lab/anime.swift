/* Anime eyes, drawn in code: a lab for choosing the look before it goes into Roomie (2026-11-19).
   The owner's reference: a sheet of anime eyes (almond whites, a heavy upper lash line with a flick,
   a gradient iris, the lid's shadow on the iris, two highlights).
   Run: swiftc -O anime.swift -o anime && ./anime out.png */
import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func mixc(_ a: CGColor, _ b: CGColor, _ k: CGFloat) -> CGColor {
  let p = a.components!, q = b.components!; return rgb(p[0] + (q[0] - p[0])*k, p[1] + (q[1] - p[1])*k, p[2] + (q[2] - p[2])*k, 1) }

enum Pupil { case round, heart, rings }
struct Style {
  var name: String, female: Bool
  var dark: CGColor, mid: CGColor, light: CGColor
  var liner = rgb(0.07, 0.06, 0.09), accent: CGColor? = nil
  var ratio: CGFloat = 1.0                      /* how tall the eye is, to its half-width */
  var iris: CGFloat = 1.0
  var pupil: Pupil = .round
}

/* points on a cubic */
func cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
  let u = 1 - t; let a = u*u*u, b = 3*u*u*t, c = 3*u*t*t, d = t*t*t
  return CGPoint(x: a*p0.x + b*c1.x + c*c2.x + d*p1.x, y: a*p0.y + b*c1.y + c*c2.y + d*p1.y) }

struct Shape { var inner, outer, top1, top2, bot1, bot2: CGPoint }
func shape(_ a: CGFloat, _ s: Style) -> Shape {
  let h = a*s.ratio
  return s.female
    ? Shape(inner: CGPoint(x: -a, y: 0.14*h), outer: CGPoint(x: a, y: -0.02*h), top1: CGPoint(x: -0.62*a, y: -1.08*h), top2: CGPoint(x: 0.5*a, y: -1.02*h),
            bot1: CGPoint(x: 0.45*a, y: 0.9*h), bot2: CGPoint(x: -0.55*a, y: 0.98*h))
    : Shape(inner: CGPoint(x: -a, y: 0.06*h), outer: CGPoint(x: a, y: -0.08*h), top1: CGPoint(x: -0.5*a, y: -0.98*h), top2: CGPoint(x: 0.62*a, y: -0.9*h),
            bot1: CGPoint(x: 0.5*a, y: 0.78*h), bot2: CGPoint(x: -0.55*a, y: 0.86*h))
}

/* one eye, its outer corner on the right; the caller mirrors the left eye */
func drawEye(_ g: CGContext, _ s: Style, a: CGFloat, gaze: CGPoint, glintSide: CGFloat, closed: Bool, halo: Bool = false) {
  let sh = shape(a, s), h = a*s.ratio
  let thick = { (t: CGFloat) -> CGFloat in s.female ? a*(0.05 + 0.16*pow(t, 1.4)) : a*(0.11 + 0.07*t) }

  /* the heavy upper lash line: a band over the top of the eye, thin at the inner corner, thick at the outer, with a flick */
  func lashLine(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint) {
    var lower: [CGPoint] = [], upper: [CGPoint] = []
    let n = 40
    for i in 0...n { let t = CGFloat(i)/CGFloat(n), p = cubic(p0, c1, c2, p1, t)
      let q = cubic(p0, c1, c2, p1, min(1, t + 0.01)), r = cubic(p0, c1, c2, p1, max(0, t - 0.01))
      var nx = (q.y - r.y), ny = -(q.x - r.x); let L = max(0.0001, hypot(nx, ny)); nx /= L; ny /= L
      if ny > 0 { nx = -nx; ny = -ny }                                  /* the normal that points up, out of the eye */
      lower.append(p); upper.append(CGPoint(x: p.x + nx*thick(t), y: p.y + ny*thick(t))) }
    /* the flick past the outer corner */
    let end = lower.last!, endUp = upper.last!
    let flick = s.female ? [CGPoint(x: end.x + 0.36*a, y: end.y - 0.3*a), CGPoint(x: endUp.x - 0.02*a, y: endUp.y)]
                         : [CGPoint(x: end.x + 0.16*a, y: end.y - 0.04*a)]
    let path = CGMutablePath(); path.addLines(between: lower + flick + upper.reversed()); path.closeSubpath()
    if halo { g.addPath(path); g.setStrokeColor(rgb(1, 1, 1, 0.75)); g.setLineWidth(max(1, a*0.12)); g.setLineJoin(.round); g.strokePath() }
    g.addPath(path); g.setFillColor(s.liner); g.fillPath()
    if s.female {
      /* two lashes flaring off the outer end */
      for (t, len) in [(CGFloat(0.72), CGFloat(0.3)), (0.86, 0.36)] {
        let p = upper[Int(t*CGFloat(n))], ang: CGFloat = -0.55 - (t - 0.7)*1.2
        let tip = CGPoint(x: p.x + cos(ang)*len*a, y: p.y + sin(ang)*len*a)
        let lp = CGMutablePath(); lp.move(to: CGPoint(x: p.x - 0.06*a, y: p.y + 0.02*a))
        lp.addQuadCurve(to: tip, control: CGPoint(x: p.x + 0.02*a, y: p.y - 0.12*a)); lp.addLine(to: CGPoint(x: p.x + 0.07*a, y: p.y + 0.03*a)); lp.closeSubpath()
        g.addPath(lp); g.fillPath() } }
    if let acc = s.accent {
      /* a coloured line under the black one */
      let ap = CGMutablePath(); ap.addLines(between: lower.enumerated().map { i, p in let t = CGFloat(i)/CGFloat(n); return CGPoint(x: p.x, y: p.y + a*0.035*t) })
      g.addPath(ap); g.setStrokeColor(acc); g.setLineWidth(max(0.8, a*0.06)); g.setLineCap(.round); g.strokePath() }
  }

  if closed {
    /* glad: the lash line bends into an arch */
    lashLine(CGPoint(x: -0.85*a, y: 0.2*h), CGPoint(x: -0.45*a, y: -0.55*h), CGPoint(x: 0.4*a, y: -0.55*h), CGPoint(x: 0.88*a, y: 0.12*h)); return }

  let eye = CGMutablePath(); eye.move(to: sh.inner)
  eye.addCurve(to: sh.outer, control1: sh.top1, control2: sh.top2)
  eye.addCurve(to: sh.inner, control1: sh.bot1, control2: sh.bot2); eye.closeSubpath()
  g.saveGState(); g.addPath(eye); g.clip()
  g.setFillColor(rgb(1, 1, 1)); g.addPath(eye); g.fillPath()
  /* the iris */
  let rx = a*(s.female ? 0.5 : 0.44)*s.iris, ry = rx*(s.female ? 1.28 : 1.08)
  let ic = CGPoint(x: gaze.x*a*0.38, y: gaze.y*h*0.22 + h*0.04)
  let ir = CGRect(x: ic.x - rx, y: ic.y - ry, width: 2*rx, height: 2*ry)
  g.saveGState(); g.addEllipse(in: ir); g.clip()
  let cs = CGColorSpace(name: CGColorSpace.sRGB)!
  g.drawLinearGradient(CGGradient(colorsSpace: cs, colors: [s.dark, s.mid, s.light] as CFArray, locations: [0.05, 0.55, 1])!,
                       start: CGPoint(x: 0, y: ir.minY), end: CGPoint(x: 0, y: ir.maxY), options: [])
  /* a lighter crescent low in the iris, and the pupil */
  g.setFillColor(mixc(s.light, rgb(1, 1, 1), 0.3).copy(alpha: 0.55)!)
  g.fillEllipse(in: CGRect(x: ic.x - rx*0.7, y: ic.y + ry*0.25, width: rx*1.4, height: ry*0.9))
  let pc = CGPoint(x: ic.x, y: ic.y - ry*0.08), prx = rx*0.46, pry = ry*0.5
  let pupilColor = mixc(s.dark, rgb(0, 0, 0), 0.55)
  switch s.pupil {
  case .round: g.setFillColor(pupilColor); g.fillEllipse(in: CGRect(x: pc.x - prx, y: pc.y - pry, width: 2*prx, height: 2*pry))
  case .heart:
    let r = prx*1.05; g.saveGState(); g.translateBy(x: pc.x, y: pc.y)
    let hp = CGMutablePath(); hp.move(to: CGPoint(x: 0, y: r*0.95))
    hp.addCurve(to: CGPoint(x: -r, y: -r*0.2), control1: CGPoint(x: -r*0.6, y: r*0.55), control2: CGPoint(x: -r, y: r*0.25))
    hp.addArc(center: CGPoint(x: -r*0.5, y: -r*0.25), radius: r*0.5, startAngle: .pi, endAngle: 0, clockwise: false)
    hp.addArc(center: CGPoint(x: r*0.5, y: -r*0.25), radius: r*0.5, startAngle: .pi, endAngle: 0, clockwise: false)
    hp.addCurve(to: CGPoint(x: 0, y: r*0.95), control1: CGPoint(x: r, y: r*0.25), control2: CGPoint(x: r*0.6, y: r*0.55))
    g.addPath(hp); g.setFillColor(pupilColor); g.fillPath(); g.restoreGState()
  case .rings:
    g.setStrokeColor(mixc(s.light, rgb(1, 1, 1), 0.5)); g.setLineWidth(max(0.6, rx*0.07))
    for k in [0.85, 0.6] as [CGFloat] { g.strokeEllipse(in: CGRect(x: ic.x - rx*k, y: ic.y - ry*k, width: 2*rx*k, height: 2*ry*k)) }
    g.setFillColor(pupilColor); g.fillEllipse(in: CGRect(x: pc.x - prx*0.7, y: pc.y - pry*0.7, width: 1.4*prx, height: 1.4*pry))
  }
  g.restoreGState()
  g.setStrokeColor(mixc(s.dark, rgb(0, 0, 0), 0.3)); g.setLineWidth(max(0.6, a*0.045)); g.strokeEllipse(in: ir)
  /* the shadow the lid throws over the top of the eye */
  let sg = CGGradient(colorsSpace: cs, colors: [rgb(0.1, 0.08, 0.2, 0.42), rgb(0.1, 0.08, 0.2, 0)] as CFArray, locations: [0, 1])!
  g.drawLinearGradient(sg, start: CGPoint(x: 0, y: -h*0.85), end: CGPoint(x: 0, y: -h*0.15), options: [])
  /* highlights: one big, one small, from the same light on both eyes */
  g.setFillColor(rgb(1, 1, 1))
  let bx = ic.x - glintSide*rx*0.38, by = ic.y - ry*0.42
  g.fillEllipse(in: CGRect(x: bx - rx*0.3, y: by - ry*0.22, width: rx*0.6, height: ry*0.44))
  let sx = ic.x + glintSide*rx*0.4, sy = ic.y + ry*0.32
  g.fillEllipse(in: CGRect(x: sx - rx*0.13, y: sy - rx*0.13, width: rx*0.26, height: rx*0.26))
  if s.female { g.fillEllipse(in: CGRect(x: bx + glintSide*rx*0.5 - rx*0.07, y: by - ry*0.1 - rx*0.07, width: rx*0.14, height: rx*0.14)) }
  g.restoreGState()
  /* a short lower lash at the outer corner */
  let lp = CGMutablePath(); var first = true
  for i in 0...12 { let t = CGFloat(i)/12*(s.female ? 0.3 : 0.2), p = cubic(sh.outer, sh.bot1, sh.bot2, sh.inner, t)
    if first { lp.move(to: p); first = false } else { lp.addLine(to: p) } }
  g.addPath(lp); g.setStrokeColor(s.liner.copy(alpha: 0.7)!); g.setLineWidth(max(0.6, a*0.04)); g.setLineCap(.round); g.strokePath()
  lashLine(sh.inner, sh.top1, sh.top2, sh.outer)
}

/* a pair: the left eye is the right one mirrored, the light comes from the same side for both */
func drawPair(_ g: CGContext, _ s: Style, centre c: CGPoint, a: CGFloat, gaze: CGPoint, closed: Bool = false, halo: Bool = false) {
  let gap = a*(s.female ? 0.5 : 0.42)
  for right in [false, true] {
    g.saveGState(); g.translateBy(x: c.x + (right ? 1 : -1)*(a + gap/2), y: c.y)
    if !right { g.scaleBy(x: -1, y: 1) }
    drawEye(g, s, a: a, gaze: CGPoint(x: right ? gaze.x : -gaze.x, y: gaze.y), glintSide: right ? 1 : -1, closed: closed, halo: halo)
    g.restoreGState() }
}

func text(_ g: CGContext, _ s: String, x: CGFloat, y: CGFloat, w: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
  let p = NSMutableParagraphStyle(); p.alignment = .center
  let f = NSFont.systemFont(ofSize: size, weight: weight), font = f.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? f
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: g, flipped: true)
  NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p]).draw(in: CGRect(x: x, y: y, width: w, height: size*1.5))
  NSGraphicsContext.restoreGraphicsState() }

let styles: [Style] = [
  Style(name: "Madam · Violet", female: true, dark: rgb(0.22, 0.05, 0.42), mid: rgb(0.56, 0.25, 0.95), light: rgb(0.88, 0.72, 1)),
  Style(name: "Madam · Sky", female: true, dark: rgb(0.04, 0.1, 0.36), mid: rgb(0.16, 0.44, 0.95), light: rgb(0.6, 0.9, 1), accent: rgb(1, 0.42, 0.68)),
  Style(name: "Madam · Rose", female: true, dark: rgb(0.4, 0.02, 0.14), mid: rgb(0.92, 0.2, 0.42), light: rgb(1, 0.72, 0.78), pupil: .heart),
  Style(name: "Gentleman · Steel", female: false, dark: rgb(0.07, 0.11, 0.2), mid: rgb(0.3, 0.44, 0.62), light: rgb(0.72, 0.82, 0.92), ratio: 0.68),
  Style(name: "Gentleman · Emerald", female: false, dark: rgb(0.02, 0.2, 0.12), mid: rgb(0.08, 0.6, 0.36), light: rgb(0.62, 0.95, 0.72), ratio: 0.7),
  Style(name: "Gentleman · Ice", female: false, dark: rgb(0.02, 0.18, 0.26), mid: rgb(0.04, 0.66, 0.8), light: rgb(0.78, 1, 1), ratio: 0.72, pupil: .rings),
]

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "anime.png"
let cw: CGFloat = 460, ch: CGFloat = 400, cols = 3
let size = CGSize(width: cw*CGFloat(cols) + 40, height: ch*2 + 40)
let scale: CGFloat = 2
let g = CGContext(data: nil, width: Int(size.width*scale), height: Int(size.height*scale), bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
g.scaleBy(x: scale, y: scale); g.translateBy(x: 0, y: size.height); g.scaleBy(x: 1, y: -1)
g.setFillColor(rgb(0.95, 0.95, 0.96)); g.fill(CGRect(origin: .zero, size: size))
for (i, s) in styles.enumerated() {
  let x = 20 + cw*CGFloat(i % cols), y = 20 + ch*CGFloat(i/cols)
  g.setFillColor(rgb(1, 1, 1)); g.addPath(CGPath(roundedRect: CGRect(x: x + 8, y: y, width: cw - 16, height: ch - 20), cornerWidth: 22, cornerHeight: 22, transform: nil)); g.fillPath()
  text(g, s.name, x: x, y: y + 14, w: cw, size: 17, weight: .bold, color: .black)
  drawPair(g, s, centre: CGPoint(x: x + cw/2, y: y + 128), a: 82, gaze: CGPoint(x: 0.25, y: -0.05))
  /* in the menu bar, at its real size, light and dark */
  for (k, dark) in [false, true].enumerated() {
    let by = y + 232 + CGFloat(k)*44
    g.setFillColor(dark ? rgb(0.15, 0.16, 0.19) : rgb(0.88, 0.89, 0.91)); g.fill(CGRect(x: x + 8, y: by, width: cw - 16, height: 36))
    drawPair(g, s, centre: CGPoint(x: x + cw/2 - 60, y: by + 19), a: 10, gaze: CGPoint(x: 0.4, y: 0.1), halo: dark)
    drawPair(g, s, centre: CGPoint(x: x + cw/2 + 60, y: by + 20), a: 10, gaze: .zero, closed: true, halo: dark) }
  text(g, "in the menu bar: open · glad", x: x, y: y + 322, w: cw, size: 12, weight: .semibold, color: NSColor(white: 0.45, alpha: 1))
}
let rep = NSBitmapImageRep(cgImage: g.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
