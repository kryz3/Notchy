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
            self?.onExpandChanged(expanded)
        }
    }

    // MARK: - Panel setup

    private func setupPanel() {
        let info = viewModel.notchInfo
        let ew = viewModel.expandedWidth
        let eh = viewModel.expandedHeight
        let centerX = info.notchRect.midX
        let topY = info.screenFrame.maxY

        let panelFrame = NSRect(x: centerX - ew / 2, y: topY - eh, width: ew, height: eh)

        panel = NotchPanel(contentRect: panelFrame)
        panel.ignoresMouseEvents = true

        let rootView = NotchContainerView(vm: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: panelFrame.size)
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    // MARK: - Expand/Collapse

    private func onExpandChanged(_ expanded: Bool) {
        if expanded {
            panel.ignoresMouseEvents = false
            panel.makeKey()
        } else {
            panel.ignoresMouseEvents = true
            panel.resignKey()
        }
    }

    // MARK: - Mouse tracking

    private func setupMouseTracking() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            self?.handleGlobalMouse(event)
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseExited]) { [weak self] event in
            self?.handleLocalMouse(event)
            return event
        }
    }

    private func handleGlobalMouse(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation

        if viewModel.isExpanded {
            if !panel.frame.contains(loc) {
                cancelHoverTimer()
                viewModel.scheduleCollapse(delay: 0.15)
            }
        } else {
            let trigger = notchTriggerRect()
            if trigger.contains(loc) {
                if event.type == .leftMouseDown {
                    cancelHoverTimer()
                    viewModel.expand()
                } else {
                    startHoverTimer()
                }
            } else if event.type == .leftMouseDown && viewModel.isCompactVisible {
                // Check click on compact play/pause area (right side of compact bar)
                let compactRect = compactClickRect()
                if compactRect.contains(loc) {
                    viewModel.music.togglePlayPause()
                }
            } else {
                cancelHoverTimer()
            }
        }
    }

    private func handleLocalMouse(_ event: NSEvent) {
        if viewModel.isExpanded {
            viewModel.cancelPendingCollapse()
        }
    }

    private func notchTriggerRect() -> NSRect {
        let info = viewModel.notchInfo
        return NSRect(
            x: info.notchRect.minX,
            y: info.notchRect.minY - 10,
            width: info.notchWidth,
            height: info.notchHeight + 10
        )
    }

    /// Click zone for the compact play/pause button (right side of compact bar)
    private func compactClickRect() -> NSRect {
        let info = viewModel.notchInfo
        let centerX = info.notchRect.midX
        let cw = viewModel.compactWidth
        // Right 40px of the compact bar
        return NSRect(
            x: centerX + cw / 2 - 40,
            y: info.notchRect.minY,
            width: 40,
            height: info.notchHeight
        )
    }

    private func startHoverTimer() {
        guard hoverTimer == nil else { return }
        viewModel.isHovering = true
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.viewModel.expand()
            self?.viewModel.isHovering = false
            self?.hoverTimer = nil
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        viewModel.isHovering = false
    }

    // MARK: - Keyboard

    private func setupKeyboardShortcut() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.viewModel.collapse()
                return nil
            }
            return event
        }
    }
}
