import SwiftUI

struct AppsView: View {
    @Bindable var manager: AppShortcutsManager
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Apps")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                TapIcon("plus.circle.fill", size: 16, color: .white.opacity(0.5)) {
                    pickApp()
                }
            }

            if manager.shortcuts.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 24)).foregroundStyle(.white.opacity(0.2))
                        Text(L.lang == .fr ? "Ajouter des raccourcis" : "Add app shortcuts")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Grid of app icons
                let columns = [GridItem(.adaptive(minimum: 50), spacing: 10)]
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(manager.shortcuts) { shortcut in
                            AppIcon(shortcut: shortcut, manager: manager)
                        }
                    }
                }
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { response in
            if response == .OK, let url = panel.url {
                manager.add(path: url.path)
            }
        }
    }
}

struct AppIcon: View {
    let shortcut: AppShortcut
    let manager: AppShortcutsManager
    @State private var hovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let icon = manager.icon(for: shortcut) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                }

                // Delete badge on hover
                if hovered {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .offset(x: 4, y: -4)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                manager.remove(shortcut)
                            }
                        }
                }
            }

            Text(shortcut.name)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { hovered = h } }
        .onTapGesture { manager.launch(shortcut) }
    }
}
