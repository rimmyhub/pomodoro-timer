import SwiftUI

struct CircularDialView: View {
    let progress: Double
    let color: Color
    let isLocked: Bool
    let onChangedMinutes: (Int) -> Void

    private var clampedProgress: Double {
        max(0.0, min(1.0, progress))
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) - 8

            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: size, height: size)

                if clampedProgress >= 0.999 {
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                } else if clampedProgress > 0 {
                    FanSectorShape(progress: clampedProgress)
                        .fill(color)
                        .frame(width: size, height: size)
                }

                Circle()
                    .stroke(color.opacity(0.75), lineWidth: 2)
                    .frame(width: size, height: size)
            }
            .contentShape(Circle())
            .animation(.linear(duration: 0.2), value: clampedProgress)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isLocked else { return }
                        guard let next = minuteValue(for: value.location, in: geo.size) else { return }
                        onChangedMinutes(next)
                    }
            )
        }
    }

    private func minuteValue(for location: CGPoint, in size: CGSize) -> Int? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = min(size.width, size.height) / 2
        let distance = hypot(dx, dy)

        // Ignore center drags to prevent unstable angle jumps.
        guard distance >= radius * 0.28 else { return nil }

        // 12 o'clock as 0deg, increasing clockwise.
        var degrees = atan2(dx, -dy) * 180 / .pi
        if degrees < 0 { degrees += 360 }

        let raw = Int((degrees / 360.0) * 60.0 + 0.5)
        if raw == 0 { return 60 }
        return max(1, min(60, raw))
    }
}

private struct FanSectorShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let endAngle = Angle.degrees(-90 + (360 * max(0, min(1, progress))))

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
