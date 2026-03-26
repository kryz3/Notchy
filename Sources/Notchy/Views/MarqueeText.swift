import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 9, weight: .medium)
    var color: Color = .white.opacity(0.7)
    var speed: Double = 20 // points per second

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var needsScroll: Bool { textWidth > containerWidth + 2 }
    private let gap: CGFloat = 17

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            let _ = updateContainer(w)

            if needsScroll {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let totalWidth = textWidth + gap
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let offset = elapsed * speed
                    let x = -(offset.truncatingRemainder(dividingBy: totalWidth))

                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .offset(x: x)
                }
                .frame(width: w, alignment: .leading)
                .clipped()
            } else {
                label
                    .frame(width: w, alignment: .leading)
            }
        }
        .frame(height: 14)
        .onAppear { measure() }
        .onChange(of: text) { _, _ in measure() }
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    private func updateContainer(_ w: CGFloat) {
        if containerWidth != w { DispatchQueue.main.async { containerWidth = w } }
    }

    private func measure() {
        // Measure text width using NSAttributedString
        let nsFont: NSFont
        switch font {
        default:
            nsFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        }
        let attr = NSAttributedString(string: text, attributes: [.font: nsFont])
        textWidth = attr.size().width
    }
}
