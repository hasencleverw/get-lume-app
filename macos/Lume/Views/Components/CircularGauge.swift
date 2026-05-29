import SwiftUI

struct CircularGauge: View {
    let value: Double          // 0–100
    let size: CGFloat
    let lineWidth: CGFloat
    var gradientColors: [Color] = [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")]
    var label: String = ""
    var unit: String = "%"
    var showValue: Bool = true

    @State private var animated: Double = 0

    private var displayColors: [Color] {
        switch value {
        case 0..<60:  return gradientColors
        case 60..<80: return [Color(hex: "FFB830"), Color(hex: "D08A0A")]
        default:      return [Color(hex: "FF4D5E"), Color(hex: "CC2035")]
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)
                    .frame(width: size, height: size)

                // Glow layer
                Circle()
                    .trim(from: 0, to: CGFloat(animated / 100))
                    .stroke(displayColors[0].opacity(0.3),
                            style: StrokeStyle(lineWidth: lineWidth + 7, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 5)
                    .animation(.spring(response: 0.9, dampingFraction: 0.75), value: animated)

                // Main arc
                Circle()
                    .trim(from: 0, to: CGFloat(animated / 100))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [displayColors[0].opacity(0.7), displayColors[0]]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.9, dampingFraction: 0.75), value: animated)

                // Center value
                if showValue {
                    VStack(spacing: 1) {
                        Text(String(format: "%.0f", value))
                            .font(.system(size: size * 0.21, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(unit)
                            .font(.system(size: size * 0.11, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
        .onAppear { animated = value }
        .onChange(of: value) { animated = $0 }
    }
}

// MARK: - Line chart (shared)
struct LineChart: View {
    let values: [Double]
    var color: Color
    var fillOpacity: Double = 0.15

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let max = Swift.max(values.max() ?? 100, 10)
            let step = size.width / CGFloat(values.count - 1)

            func pt(_ i: Int) -> CGPoint {
                CGPoint(x: CGFloat(i) * step,
                        y: size.height - CGFloat(values[i] / max) * size.height * 0.92 - size.height * 0.04)
            }

            // Fill
            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            for i in values.indices { fill.addLine(to: pt(i)) }
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.closeSubpath()
            let grad = ctx.resolve(
                GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [color.opacity(fillOpacity), color.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            ctx.fill(fill, with: grad)

            // Line
            var line = Path()
            line.move(to: pt(0))
            for i in 1..<values.count { line.addLine(to: pt(i)) }
            ctx.stroke(line, with: .color(color), lineWidth: 1.8)
        }
    }
}

// MARK: - Progress bar
struct ProgressBar: View {
    let value: Double  // 0–1
    var color: Color = .appAccent
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07)).frame(height: height)
                Capsule()
                    .fill(LinearGradient(
                        colors: [color.opacity(0.8), color],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(0, geo.size.width * CGFloat(value)), height: height)
                    .animation(.spring(response: 0.6), value: value)
            }
        }
        .frame(height: height)
    }
}
