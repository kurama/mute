import AVFoundation
import CoreAudio
import CoreMediaIO

enum TriggerMode: String {
    case micAndCamera = "both"
    case micOnly = "mic"
    case cameraOnly = "camera"

    /// Whether the current mic/camera activity should trigger Do Not Disturb under
    /// this mode. Pure and side-effect free so it can be unit tested on its own.
    func isTriggered(mic: Bool, camera: Bool) -> Bool {
        switch self {
        case .micAndCamera: return mic || camera
        case .micOnly:      return mic
        case .cameraOnly:   return camera
        }
    }
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
        stateDidChange()
    }

    var triggerMode: TriggerMode = {
        TriggerMode(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.triggerMode) ?? "") ?? .micAndCamera
    }() {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: DefaultsKey.triggerMode)
            stateDidChange()
        }
    }

    private(set) var isActive = false
    private(set) var isMicActive = false
    private(set) var isCameraActive = false

    private var micDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var micRunningListener: AudioObjectPropertyListenerBlock?
    private var defaultInputListener: AudioObjectPropertyListenerBlock?
    private var deviceConnectObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    func start() {
        attachMicListener()
        listenForDefaultInputChanges()
        requestCameraAccessThenListen()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()

        deviceConnectObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.attachCameraListener() }
    }

    // The default input device changes when a headset connects, a mic is unplugged,
    // or the user picks another one in System Settings. Re-point the mic listener at
    // it so detection doesn't stay stuck on the device that was default at launch.
    private func listenForDefaultInputChanges() {
        var address = defaultInputAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachMicListener() }
        }
        defaultInputListener = listener
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
        )
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
        detachMicListener()
        if let listener = defaultInputListener {
            var address = defaultInputAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
            )
            defaultInputListener = nil
        }
    }

    private var defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private var micRunningAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // kAudioDevicePropertyDeviceIsRunningSomewhere is the same signal that drives
    // the orange mic indicator in the macOS menu bar — reliable across all apps.
    // Called again whenever the default input changes, so it re-points at the new one.
    private func attachMicListener() {
        var address = defaultInputAddress
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return }

        guard deviceID != micDeviceID else { return }
        detachMicListener()
        micDeviceID = deviceID

        var runningAddress = micRunningAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refreshMicState() }
        }
        micRunningListener = listener
        AudioObjectAddPropertyListenerBlock(deviceID, &runningAddress, DispatchQueue.main, listener)
        refreshMicState()
    }

    private func detachMicListener() {
        guard micDeviceID != kAudioObjectUnknown, let listener = micRunningListener else { return }
        var runningAddress = micRunningAddress
        AudioObjectRemovePropertyListenerBlock(micDeviceID, &runningAddress, DispatchQueue.main, listener)
        micRunningListener = nil
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
        stateDidChange()
    }

    private func setMicActive(_ active: Bool) {
        guard isMicActive != active else { return }
        isMicActive = active
        stateDidChange()
    }

    /// Re-evaluate the DND state, then notify observers that panel data changed.
    private func stateDidChange() {
        refreshState()
        onStateRefresh?()
    }

    private func refreshState() {
        guard !isFocusing else { return }
        let triggered = triggerMode.isTriggered(mic: isMicActive, camera: isCameraActive)
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
