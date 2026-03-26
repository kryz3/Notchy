import SwiftUI

struct NotchContainerView: View {
    @Bindable var vm: NotchViewModel
    @State private var scrolledTab: RightTab? = .calendar
    @State private var currentTime = Date()
    @State private var showSettings = false
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .top) {
            // Main notch content
            ZStack(alignment: .top) {
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
            .frame(
                width: vm.isExpanded ? vm.expandedWidth : vm.notchWidth,
                height: vm.isExpanded ? vm.expandedHeight : vm.notchHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: vm.isExpanded ? vm.expandedCornerRadius : vm.collapsedCornerRadius))

            // Notification pill — flush with right edge of notch
            if vm.showNotification && !vm.isExpanded {
                notificationPill
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: (vm.expandedWidth + vm.notchWidth) / 2 - 8)
                    .transition(.offset(x: -90).combined(with: .opacity))
            }
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

    // These are only for the main notch shape (notification is separate)
    private var currentWidth: CGFloat { vm.isExpanded ? vm.expandedWidth : vm.notchWidth }
    private var currentHeight: CGFloat { vm.isExpanded ? vm.expandedHeight : vm.notchHeight }

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
        let fmt = DateFormatter(); fmt.locale = L.dateLocale; fmt.dateFormat = "EEE d MMM"
        return fmt.string(from: currentTime).capitalized
    }

    // MARK: - Settings panel

    private var settingsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L.settings)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                TapIcon("xmark", size: 11, color: .white.opacity(0.4)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showSettings = false
                    }
                }
            }
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {

            // Theme
            settingsSection(L.appearance) {
                HStack(spacing: 12) {
                    ForEach(NotchTheme.allCases, id: \.rawValue) { theme in themeCard(theme) }
                }
            }

            // Language
            settingsSection(L.language) {
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                vm.settings.language = lang
                            }
                        } label: {
                            Text(lang.rawValue)
                                .font(.system(size: 11, weight: vm.settings.language == lang ? .semibold : .regular))
                                .foregroundStyle(vm.settings.language == lang ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(vm.settings.language == lang ? .white.opacity(0.12) : .white.opacity(0.04))
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Music player
            settingsSection(L.musicPlayer) {
                HStack(spacing: 8) {
                    ForEach(MusicPlayerSource.allCases, id: \.rawValue) { source in
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                vm.settings.musicPlayer = source
                            }
                        } label: {
                            Text(source.rawValue)
                                .font(.system(size: 11, weight: vm.settings.musicPlayer == source ? .semibold : .regular))
                                .foregroundStyle(vm.settings.musicPlayer == source ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(vm.settings.musicPlayer == source ? .white.opacity(0.12) : .white.opacity(0.04))
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Queue size
            settingsSlider(L.queueSize, value: $vm.settings.queueSize, unit: L.tracks, range: 3...20, step: 1)

            // Music history
            settingsSlider(L.musicHistory, value: $vm.settings.musicHistorySize, unit: L.tracks, range: 3...30, step: 1)

            // Terminal history
            settingsSlider(L.terminalHistory, value: $vm.settings.terminalHistorySize, unit: "", range: 20...500, step: 10)

            // Launch at login
            HStack {
                Toggle(isOn: Binding(
                    get: { vm.settings.launchAtLogin },
                    set: { vm.settings.launchAtLogin = $0 }
                )) {
                    Text(L.launchAtLogin)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .toggleStyle(.switch)
                .tint(.green)
            }

            // Credit + GitHub
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(L.createdBy).font(.system(size: 10)).foregroundStyle(.white.opacity(0.2))
                    Button {
                        NSWorkspace.shared.open(URL(string: "https://github.com/kryz3")!)
                    } label: {
                        Text("kryz3").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/kryz3/Notchy")!)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 9))
                        Text("GitHub").font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.2))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            // Update
            updateSection

            // Quit
            Button {
                vm.settings.quit()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "power").font(.system(size: 10))
                    Text(L.quit).font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.red.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            content()
        }
    }

    private var updateSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("v\(UpdateManager.currentVersion)")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.25))
                Spacer()

                if vm.updater.isUpdating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        Text(vm.updater.updateProgress).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                } else if vm.updater.updateAvailable {
                    Button {
                        vm.updater.performUpdate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 10))
                            Text(L.lang == .fr ? "Mettre à jour (\(vm.updater.latestVersion ?? ""))" : "Update (\(vm.updater.latestVersion ?? ""))")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.green.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                } else if vm.updater.isChecking {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                } else if vm.updater.checkedOnce && !vm.updater.updateAvailable {
                    Text(L.lang == .fr ? "À jour" : "Up to date")
                        .font(.system(size: 10)).foregroundStyle(.green.opacity(0.6))
                } else {
                    Button {
                        vm.updater.checkForUpdates()
                    } label: {
                        Text(L.lang == .fr ? "Vérifier" : "Check")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = vm.updater.error {
                Text(error).font(.system(size: 9)).foregroundStyle(.red.opacity(0.6))
            }
        }
    }

    private func settingsSlider(_ title: String, value: Binding<Int>, unit: String, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
            }
            HStack(spacing: 8) {
                Text("\(Int(range.lowerBound))").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0) }),
                       in: range, step: step).tint(.white.opacity(0.5))
                Text("\(Int(range.upperBound))").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
            }
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

    // MARK: - Notification pill (right of notch, same height, always black)

    private var notificationPill: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.notificationIcon ?? "headphones")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)

            Text(vm.notificationText ?? "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(height: vm.notchHeight - 1)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 2,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 8,
                topTrailingRadius: 8
            )
            .fill(.black)
        )
        .fixedSize()
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
