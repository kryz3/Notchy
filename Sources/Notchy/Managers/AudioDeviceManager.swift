import Foundation
import CoreAudio

final class AudioDeviceManager {
    var onDeviceConnected: ((String) -> Void)?

    private var lastDeviceName: String = ""
    private var listenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        lastDeviceName = currentOutputDeviceName() ?? "Built-in"
        watchOutputDevice()
    }

    private func watchOutputDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if let name = self.currentOutputDeviceName(), name != self.lastDeviceName {
                    let previous = self.lastDeviceName
                    self.lastDeviceName = name

                    // Only notify on external device connections (not switching back to built-in)
                    let builtIn = name.lowercased().contains("macbook") || name.lowercased().contains("built-in")
                    if !builtIn && previous != name {
                        self.onDeviceConnected?(name)
                    }
                }
            }
        }
        listenerBlock = block

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    private func currentOutputDeviceName() -> String? {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        ) == noErr else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &nameAddress, 0, nil, &size, &name
        ) == noErr else { return nil }

        return name as String
    }
}
