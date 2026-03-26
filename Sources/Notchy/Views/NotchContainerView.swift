import SwiftUI

struct NotchContainerView: View {
    @Bindable var vm: NotchViewModel
    @State private var scrolledTab: RightTab? = .calendar
    @State private var currentTime = Date()
    @State private var showSettings = false
    @State private var settingsPage: String? = nil // nil = root
    @State private var showBTPopover = false
    @State private var btHoverTrigger = false
    @State private var btHoverPopover = false
    @State private var showCPUTip = false
    @State private var showRAMTip = false
    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accent: Color {
        let c = vm.settings.accentColor.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }

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

                // Compact mode: music info visible when collapsed
                if vm.isCompactVisible && !vm.isExpanded && !vm.showNotification {
                    compactMusicBar
                }
            }
            .frame(width: mainWidth, height: mainHeight)
            .clipShape(RoundedRectangle(cornerRadius: mainCornerRadius))
            // Breathing glow on hover (before expanding)
            .shadow(
                color: vm.isHovering && !vm.isExpanded
                    ? accent.opacity(0.4)
                    : .clear,
                radius: vm.isHovering ? 12 : 0, y: 4
            )
            .scaleEffect(vm.isHovering && !vm.isExpanded ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: vm.isHovering)

            // Notification pill
            if vm.showNotification && !vm.isExpanded && !vm.isCompactVisible {
                notificationPill
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .offset(x: (vm.expandedWidth + vm.notchWidth) / 2 - 8)
                    .transition(.offset(x: -90).combined(with: .opacity))
            }

            // BT popover (outside clip, above everything)
            if showBTPopover && vm.isExpanded {
                btPopover
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -50, y: vm.notchHeight + 4)
                    .zIndex(100)
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

    private var mainWidth: CGFloat {
        if vm.isExpanded { return vm.expandedWidth }
        if vm.isCompactVisible { return vm.compactWidth }
        return vm.notchWidth
    }

    private var mainHeight: CGFloat {
        if vm.isExpanded { return vm.expandedHeight }
        return vm.notchHeight // compact same height as notch
    }

    private var mainCornerRadius: CGFloat {
        if vm.isExpanded { return vm.expandedCornerRadius }
        return vm.collapsedCornerRadius
    }

    // MARK: - Compact music bar

    private var compactMusicBar: some View {
        // 3 columns: [left side] [notch gap] [right side]
        // All centered on the notch. Both sides equal width.
        let side = (vm.compactWidth - vm.notchWidth) / 2

        return GeometryReader { _ in
            HStack(spacing: 0) {
                // LEFT: cover + scrolling title, centered in its column
                HStack(spacing: 5) {
                    Group {
                        if let art = vm.music.artwork {
                            Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.15))
                        }
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    MarqueeText(text: "\(vm.music.title) — \(vm.music.artist)")
                        .frame(width: side - 38)
                }
                .frame(width: side)

                // CENTER: notch gap (exact notch width)
                Color.clear
                    .frame(width: vm.notchWidth)

                // RIGHT: prev/play/next, centered in its column
                HStack(spacing: 12) {
                    TapIcon("backward.fill", size: 8, color: .white.opacity(0.45)) { vm.music.previousTrack() }
                    TapIcon(vm.music.isPlaying ? "pause.fill" : "play.fill", size: 10, color: accent) { vm.music.togglePlayPause() }
                    TapIcon("forward.fill", size: 8, color: .white.opacity(0.45)) { vm.music.nextTrack() }
                }
                .frame(width: side)
            }
            .frame(width: vm.compactWidth, height: vm.notchHeight)
        }
        .frame(width: vm.compactWidth, height: vm.notchHeight)
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
            // LEFT: time + weather + system indicators
            HStack(spacing: 6) {
                Text(timeString)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)

                if !vm.weather.temperature.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: vm.weather.icon).font(.system(size: 9))
                        Text(vm.weather.temperature).font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }

                // System indicators (only when enabled)
                systemIndicators
            }
            .padding(.leading, 20)

            Spacer()
            Color.clear.frame(width: vm.notchWidth)
            Spacer()

            // RIGHT: timer | date | BT | gear (timer always left of date)
            HStack(spacing: 6) {
                // Timer: always in the same spot (left of date)
                if vm.timer.isRunning {
                    timerWidget
                } else if vm.timer.isSettingTime {
                    timerInput
                } else {
                    TapIcon("timer", size: 11, color: .white.opacity(0.3)) {
                        vm.timer.isSettingTime = true
                    }
                }

                // Date always visible
                Text(dateString)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))

                // BT indicator (popover is outside the clip)
                if vm.settings.showBluetooth && !vm.systemMonitor.bluetoothDevices.isEmpty {
                    HStack(spacing: 3) {
                        let device = vm.systemMonitor.bluetoothDevices[0]
                        Image(systemName: device.icon)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                        if let avg = device.averageBattery {
                            Text("\(avg)%")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(avg <= 15 ? .red.opacity(0.7) : .white.opacity(0.35))
                        }
                    }
                    .onHover { h in
                        btHoverTrigger = h
                        updateBTPopover()
                    }
                }

                TapIcon("gearshape.fill", size: 12, color: showSettings ? .white : .white.opacity(0.35)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showSettings.toggle()
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }

    private func hoverTip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.92))
                .shadow(color: .black.opacity(0.3), radius: 4))
            .fixedSize()
            .offset(y: 18)
    }

    private var btPopover: some View {
        VStack(spacing: 6) {
            ForEach(vm.systemMonitor.bluetoothDevices) { device in
                VStack(spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: device.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(accent)
                        Text(device.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if let l = device.batteryLeft {
                            btBatteryPill("L", l)
                        }
                        if let r = device.batteryRight {
                            btBatteryPill("R", r)
                        }
                        if let c = device.batteryCase {
                            btBatteryPill("C", c)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.92))
                .shadow(color: .black.opacity(0.3), radius: 6)
        )
        .fixedSize()
        .onHover { h in
            btHoverPopover = h
            updateBTPopover()
        }
    }

    private func updateBTPopover() {
        // Small delay to allow mouse to transit between trigger and popover
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let shouldShow = btHoverTrigger || btHoverPopover
            if showBTPopover != shouldShow {
                withAnimation(.easeInOut(duration: 0.12)) { showBTPopover = shouldShow }
            }
        }
    }

    private func btBatteryPill(_ label: String, _ level: Int) -> some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.3))
            Text("\(level)%").font(.system(size: 8, weight: .medium))
                .foregroundStyle(level <= 15 ? .red.opacity(0.7) : .white.opacity(0.5))
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.06)))
    }

    @ViewBuilder
    private var systemIndicators: some View {
        let sm = vm.systemMonitor
        let s = vm.settings

        if s.showBattery && sm.batteryLevel >= 0 {
            HStack(spacing: 2) {
                Image(systemName: sm.isCharging ? "battery.100.bolt" : batteryIcon(sm.batteryLevel))
                    .font(.system(size: 9))
                Text("\(sm.batteryLevel)%").font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(sm.batteryLevel <= 15 ? .red.opacity(0.7) : .white.opacity(0.35))
        }

        if s.showCPU {
            HStack(spacing: 2) {
                Image(systemName: "cpu").font(.system(size: 8))
                Text("\(Int(sm.cpuUsage))%").font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(sm.cpuUsage > 80 ? .orange.opacity(0.7) : .white.opacity(0.35))
            .overlay(alignment: .bottom) {
                if showCPUTip {
                    hoverTip("CPU: \(Int(sm.cpuUsage))%")
                        .onHover { h in if h { showCPUTip = true } }
                }
            }
            .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { showCPUTip = h } }
        }

        if s.showRAM {
            HStack(spacing: 2) {
                Image(systemName: "memorychip").font(.system(size: 8))
                Text(String(format: "%.1f", sm.ramUsedGB) + "G").font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(sm.ramUsage > 85 ? .orange.opacity(0.7) : .white.opacity(0.35))
            .overlay(alignment: .bottom) {
                if showRAMTip {
                    hoverTip(String(format: "RAM: %.1f / %.0f GB (%d%%)", sm.ramUsedGB, sm.ramTotalGB, Int(sm.ramUsage)))
                        .onHover { h in if h { showRAMTip = true } }
                }
            }
            .onHover { h in withAnimation(.easeInOut(duration: 0.1)) { showRAMTip = h } }
        }

        // Bluetooth is shown on the RIGHT side of the notch, not here
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 0...10: return "battery.0"
        case 11...37: return "battery.25"
        case 38...62: return "battery.50"
        case 63...87: return "battery.75"
        default: return "battery.100"
        }
    }

    private var timerWidget: some View {
        HStack(spacing: 4) {
            Circle()
                .trim(from: 0, to: vm.timer.progress)
                .stroke(accent, lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 12)
                .background(Circle().fill(.white.opacity(0.05)))

            Text(vm.timer.displayTime)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(accent)

            TapIcon("xmark", size: 8, color: .white.opacity(0.4)) {
                vm.timer.stop()
            }
        }
    }

    private var timerInput: some View {
        HStack(spacing: 4) {
            TextField("5", text: $vm.timer.inputMinutes)
                .textFieldStyle(.plain)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 24)
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    if let m = Int(vm.timer.inputMinutes), m > 0 { vm.timer.start(minutes: m) }
                }

            Text("min")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
                .fixedSize()

            TapIcon("play.fill", size: 9, color: accent) {
                if let m = Int(vm.timer.inputMinutes), m > 0 { vm.timer.start(minutes: m) }
            }

            TapIcon("xmark", size: 8, color: .white.opacity(0.3)) {
                vm.timer.isSettingTime = false
            }
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

    // MARK: - Settings panel (iPhone-style drill-down)

    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // Header with breadcrumb
            HStack(spacing: 6) {
                if settingsPage != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(L.settings)
                            .font(.system(size: 11))
                            .foregroundStyle(accent)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { settingsPage = nil }
                    }
                }
                Text(settingsPageTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                TapIcon("xmark", size: 11, color: .white.opacity(0.4)) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        showSettings = false; settingsPage = nil
                    }
                }
            }
            .padding(.bottom, 10)

            // Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    switch settingsPage {
                    case nil: settingsRoot
                    case "appearance": settingsAppearance
                    case "music": settingsMusic
                    case "calendar": settingsCalendar
                    case "system": settingsSystem
                    case "general": settingsGeneral
                    case "about": settingsAbout
                    default: settingsRoot
                    }
                }
            }
        }
    }

    private var settingsPageTitle: String {
        switch settingsPage {
        case nil: return L.settings
        case "appearance": return L.appearance
        case "music": return L.musicPlayer
        case "calendar": return L.lang == .fr ? "Calendrier" : "Calendar"
        case "general": return L.lang == .fr ? "Général" : "General"
        case "system": return L.lang == .fr ? "Système" : "System"
        case "about": return L.lang == .fr ? "À propos" : "About"
        default: return L.settings
        }
    }

    // MARK: Root menu

    private var settingsRoot: some View {
        VStack(spacing: 2) {
            settingsRow("paintbrush.fill", L.appearance, sub: vm.settings.theme.rawValue) { settingsPage = "appearance" }
            settingsRow("music.note", L.musicPlayer, sub: vm.settings.musicPlayer.rawValue) { settingsPage = "music" }
            settingsRow("calendar", L.lang == .fr ? "Calendrier" : "Calendar") { settingsPage = "calendar" }
            settingsRow("gauge.with.dots.needle.33percent", L.lang == .fr ? "Système" : "System") { settingsPage = "system" }
            settingsRow("gearshape", L.lang == .fr ? "Général" : "General") { settingsPage = "general" }
            settingsRow("info.circle", L.lang == .fr ? "À propos" : "About") { settingsPage = "about" }

            Spacer(minLength: 10)

            // Quit at bottom of root
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
        }
    }

    private func settingsRow(_ icon: String, _ title: String, sub: String = "", action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { action() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Appearance page

    private var settingsAppearance: some View {
        VStack(spacing: 14) {
            settingsSection(L.lang == .fr ? "Thème" : "Theme") {
                HStack(spacing: 12) {
                    ForEach(NotchTheme.allCases, id: \.rawValue) { theme in themeCard(theme) }
                }
            }

            settingsSection("Accent") {
                HStack(spacing: 6) {
                    ForEach(AccentColor.allCases, id: \.rawValue) { ac in
                        let c = ac.color
                        Circle().fill(Color(red: c.r, green: c.g, blue: c.b))
                            .frame(width: vm.settings.accentColor == ac ? 20 : 16,
                                   height: vm.settings.accentColor == ac ? 20 : 16)
                            .overlay(vm.settings.accentColor == ac ? Circle().stroke(.white, lineWidth: 2) : nil)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { vm.settings.accentColor = ac }
                            }
                    }
                }
            }

            settingsSection(L.lang == .fr ? "Mode compact" : "Compact") {
                settingsPicker(CompactStyle.allCases.map { $0.rawValue },
                               selected: vm.settings.compactMode.rawValue) { val in
                    vm.settings.compactMode = CompactStyle(rawValue: val) ?? .off
                }
            }
        }
    }

    // MARK: Music page

    private var settingsMusic: some View {
        VStack(spacing: 14) {
            settingsSection(L.lang == .fr ? "Source" : "Source") {
                settingsPicker(MusicPlayerSource.allCases.map { $0.rawValue },
                               selected: vm.settings.musicPlayer.rawValue) { val in
                    vm.settings.musicPlayer = MusicPlayerSource(rawValue: val) ?? .auto
                }
            }

            settingsSlider(L.queueSize, value: $vm.settings.queueSize, unit: L.tracks, range: 3...20, step: 1)
            settingsSlider(L.musicHistory, value: $vm.settings.musicHistorySize, unit: L.tracks, range: 3...30, step: 1)
        }
    }

    // MARK: Calendar page

    private var settingsCalendar: some View {
        VStack(spacing: 8) {
            ForEach(vm.calendar.availableCalendars, id: \.calendarIdentifier) { cal in
                let isHidden = vm.settings.hiddenCalendarIds.contains(cal.calendarIdentifier)
                HStack(spacing: 8) {
                    Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                    Text(cal.title).font(.system(size: 11)).foregroundStyle(isHidden ? .white.opacity(0.25) : .white.opacity(0.8)).lineLimit(1)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !isHidden },
                        set: { vis in
                            if vis { vm.settings.hiddenCalendarIds.remove(cal.calendarIdentifier) }
                            else { vm.settings.hiddenCalendarIds.insert(cal.calendarIdentifier) }
                            vm.calendar.refresh()
                        }
                    ))
                    .toggleStyle(.switch).scaleEffect(0.6).tint(accent)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
            }
        }
    }

    // MARK: System page

    private var settingsSystem: some View {
        VStack(spacing: 10) {
            Text(L.lang == .fr ? "Indicateurs dans la barre du haut (désactivés par défaut)" : "Clock bar indicators (disabled by default)")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))

            systemToggle("battery.100", L.lang == .fr ? "Batterie" : "Battery",
                         isOn: $vm.settings.showBattery)
            systemToggle("cpu", "CPU",
                         isOn: $vm.settings.showCPU)
            systemToggle("memorychip", "RAM",
                         isOn: $vm.settings.showRAM)
            systemToggle("dot.radiowaves.left.and.right", "Bluetooth",
                         isOn: $vm.settings.showBluetooth)

            if vm.settings.showBluetooth && !vm.systemMonitor.bluetoothDevices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.lang == .fr ? "Appareils connectés" : "Connected devices")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                    ForEach(vm.systemMonitor.bluetoothDevices) { device in
                        HStack(spacing: 8) {
                            Image(systemName: device.icon)
                                .font(.system(size: 14)).foregroundStyle(accent).frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(device.name).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                                if !device.batteryDisplay.isEmpty {
                                    Text(device.batteryDisplay).font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                                }
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func systemToggle(_ icon: String, _ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(accent).frame(width: 20)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Toggle("", isOn: isOn).toggleStyle(.switch).scaleEffect(0.6).tint(accent)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
    }

    // MARK: General page

    private var settingsGeneral: some View {
        VStack(spacing: 14) {
            settingsSection(L.language) {
                settingsPicker(AppLanguage.allCases.map { $0.rawValue },
                               selected: vm.settings.language.rawValue) { val in
                    vm.settings.language = AppLanguage(rawValue: val) ?? .fr
                }
            }

            settingsSlider(L.terminalHistory, value: $vm.settings.terminalHistorySize, unit: "", range: 20...500, step: 10)

            HStack {
                Toggle(isOn: Binding(
                    get: { vm.settings.launchAtLogin },
                    set: { vm.settings.launchAtLogin = $0 }
                )) {
                    Text(L.launchAtLogin).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }
                .toggleStyle(.switch).tint(.green)
            }

            updateSection
        }
    }

    // MARK: About page

    private var settingsAbout: some View {
        VStack(spacing: 12) {
            // App info
            VStack(spacing: 4) {
                Text("Notchy").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                Text("v\(UpdateManager.currentVersion)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
            }
            .padding(.top, 8)

            Text(L.lang == .fr
                ? "Dynamic Island pour macOS"
                : "Dynamic Island for macOS")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))

            Spacer(minLength: 10)

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(L.createdBy).font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                    Button { NSWorkspace.shared.open(URL(string: "https://github.com/kryz3")!) } label: {
                        Text("kryz3").font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                    }.buttonStyle(.plain)
                }
                Button { NSWorkspace.shared.open(URL(string: "https://github.com/kryz3/Notchy")!) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 10))
                        Text("GitHub").font(.system(size: 11))
                    }.foregroundStyle(.white.opacity(0.3))
                }.buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private func settingsPicker(_ options: [String], selected: String, onChange: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { opt in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) { onChange(opt) }
                } label: {
                    Text(opt)
                        .font(.system(size: 10, weight: selected == opt ? .semibold : .regular))
                        .foregroundStyle(selected == opt ? .white : .white.opacity(0.4))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(selected == opt ? accent.opacity(0.15) : .white.opacity(0.04)))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
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
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(vm.selectedTab == tab ? accent : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(vm.selectedTab == tab ? accent.opacity(0.12) : .clear)
                            )
                            .contentShape(Rectangle())
                            .help(tab.label)
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
                    ClipboardView(clipboard: vm.clipboard)
                        .containerRelativeFrame(.horizontal)
                        .id(RightTab.clipboard)
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
