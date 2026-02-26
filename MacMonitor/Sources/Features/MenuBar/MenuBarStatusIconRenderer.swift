import AppKit
import Foundation

enum MenuBarIconVariant: Hashable {
    case white
    case black
    case premiumGlass(ThermalState)
}

@MainActor
final class MenuBarStatusIconRenderer {
    static let shared = MenuBarStatusIconRenderer()

    private struct CacheKey: Hashable {
        let variant: MenuBarIconVariant
        let pixelSize: Int
    }

    private var cache: [CacheKey: NSImage] = [:]

    private init() {}

    func icon(for variant: MenuBarIconVariant, pointSize: CGFloat = 18) -> NSImage {
        let pixelSize = max(Int((pointSize * 2).rounded()), 18)
        let key = CacheKey(variant: variant, pixelSize: pixelSize)
        if let cached = cache[key] {
            return cached
        }

        let drawSize = CGSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize))
        let image = switch variant {
        case .white:
            drawMonochromeIcon(color: .white, size: drawSize)
        case .black:
            drawMonochromeIcon(color: .black, size: drawSize)
        case .premiumGlass(let thermalState):
            drawPremiumGlassIcon(thermalState: thermalState, size: drawSize)
        }

        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = false
        cache[key] = image
        return image
    }

    private func drawMonochromeIcon(color: NSColor, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            let center = CGPoint(x: rect.midX, y: rect.midY + size.height * 0.04)
            self.drawArc(
                context,
                center: center,
                radius: size.width * 0.40,
                startDegrees: 198,
                endDegrees: 342,
                width: size.width * 0.11,
                color: color
            )
            self.drawArc(
                context,
                center: center,
                radius: size.width * 0.28,
                startDegrees: 202,
                endDegrees: 338,
                width: size.width * 0.10,
                color: color.withAlphaComponent(0.95)
            )

            let chipRect = CGRect(
                x: size.width * 0.28,
                y: size.height * 0.20,
                width: size.width * 0.44,
                height: size.height * 0.30
            )
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(size.width * 0.065)
            context.addPath(
                CGPath(
                    roundedRect: chipRect,
                    cornerWidth: size.width * 0.08,
                    cornerHeight: size.width * 0.08,
                    transform: nil
                )
            )
            context.strokePath()

            let pinWidth = size.width * 0.04
            let pinHeight = size.height * 0.07
            let sidePinsY: [CGFloat] = [0.26, 0.36, 0.46].map { size.height * $0 }
            for y in sidePinsY {
                context.fill(CGRect(x: chipRect.minX - pinWidth * 1.8, y: y, width: pinWidth, height: pinHeight))
                context.fill(CGRect(x: chipRect.maxX + pinWidth * 0.8, y: y, width: pinWidth, height: pinHeight))
            }

            let bottomPinXs: [CGFloat] = [0.37, 0.46, 0.55, 0.64].map { size.width * $0 }
            for x in bottomPinXs {
                context.fill(CGRect(x: x, y: chipRect.minY - pinHeight * 1.5, width: pinWidth, height: pinHeight))
            }

            context.setFillColor(color.withAlphaComponent(0.92).cgColor)
            let dotRadius = size.width * 0.045
            context.fillEllipse(
                in: CGRect(
                    x: center.x - dotRadius,
                    y: chipRect.minY + size.height * 0.06 - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
            )

            return true
        }
    }

    private func drawPremiumGlassIcon(thermalState: ThermalState, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            let center = CGPoint(x: rect.midX, y: rect.midY + size.height * 0.04)

            self.drawGradientArc(
                context,
                center: center,
                radius: size.width * 0.40,
                startDegrees: 198,
                endDegrees: 342,
                width: size.width * 0.11,
                startColor: NSColor(red: 0.28, green: 0.94, blue: 0.73, alpha: 1),
                endColor: NSColor(red: 0.98, green: 0.78, blue: 0.24, alpha: 1)
            )
            self.drawGradientArc(
                context,
                center: center,
                radius: size.width * 0.29,
                startDegrees: 202,
                endDegrees: 338,
                width: size.width * 0.095,
                startColor: NSColor(red: 0.35, green: 0.95, blue: 0.64, alpha: 1),
                endColor: NSColor(red: 0.30, green: 0.89, blue: 0.70, alpha: 1)
            )
            self.drawGradientArc(
                context,
                center: center,
                radius: size.width * 0.20,
                startDegrees: 204,
                endDegrees: 334,
                width: size.width * 0.09,
                startColor: NSColor(red: 0.24, green: 0.74, blue: 1.0, alpha: 1),
                endColor: NSColor(red: 0.35, green: 0.90, blue: 1.0, alpha: 1)
            )

            let chipRect = CGRect(
                x: size.width * 0.28,
                y: size.height * 0.20,
                width: size.width * 0.44,
                height: size.height * 0.30
            )

            context.setFillColor(NSColor(red: 0.16, green: 0.21, blue: 0.30, alpha: 0.95).cgColor)
            context.setStrokeColor(NSColor(red: 0.42, green: 0.53, blue: 0.67, alpha: 0.65).cgColor)
            context.setLineWidth(size.width * 0.045)
            context.addPath(
                CGPath(
                    roundedRect: chipRect,
                    cornerWidth: size.width * 0.08,
                    cornerHeight: size.width * 0.08,
                    transform: nil
                )
            )
            context.drawPath(using: .fillStroke)

            context.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
            context.addPath(
                CGPath(
                    roundedRect: CGRect(
                        x: chipRect.minX + size.width * 0.03,
                        y: chipRect.minY + chipRect.height * 0.58,
                        width: chipRect.width - size.width * 0.06,
                        height: chipRect.height * 0.24
                    ),
                    cornerWidth: size.width * 0.06,
                    cornerHeight: size.width * 0.06,
                    transform: nil
                )
            )
            context.fillPath()

            let pinColor = NSColor(red: 0.35, green: 0.42, blue: 0.54, alpha: 0.85)
            context.setFillColor(pinColor.cgColor)
            let pinWidth = size.width * 0.04
            let pinHeight = size.height * 0.07
            let sidePinsY: [CGFloat] = [0.26, 0.36, 0.46].map { size.height * $0 }
            for y in sidePinsY {
                context.fill(CGRect(x: chipRect.minX - pinWidth * 1.8, y: y, width: pinWidth, height: pinHeight))
                context.fill(CGRect(x: chipRect.maxX + pinWidth * 0.8, y: y, width: pinWidth, height: pinHeight))
            }

            let bottomPinXs: [CGFloat] = [0.37, 0.46, 0.55, 0.64].map { size.width * $0 }
            for x in bottomPinXs {
                context.fill(CGRect(x: x, y: chipRect.minY - pinHeight * 1.5, width: pinWidth, height: pinHeight))
            }

            let coreCenter = CGPoint(x: center.x, y: chipRect.minY + size.height * 0.06)
            context.setStrokeColor(NSColor(red: 0.13, green: 0.18, blue: 0.30, alpha: 0.85).cgColor)
            context.setLineWidth(size.width * 0.028)
            let ringRadii: [CGFloat] = [0.10, 0.07, 0.045].map { size.width * $0 }
            for radius in ringRadii {
                context.strokeEllipse(
                    in: CGRect(
                        x: coreCenter.x - radius,
                        y: coreCenter.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                )
            }

            context.setFillColor(thermalState.accentColor.cgColor)
            let thermalDotRadius = size.width * 0.033
            context.fillEllipse(
                in: CGRect(
                    x: chipRect.midX - thermalDotRadius,
                    y: chipRect.minY + chipRect.height * 0.66 - thermalDotRadius,
                    width: thermalDotRadius * 2,
                    height: thermalDotRadius * 2
                )
            )

            return true
        }
    }

    private func drawArc(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        startDegrees: CGFloat,
        endDegrees: CGFloat,
        width: CGFloat,
        color: NSColor
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.addArc(
            center: center,
            radius: radius,
            startAngle: startDegrees.degreesToRadians,
            endAngle: endDegrees.degreesToRadians,
            clockwise: false
        )
        context.strokePath()
        context.restoreGState()
    }

    private func drawGradientArc(
        _ context: CGContext,
        center: CGPoint,
        radius: CGFloat,
        startDegrees: CGFloat,
        endDegrees: CGFloat,
        width: CGFloat,
        startColor: NSColor,
        endColor: NSColor
    ) {
        let segments = 30
        for segment in 0 ..< segments {
            let t0 = CGFloat(segment) / CGFloat(segments)
            let t1 = CGFloat(segment + 1) / CGFloat(segments)
            let color = blendColor(from: startColor, to: endColor, t: t0)
            let start = startDegrees + (endDegrees - startDegrees) * t0
            let end = startDegrees + (endDegrees - startDegrees) * t1
            drawArc(context, center: center, radius: radius, startDegrees: start, endDegrees: end, width: width, color: color)
        }
    }

    private func blendColor(from: NSColor, to: NSColor, t: CGFloat) -> NSColor {
        let start = from.usingColorSpace(.deviceRGB) ?? from
        let end = to.usingColorSpace(.deviceRGB) ?? to
        return NSColor(
            red: start.redComponent + (end.redComponent - start.redComponent) * t,
            green: start.greenComponent + (end.greenComponent - start.greenComponent) * t,
            blue: start.blueComponent + (end.blueComponent - start.blueComponent) * t,
            alpha: start.alphaComponent + (end.alphaComponent - start.alphaComponent) * t
        )
    }
}

private extension CGFloat {
    var degreesToRadians: CGFloat { self * .pi / 180.0 }
}

private extension ThermalState {
    var accentColor: NSColor {
        switch self {
        case .nominal:
            return NSColor(red: 0.29, green: 0.89, blue: 0.64, alpha: 1)
        case .fair:
            return NSColor(red: 0.98, green: 0.80, blue: 0.27, alpha: 1)
        case .serious:
            return NSColor(red: 0.99, green: 0.58, blue: 0.26, alpha: 1)
        case .critical:
            return NSColor(red: 0.96, green: 0.31, blue: 0.35, alpha: 1)
        case .unknown:
            return NSColor(red: 0.72, green: 0.75, blue: 0.83, alpha: 1)
        }
    }
}
