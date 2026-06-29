import AppKit
import Foundation

// 사용법: swift icon_gen.swift <mark.png> <out.png> [size]
// github-mark.png(검정 마크, 투명)를 베이스로 "PR 리뷰" 앱 아이콘을 그린다.
//  - 둥근 사각형 + GitHub 다크 그라데이션 배경
//  - 중앙 흰색 Octocat 마크
//  - 우하단 초록 체크 배지(리뷰 승인 상징)

let args = CommandLine.arguments
guard args.count >= 3 else { fputs("usage: icon_gen.swift <mark.png> <out.png> [size]\n", stderr); exit(1) }
let markPath = args[1]
let outPath = args[2]
let size = args.count >= 4 ? (Int(args[3]) ?? 1024) : 1024
let S = CGFloat(size)

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("bitmap 생성 실패\n", stderr); exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let full = NSRect(x: 0, y: 0, width: S, height: S)

// 둥근 사각형 클립 + 그라데이션 배경
let radius = S * 0.225
NSBezierPath(roundedRect: full, xRadius: radius, yRadius: radius).addClip()
let topColor = NSColor(srgbRed: 0.20, green: 0.23, blue: 0.28, alpha: 1)   // 위(밝음)
let botColor = NSColor(srgbRed: 0.086, green: 0.105, blue: 0.133, alpha: 1) // 아래(어둠)
NSGradient(starting: botColor, ending: topColor)!.draw(in: full, angle: 90)

// 중앙 흰색 Octocat 마크
guard let mark = NSImage(contentsOfFile: markPath) else { fputs("마크 로드 실패: \(markPath)\n", stderr); exit(1) }
let mScale = S * 0.52
let mRect = NSRect(x: (S - mScale)/2, y: (S - mScale)/2 + S*0.045, width: mScale, height: mScale)
let whiteMark = NSImage(size: NSSize(width: mScale, height: mScale))
whiteMark.lockFocus()
let lb = NSRect(x: 0, y: 0, width: mScale, height: mScale)
mark.draw(in: lb)
NSColor.white.set()
lb.fill(using: .sourceAtop)   // 마크 알파 영역만 흰색으로
whiteMark.unlockFocus()
whiteMark.draw(in: mRect)

// 우하단 리뷰 배지: 어두운 외곽 링 + 초록 원 + 흰 체크
let bd = S * 0.34
let pad = S * 0.065
let bRect = NSRect(x: S - bd - pad, y: pad, width: bd, height: bd)
botColor.setFill()
NSBezierPath(ovalIn: bRect.insetBy(dx: -S*0.024, dy: -S*0.024)).fill()
NSColor(srgbRed: 0.18, green: 0.65, blue: 0.27, alpha: 1).setFill()   // GitHub green
NSBezierPath(ovalIn: bRect).fill()

let cx = bRect.midX, cy = bRect.midY, r = bd/2
let check = NSBezierPath()
check.move(to: NSPoint(x: cx - 0.30*r, y: cy + 0.02*r))
check.line(to: NSPoint(x: cx - 0.04*r, y: cy - 0.24*r))
check.line(to: NSPoint(x: cx + 0.36*r, y: cy + 0.30*r))
check.lineWidth = r * 0.20
check.lineCapStyle = .round
check.lineJoinStyle = .round
NSColor.white.setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fputs("png 인코딩 실패\n", stderr); exit(1) }
do { try png.write(to: URL(fileURLWithPath: outPath)); print("wrote \(outPath) (\(size)x\(size))") }
catch { fputs("쓰기 실패: \(error)\n", stderr); exit(1) }
