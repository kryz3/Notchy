import SwiftUI

struct NotchContainerView: View {
    @Bindable var vm: NotchViewModel
    @State private var scrolledTab: RightTab? = .calendar
    @State private var currentTime = Date()
    @State private var showSettings = false
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            // Notification banner
            if vm.showNotification && !vm.isExpanded {
                notificationBanner
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Background + content clipped
            ZStack(alignment: .top) {
                // Theme-aware background
                notchBackground

                if vm.isExpanded {
                    VStack(spacing: 0) {
                        clockBar
                            .padding(.top, 4)
                            .frame(height: vm.notchHeight)

                        if showSettings {
                            settingsPanel
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            expandedContent
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                                .padding(.top, 6)
                        }
                    }
                    .opacity(vm.isExpanded ? 1 : 0)
                }
            }
            .frame(width: currentWidth, height: currentHeight)
            .clipShape(RoundedRectangle(cornerRadius: vm.isExpanded ? vm.expandedCornerRadius : vm.collapsedCornerRadius))
        }
        .frame(width: vm.expandedWidth, height: vm.expandedHeight, alignment: .top)
        .onReceive(clockTimer) { currentTime = $0 }
        .onChange(of: scrolledTab) { _, newValue in
            if let tab = newValue { vm.selectedTab = tab }
        }
        .onChange(of: vm.selectedTab) { _, newValue in
            scrolledTab = newValue
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var notchBackground: some View {
        switch vm.settings.theme {
        case .solid:
            RoundedRectangle(cornerRadius: vm.isExpanded ? vm.expandedCornerRadius : vm.collapsedCornerRadius)
                .fill(.black)
                .shadow(color: .black.opacity(vm.isExpanded ? 0.5 : 0), radius: 20, y: 10)
        case .glass:
            ZStack {
                RoundedRectangle(cornerRadius: vm.isExpanded ? vm.expandedCornerRadius : vm.collapsedCornerRadius)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                RoundedRectangle(cornerRadius: vm.isExpanded ? vm.expandedCornerRadius : vm.collapsedCornerRadius)
                    .fill(.black.opacity(0.35))
            }
            .shadow(color: .black.opacity(vm.isExpanded ? 0.4 : 0), radius: 25, y: 10)
        }
    }

    private var currentWidth: CGFloat {
        if vm.showNotification && !vm.isExpanded { return vm.notificationWidth }
        return vm.isExpanded ? vm.expandedWidth : vm.notchWidth
    }

    private var currentHeight: CGFloat {
        if vm.showNotification && !vm.isExpanded { return vm.notificationHeight }
        return vm.isExpanded ? vm.expandedHeight : vm.notchHeight
    }

    // MARK: - Clock

    private var clockBar: some View {
        HStack(spacing: 0) {
            Text(timeString)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.leading, 20)

            Spacer()
            Color.clear.frame(width: vm.notchWidth)
            Spacer()

            Text(dateString)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))

            // Settings gear
            TapIcon("gearshape.fill", size: 12, color: showSettings ? .white : .white.opacity(0.35)) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showSettings.toggle()
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 16)
        }
    }

    private var timeString: String {
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        return fmt.string(from: currentTime)
    }

    private var dateString: String {
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "fr_FR"); fmt.dateFormat = "EEE d MMM"
        return fmt.string(from: currentTime).capitalized
    }

    // MARK: - Settings panel

    private var settingsPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Apparence")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                TapIcon("xmark", size: 11, color: .white.opacity(0.4)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showSettings = false
                    }
                }
            }

            HStack(spacing: 12) {
                ForEach(NotchTheme.allCases, id: \.rawValue) { theme in
                    themeCard(theme)
                }
            }

            Spacer()
        }
    }

    private func themeCard(_ theme: NotchTheme) -> some View {
        let selected = vm.settings.theme == theme
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                vm.settings.theme = theme
            }
        } label: {
            VStack(spacing: 8) {
                // Preview
                ZStack {
                    if theme == .glass {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.black.opacity(0.3))
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.black)
                    }

                    // Fake content
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.2)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1)).frame(height: 6)
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.1)).frame(height: 6)
                    }
                    .padding(10)
                }
                .frame(height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? .white : .white.opacity(0.15), lineWidth: selected ? 2 : 1)
                )

                Text(theme.rawValue)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .white : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notification banner

    private var notificationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: vm.notificationIcon ?? "headphones")
                .font(.system(size: 20)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connecté").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                Text(vm.notificationText ?? "").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
            }
        }
        .padding(.top, vm.notchHeight + 4)
        .frame(width: vm.notificationWidth, height: vm.notificationHeight, alignment: .center)
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        HStack(spacing: 14) {
            MusicView(music: vm.music)
                .frame(width: 220)

            Rectangle().fill(.white.opacity(0.1)).frame(width: 1)

            rightPanel
        }
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(RightTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            vm.selectedTab = tab
                            scrolledTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon).font(.system(size: 10))
                            Text(tab.label).font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(vm.selectedTab == tab ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vm.selectedTab == tab ? .white.opacity(0.1) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    CalendarView(calendar: vm.calendar)
                        .containerRelativeFrame(.horizontal)
                        .id(RightTab.calendar)
                    RemindersView(reminders: vm.reminders)
                        .containerRelativeFrame(.horizontal)
                        .id(RightTab.reminders)
                    StickyNoteView(manager: vm.stickyNote)
                        .containerRelativeFrame(.horizontal)
                        .id(RightTab.notes)
                    TerminalView()
                        .containerRelativeFrame(.horizontal)
                        .id(RightTab.terminal)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledTab)
        }
    }
}
