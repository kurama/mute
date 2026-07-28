import AVFoundation
import CoreAudio
import CoreMediaIO

enum TriggerMode: String {
    case micAndCamera = "both"
    case micOnly = "mic"
    case cameraOnly = "camera"
}

final class MediaMonitor {

    var onStateChange: ((Bool) -> Void)?
    var onStateRefresh: (() -> Void)?

    var isMonitoringEnabled = true {
        didSet {
            if !isMonitoringEnabled { forceIdle() }
            onStateRefresh?()
        }
    }

    private(set) var isFocusing = false
    private(set) var focusEndsAt: Date?
    private var focusTimer: Timer?

    func startFocus(for duration: TimeInterval = 1800) {
        focusTimer?.invalidate()
        isFocusing = true
        focusEndsAt = Date().addingTimeInterval(duration)
        if !isActive {
            isActive = true
            onStateChange?(true)
        }
        focusTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.endFocus()
        }
        onStateRefresh?()
    }

    func endFocus() {
        focusTimer?.invalidate()
        focusTimer = nil
        isFocusing = false
        focusEndsAt = nil
        refreshState()
        onStateRefresh?()
    }

    var triggerMode: TriggerMode = {
        TriggerMode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.triggerMode) ?? "") ?? .micAndCamera
    }() {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: DefaultsKey.triggerMode)
            refreshState()
            onStateRefresh?()
        }
    }

    private(set) var isActive = false
    private(set) var isMicActive = false
    private(set) var isCameraActive = false

    private var micDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var deviceConnectObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    func start() {
        attachMicListener()
        requestCameraAccessThenListen()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()

        deviceConnectObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.attachCameraListener() }
    }

    private func requestCameraAccessThenListen() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            attachCameraListener()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.attachCameraListener() } }
            }
        default:
            break
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let obs = deviceConnectObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // kAudioDevicePropertyDeviceIsRunningSomewhere is the same signal that drives
    // the orange mic indicator in the macOS menu bar — reliable across all apps.
    private func attachMicListener() {
        var hwAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &hwAddress, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return }

        micDeviceID = deviceID

        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &runningAddress, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refreshMicState() }
        }
    }

    private func refreshMicState() {
        guard micDeviceID != kAudioObjectUnknown else { return }
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(micDeviceID, &address, 0, nil, &size, &isRunning) == noErr else { return }
        setMicActive(isRunning != 0)
    }

    // CoreMediaIO mirrors CoreAudio but for video — no camera permission needed,
    // kCMIODevicePropertyDeviceIsRunningSomewhere is the camera equivalent of the mic property above.
    private func attachCameraListener() {
        guard let ids = cmioCameraIDs(), !ids.isEmpty else { return }
        for deviceID in ids {
            var addr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            CMIOObjectAddPropertyListenerBlock(deviceID, &addr, DispatchQueue.main) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refreshCameraState() }
            }
        }
        refreshCameraState()
    }

    private func cmioCameraIDs() -> [CMIODeviceID]? {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return nil }

        let count = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var ids = [CMIODeviceID](repeating: CMIODeviceID(kCMIOObjectUnknown), count: count)
        var outSize = dataSize
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, dataSize, &outSize, &ids
        ) == noErr else { return nil }
        return ids
    }

    private func refreshCameraState() {
        guard let ids = cmioCameraIDs() else { setCameraActive(false); return }
        let active = ids.contains { deviceID in
            var addr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            return CMIOObjectGetPropertyData(deviceID, &addr, 0, nil, size, &size, &isRunning) == noErr && isRunning != 0
        }
        setCameraActive(active)
    }

    private func poll() {
        guard isMonitoringEnabled else { return }
        refreshMicState()
        refreshCameraState()
    }

    private func setCameraActive(_ active: Bool) {
        guard isCameraActive != active else { return }
        isCameraActive = active
        refreshState()
        onStateRefresh?()
    }

    private func setMicActive(_ active: Bool) {
        guard isMicActive != active else { return }
        isMicActive = active
        refreshState()
        onStateRefresh?()
    }

    private func refreshState() {
        guard !isFocusing else { return }
        let triggered: Bool
        switch triggerMode {
        case .micAndCamera: triggered = isMicActive || isCameraActive
        case .micOnly:      triggered = isMicActive
        case .cameraOnly:   triggered = isCameraActive
        }
        let newActive = isMonitoringEnabled && triggered
        guard newActive != isActive else { return }
        isActive = newActive
        onStateChange?(isActive)
    }

    private func forceIdle() {
        if isFocusing {
            focusTimer?.invalidate()
            focusTimer = nil
            isFocusing = false
        }
        isMicActive = false
        isCameraActive = false
        guard isActive else { return }
        isActive = false
        onStateChange?(false)
    }
}
