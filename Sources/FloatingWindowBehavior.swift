import SwiftUI
import AppKit

struct FloatingWindowBehavior: NSViewRepresentable {
    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            guard context.coordinator.configuredWindow !== window else { return }

            window.level = .floating
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            context.coordinator.configuredWindow = window
        }
    }
}
