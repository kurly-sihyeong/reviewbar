import AppKit

// 사용법: swift pngprep.swift <src> <dst.png> <pointSize> <scale>
// 결과: (pointSize*scale)px 픽셀 + pointSize pt 크기 → @scale 로 선명하게(예: 18pt @2x = 36px, 144dpi)
let args = CommandLine.arguments
guard args.count >= 5, let point = Double(args[3]), let scale = Double(args[4]) else { print("USAGE"); exit(2) }
let srcPath = args[1], dstPath = args[2]
let px = Int((point * scale).rounded())

guard let img = NSImage(contentsOfFile: srcPath) else { print("LOAD_FAIL"); exit(1) }

guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { print("REP_FAIL"); exit(1) }
out.size = NSSize(width: px, height: px)   // 우선 픽셀 좌표로 그림
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.set()
NSBezierPath.fill(NSRect(x: 0, y: 0, width: px, height: px))
img.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

func a(_ x: Int, _ y: Int) -> Int { guard let c = out.colorAt(x: x, y: y) else { return -1 }; return Int((c.alphaComponent * 255).rounded()) }
var opaque = 0
for y in 0..<px { for x in 0..<px { if a(x, y) > 10 { opaque += 1 } } }
print("OUT \(px)x\(px) corners=[\(a(0,0)),\(a(px-1,0)),\(a(0,px-1)),\(a(px-1,px-1))] opaquePixels=\(opaque)")

out.size = NSSize(width: point, height: point)   // 144dpi 메타데이터(@2x) 기록
guard let png = out.representation(using: .png, properties: [:]) else { print("PNG_FAIL"); exit(1) }
do { try png.write(to: URL(fileURLWithPath: dstPath)); print("WROTE \(dstPath) (\(png.count)B)") }
catch { print("WRITE_FAIL \(error)"); exit(1) }
