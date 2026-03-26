import Foundation
import IOKit.ps

struct BTDevice: Identifiable {
    let id = UUID()
    let name: String
    let batteryLeft: Int?   // nil if not available
    let batteryRight: Int?
    let batteryCase: Int?
    let minorType: String   // "Headphones", etc.

    var icon: String {
        let lower = name.lowercased()
        if lower.contains("airpods pro") || lower.contains("airpodspro") { return "airpodspro" }
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods") { return "airpods.gen3" }
        if lower.contains("beats") { return "beats.headphones" }
        if minorType.lowercased().contains("headphone") { return "headphones" }
        return "dot.radiowaves.left.and.right"
    }

    var batteryDisplay: String {
        var parts: [String] = []
        if let l = batteryLeft { parts.append("L:\(l)%") }
        if let r = batteryRight { parts.append("R:\(r)%") }
        if let c = batteryCase { parts.append("C:\(c)%") }
        if parts.isEmpty { return "" }
        return parts.joined(separator: " ")
    }

    var averageBattery: Int? {
        let vals = [batteryLeft, batteryRight].compactMap { $0 }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / vals.count
    }
}

@Observable
final class SystemMonitorManager {
    var batteryLevel: Int = -1      // -1 = no battery
    var isCharging = false
    var cpuUsage: Double = 0        // 0-100
    var ramUsage: Double = 0        // 0-100
    var ramUsedGB: Double = 0
    var ramTotalGB: Double = 0
    var bluetoothDevices: [BTDevice] = []

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        fetchBattery()
        fetchCPU()
        fetchRAM()
        fetchBluetooth()
    }

    // MARK: - Battery

    private func fetchBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else { batteryLevel = -1; return }

        batteryLevel = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let state = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        isCharging = state == kIOPSACPowerValue
    }

    // MARK: - CPU

    private func fetchCPU() {
        // Use 'top' for a quick CPU snapshot
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            let pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/top")
            p.arguments = ["-l", "1", "-n", "0", "-stats", "cpu"]
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            // Parse "CPU usage: X% user, Y% sys, Z% idle"
            if let line = output.components(separatedBy: "\n").first(where: { $0.contains("CPU usage") }) {
                let parts = line.components(separatedBy: ",")
                var total = 0.0
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("idle") { continue }
                    // Extract percentage
                    let nums = trimmed.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).joined()
                    let normalized = nums.replacingOccurrences(of: ",", with: ".")
                    total += Double(normalized) ?? 0
                }
                DispatchQueue.main.async { self?.cpuUsage = min(100, total) }
            }
        }
    }

    // MARK: - RAM

    private func fetchRAM() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        ramTotalGB = totalBytes / 1_073_741_824
        ramUsedGB = used / 1_073_741_824
        ramUsage = (used / totalBytes) * 100
    }

    // MARK: - Bluetooth

    private func fetchBluetooth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            let pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPBluetoothDataType"]
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.components(separatedBy: "\n")

            var devices: [BTDevice] = []
            var inConnected = false
            var currentName: String?
            var leftBat: Int?, rightBat: Int?, caseBat: Int?, minorType = ""

            func flushDevice() {
                if let name = currentName {
                    devices.append(BTDevice(name: name, batteryLeft: leftBat, batteryRight: rightBat,
                                           batteryCase: caseBat, minorType: minorType))
                }
                currentName = nil; leftBat = nil; rightBat = nil; caseBat = nil; minorType = ""
            }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let indent = line.count - line.drop(while: { $0 == " " }).count

                if trimmed == "Connected:" { inConnected = true; continue }
                if trimmed == "Not Connected:" { flushDevice(); break }
                guard inConnected else { continue }

                // Device name: indented ~10, ends with ":"
                if indent >= 8 && indent <= 12 && trimmed.hasSuffix(":") && !trimmed.contains("Battery") {
                    flushDevice()
                    currentName = String(trimmed.dropLast())
                }
                // Properties: indented ~14+
                if indent >= 14, currentName != nil {
                    if trimmed.hasPrefix("Left Battery Level:") {
                        leftBat = Int(trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
                    } else if trimmed.hasPrefix("Right Battery Level:") {
                        rightBat = Int(trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
                    } else if trimmed.hasPrefix("Case Battery Level:") {
                        caseBat = Int(trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
                    } else if trimmed.hasPrefix("Minor Type:") {
                        minorType = trimmed.replacingOccurrences(of: "Minor Type: ", with: "")
                    }
                }
            }
            flushDevice()

            DispatchQueue.main.async { self?.bluetoothDevices = devices }
        }
    }
}
