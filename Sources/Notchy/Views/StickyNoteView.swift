import SwiftUI

enum NoteMode: String {
    case text, draw
}

// MARK: - Drawing canvas

struct DrawingLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
}

struct DrawingCanvas: View {
    @Binding var lines: [DrawingLine]
    @State private var currentLine: DrawingLine?
    var strokeColor: Color = .white
    var strokeWidth: CGFloat = 2

    var body: some View {
        Canvas { context, _ in
            for line in lines {
                var path = Path()
                guard let first = line.points.first else { continue }
                path.move(to: first)
                for point in line.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(line.color), lineWidth: line.width)
            }

            if let current = currentLine {
                var path = Path()
                guard let first = current.points.first else { return }
                path.move(to: first)
                for point in current.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(current.color), lineWidth: current.width)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if currentLine == nil {
                        currentLine = DrawingLine(points: [value.location], color: strokeColor, width: strokeWidth)
                    } else {
                        currentLine?.points.append(value.location)
                    }
                }
                .onEnded { _ in
                    if let line = currentLine {
                        lines.append(line)
                    }
                    currentLine = nil
                }
        )
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.03)))
    }
}

// MARK: - StickyNoteView

struct StickyNoteView: View {
    @Bindable var manager: StickyNoteManager
    @State private var mode: NoteMode = .text
    @State private var isEditing = true
    @State private var drawingLines: [DrawingLine] = []
    @State private var strokeColor: Color = .white
    @State private var strokeWidth: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Mode switcher
                HStack(spacing: 0) {
                    modeButton(.text, icon: "text.alignleft")
                    modeButton(.draw, icon: "scribble")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))

                if mode == .text {
                    TapIcon(isEditing ? "eye" : "pencil", size: 11, color: .white.opacity(0.5)) {
                        isEditing.toggle()
                    }
                } else {
                    // Drawing controls
                    TapIcon("arrow.uturn.backward", size: 11, color: drawingLines.isEmpty ? .white.opacity(0.15) : .white.opacity(0.5)) {
                        if !drawingLines.isEmpty { drawingLines.removeLast() }
                    }
                    TapIcon("trash", size: 11, color: drawingLines.isEmpty ? .white.opacity(0.15) : .white.opacity(0.5)) {
                        drawingLines.removeAll()
                    }
                }
            }

            if mode == .text {
                textContent
            } else {
                drawContent
            }
        }
    }

    private func modeButton(_ m: NoteMode, icon: String) -> some View {
        TapIcon(icon, size: 11, color: mode == m ? .white : .white.opacity(0.35)) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { mode = m }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(mode == m ? RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)) : nil)
    }

    // MARK: - Text mode

    private var textContent: some View {
        Group {
            if isEditing {
                TextEditor(text: $manager.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(markdownContent)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
            }
        }
    }

    // MARK: - Draw mode

    private var drawContent: some View {
        VStack(spacing: 6) {
            DrawingCanvas(lines: $drawingLines, strokeColor: strokeColor, strokeWidth: strokeWidth)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Color + width controls
            HStack(spacing: 8) {
                ForEach([Color.white, .red, .green, .blue, .yellow, .orange], id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: strokeColor == color ? 16 : 12, height: strokeColor == color ? 16 : 12)
                        .overlay(strokeColor == color ? Circle().stroke(.white.opacity(0.5), lineWidth: 1.5) : nil)
                        .onTapGesture { strokeColor = color }
                }

                Spacer()

                // Stroke width
                ForEach([CGFloat(1), 2, 4], id: \.self) { w in
                    Circle()
                        .fill(.white.opacity(strokeWidth == w ? 0.8 : 0.3))
                        .frame(width: 4 + w * 2, height: 4 + w * 2)
                        .onTapGesture { strokeWidth = w }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var markdownContent: AttributedString {
        (try? AttributedString(markdown: manager.text)) ?? AttributedString(manager.text)
    }
}
