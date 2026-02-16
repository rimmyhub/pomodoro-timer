import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct PomodoroBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = PomodoroViewModel()

    var body: some Scene {
        MenuBarExtra {
            MainTimerView(viewModel: viewModel)
                .frame(width: 360, height: 490)
        } label: {
            MenuBarTimerIcon(progress: viewModel.menuBarProgress)
        }
        .menuBarExtraStyle(.window)

        Window("카테고리", id: "category-manager") {
            CategoryManagerView(viewModel: viewModel)
                .background(FloatingWindowBehavior())
                .frame(minWidth: 420, minHeight: 520)
        }

        Window("학습 통계", id: "stats") {
            StatsView(viewModel: viewModel)
                .background(FloatingWindowBehavior())
                .frame(minWidth: 580, minHeight: 520)
        }

        Window("설정", id: "settings") {
            SettingsView(viewModel: viewModel)
                .background(FloatingWindowBehavior())
                .frame(minWidth: 460, minHeight: 430)
        }
    }
}

struct MenuBarTimerIcon: View {
    let progress: Double

    private var clampedProgress: Double {
        max(0, min(1, progress))
    }

    var body: some View {
        Image(nsImage: MenuBarProgressImage.make(progress: clampedProgress))
            .renderingMode(.template)
            .interpolation(.high)
        .animation(.linear(duration: 0.22), value: clampedProgress)
    }
}

private enum MenuBarProgressImage {
    static func make(progress: Double) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let frame = NSRect(x: 1, y: 1, width: 16, height: 16)
        let baseCircle = NSBezierPath(ovalIn: frame)

        if progress > 0 {
            NSColor.labelColor.withAlphaComponent(0.20).setFill()
            baseCircle.fill()
        }

        let p = max(0, min(1, progress))
        if p >= 0.999 {
            NSColor.labelColor.setFill()
            baseCircle.fill()
        } else if p > 0 {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radius = frame.width / 2
            // Match main dial: start at 12 o'clock and proceed clockwise.
            let startAngle: CGFloat = 90
            let endAngle = startAngle - (360 * p)

            let sector = NSBezierPath()
            sector.move(to: center)
            sector.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            sector.close()

            NSColor.labelColor.setFill()
            sector.fill()
        }

        NSColor.labelColor.setStroke()
        baseCircle.lineWidth = 1.0
        baseCircle.stroke()

        image.isTemplate = true
        return image
    }
}
