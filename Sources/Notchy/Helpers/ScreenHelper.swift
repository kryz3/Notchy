import AppKit

struct NotchInfo {
    let screenFrame: CGRect
    let notchRect: CGRect
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let menuBarHeight: CGFloat
    let hasNotch: Bool
}

enum ScreenHelper {

    static func detectNotch() -> NotchInfo {
        guard let screen = NSScreen.main else {
            return NotchInfo(
                screenFrame: .zero, notchRect: .zero,
                notchWidth: 200, notchHeight: 32, menuBarHeight: 25, hasNotch: false
            )
        }

        let frame = screen.frame
        let visible = screen.visibleFrame
        let menuBarHeight = frame.maxY - visible.maxY

        // Try to detect notch via auxiliary areas (macOS 12+)
        if let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea {

            let notchLeft = topLeft.maxX
            let notchRight = topRight.minX
            let notchWidth = notchRight - notchLeft
            let notchY = frame.maxY - menuBarHeight

            let notchRect = CGRect(
                x: notchLeft,
                y: notchY,
                width: notchWidth,
                height: menuBarHeight
            )

            return NotchInfo(
                screenFrame: frame,
                notchRect: notchRect,
                notchWidth: notchWidth,
                notchHeight: menuBarHeight,
                menuBarHeight: menuBarHeight,
                hasNotch: true
            )
        }

        // No notch — simulate one at top center
        let fakeWidth: CGFloat = 200
        let notchRect = CGRect(
            x: frame.midX - fakeWidth / 2,
            y: frame.maxY - menuBarHeight,
            width: fakeWidth,
            height: menuBarHeight
        )

        return NotchInfo(
            screenFrame: frame,
            notchRect: notchRect,
            notchWidth: fakeWidth,
            notchHeight: menuBarHeight,
            menuBarHeight: menuBarHeight,
            hasNotch: false
        )
    }

    /// Trigger zone is larger than the notch to make hover easier
    static func triggerZone(for info: NotchInfo, padding: CGFloat = 20) -> CGRect {
        return info.notchRect.insetBy(dx: -padding, dy: -padding / 2)
    }
}
