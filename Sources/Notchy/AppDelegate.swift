import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: NotchPanel!
    private var viewModel: NotchViewModel!
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var localKeyMonitor: Any?
    private var hoverTimer: Timer?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = NotchViewModel()
        setupPanel()
        setupMouseTracking()
        setupKeyboardShortcut()
        viewModel.onExpandChanged = { [weak self] expanded in
            guard let self else { return }
            self.panel.ignoresMouseEvents = !expanded
            if expanded {
                self.panel.makeKey()
            } else {
                self.panel.resignKey()
            }
        }
    }

    // MARK: - Panel setup

    private func setupPanel() {
        let info = viewModel.notchInfo
        let expandedW = viewModel.expandedWidth
        let expandedH = viewModel.expandedHeight

        let centerX = info.notchRect.midX
        let topY = info.screenFrame.maxY

        let panelFrame = NSRect(
            x: centerX - expandedW / 2,
            y: topY - expandedH,
            width: expandedW,
            height: expandedH
        )

        panel = NotchPanel(contentRect: panelFrame)
        // Start click-through since we're collapsed
        panel.ignoresMouseEvents = true

        let rootView = NotchContainerView(vm: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelFrame.size)
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    // MARK: - Mouse tracking

    private func setupMouseTracking() {
        // Global: mouse everywhere (including when panel is click-through)
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            self?.handleGlobalMouse(event)
        }

        // Local: mouse inside our panel (only fires when panel accepts events = expanded)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseExited]) { [weak self] event in
            self?.handleLocalMouse(event)
            return event
        }
    }

    private func handleGlobalMouse(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation

        if viewModel.isExpanded {
            // Mouse moved outside our panel → collapse
            let contentRect = panel.frame
            if !contentRect.contains(loc) {
                cancelHoverTimer()
                viewModel.scheduleCollapse(delay: 0.15)
            }
        } else {
            // Collapsed: check if mouse is exactly in the notch trigger zone
            let trigger = notchTriggerRect()
            if trigger.contains(loc) {
                if event.type == .leftMouseDown {
                    cancelHoverTimer()
                    viewModel.expand()
                } else {
                    startHoverTimer()
                }
            } else {
                cancelHoverTimer()
            }
        }
    }

    private func handleLocalMouse(_ event: NSEvent) {
        // Panel is interactive (expanded) and mouse is inside → cancel collapse
        if viewModel.isExpanded {
            viewModel.cancelPendingCollapse()
        }
    }

    /// Small rect around the physical notch — this is the ONLY hover trigger
    private func notchTriggerRect() -> NSRect {
        let info = viewModel.notchInfo
        // Tight zone: notch rect + small vertical padding below
        return NSRect(
            x: info.notchRect.minX,
            y: info.notchRect.minY - 10,
            width: info.notchWidth,
            height: info.notchHeight + 10
        )
    }

    private func startHoverTimer() {
        guard hoverTimer == nil else { return }
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.viewModel.expand()
            self?.hoverTimer = nil
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    // MARK: - Keyboard

    private func setupKeyboardShortcut() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.viewModel.collapse()
                return nil
            }
            return event
        }
    }
}
