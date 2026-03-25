import AppKit
import SwiftUI

final class NotchPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar + 1
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
    }
}

/// NSHostingView subclass that only accepts hits within the visible content shape.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var hitTestPath: NSBezierPath?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let path = hitTestPath, !path.contains(point) {
            return nil
        }
        return super.hitTest(point)
    }
}
