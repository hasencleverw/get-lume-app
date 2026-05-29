import SwiftUI

/// Fluid "L" shape mirroring the Lume brand: a tall vertical stroke with a
/// flowing curved foot, like flame strokes meeting at a corner.
struct LumeLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // The L sits inside ~76% of the box, with slight optical padding.
        let xLeft   = w * 0.30
        let xStroke = w * 0.20      // thickness of vertical stroke
        let yTop    = h * 0.14
        let yFootTop  = h * 0.66
        let yBottom = h * 0.86
        let xRight  = w * 0.84      // end of horizontal foot
        let radius  = w * 0.10

        // Vertical stroke (top to where the foot starts).
        p.move(to: CGPoint(x: xLeft + radius, y: yTop))
        p.addLine(to: CGPoint(x: xLeft + xStroke - radius, y: yTop))
        p.addQuadCurve(to: CGPoint(x: xLeft + xStroke, y: yTop + radius),
                       control: CGPoint(x: xLeft + xStroke, y: yTop))
        p.addLine(to: CGPoint(x: xLeft + xStroke, y: yFootTop))

        // Outer curve of the foot's inner corner — flowing curve outward.
        p.addQuadCurve(to: CGPoint(x: xLeft + xStroke + radius * 1.6, y: yFootTop + radius * 0.6),
                       control: CGPoint(x: xLeft + xStroke, y: yFootTop + radius * 0.6))

        // Top edge of horizontal foot to the right.
        p.addLine(to: CGPoint(x: xRight - radius, y: yFootTop + radius * 0.6))
        p.addQuadCurve(to: CGPoint(x: xRight, y: yFootTop + radius * 0.6 + radius),
                       control: CGPoint(x: xRight, y: yFootTop + radius * 0.6))

        // Right edge of foot.
        p.addLine(to: CGPoint(x: xRight, y: yBottom - radius))
        p.addQuadCurve(to: CGPoint(x: xRight - radius, y: yBottom),
                       control: CGPoint(x: xRight, y: yBottom))

        // Bottom edge — back to the left.
        p.addLine(to: CGPoint(x: xLeft + radius, y: yBottom))
        p.addQuadCurve(to: CGPoint(x: xLeft, y: yBottom - radius),
                       control: CGPoint(x: xLeft, y: yBottom))

        // Left edge — back up to the top.
        p.addLine(to: CGPoint(x: xLeft, y: yTop + radius))
        p.addQuadCurve(to: CGPoint(x: xLeft + radius, y: yTop),
                       control: CGPoint(x: xLeft, y: yTop))

        p.closeSubpath()
        return p
    }
}

/// Reusable view that renders the Lume L glyph at any size, color-aware so it
/// works in the menu bar (which adapts to light/dark menus) and in the app UI.
struct LumeLogoMark: View {
    var size: CGFloat = 18
    var color: Color = .primary

    var body: some View {
        LumeLogoShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

