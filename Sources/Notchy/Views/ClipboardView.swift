import SwiftUI

struct ClipboardView: View {
    @Bindable var clipboard: ClipboardManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("\(clipboard.items.count)")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                if !clipboard.items.isEmpty {
                    TapIcon("trash", size: 12, color: .white.opacity(0.3)) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { clipboard.clear() }
                    }
                }
            }

            if clipboard.items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 24)).foregroundStyle(.white.opacity(0.2))
                        Text(L.lang == .fr ? "Rien dans le presse-papier" : "Clipboard empty")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(clipboard.items) { item in
                            ClipRow(item: item, onCopy: {
                                clipboard.copyToClipboard(item)
                            }, onDelete: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    clipboard.remove(item)
                                }
                            })
                        }
                    }
                }
            }
        }
    }
}

struct ClipRow: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var hovered = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(item.preview)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)

            Spacer(minLength: 4)

            if copied {
                Image(systemName: "checkmark").font(.system(size: 9)).foregroundStyle(.green)
            } else if hovered {
                HStack(spacing: 8) {
                    TapIcon("doc.on.doc", size: 10, color: .white.opacity(0.5)) {
                        onCopy()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
                    }
                    TapIcon("xmark", size: 9, color: .white.opacity(0.3)) { onDelete() }
                }
            } else {
                Text(item.timeAgo)
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(hovered ? 0.06 : 0.03)))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { hovered = h } }
        .onTapGesture {
            onCopy()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { copied = false }
        }
    }
}
