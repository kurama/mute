import AVFoundation
import CoreAudio

enum TriggerMode: String {
    case micAndCamera = "both"
    case micOnly = "mic"
    case cameraOnly = "camera"
}

final class MediaMonitor {

    var onStateChange: ((Bool) -> Void)?

    var isMonitoringEnabled = true {
        didSet { if !isMonitoringEnabled { forceIdle() } }
    }

    var triggerMode: TriggerMode = {
        TriggerMode(rawValue: UserDefaults.standard.string(forKey: "triggerMode") ?? "") ?? .micAndCamera
    }() {
        didSet {
            UserDefaults.standard.set(triggerMode.rawValue, forKey: "triggerMode")
            refreshState()
        }
    }

    private(set) var isActive = false
    private(set) var isMicActive = false
    private(set) var isCameraActive = false

    private var micDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var cameraObservation: NSKeyValueObservation?
    private var deviceConnectObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        attachMicListener()
        attachCameraObserver()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()

        deviceConnectObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main
        ) { [weak self] _ in self?.attachCameraObserver() }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        cameraObservation = nil
        if let obs = deviceConnectObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    // MARK: - Microphone (CoreAudio)

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

    // MARK: - Camera (AVCaptureDevice)

    private func attachCameraObserver() {
        cameraObservation = nil
        let cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        guard let camera = cameras.first else { return }
        cameraObservation = camera.observe(\.isInUseByAnotherApplication, options: [.new, .initial]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshCameraState() }
        }
    }

    private func refreshCameraState() {
        let active = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices.contains { $0.isInUseByAnotherApplication }
        setCameraActive(active)
    }

    // MARK: - Polling fallback

    private func poll() {
        guard isMonitoringEnabled else { return }
        refreshMicState()
        refreshCameraState()
    }

    // MARK: - State

    private func setCameraActive(_ active: Bool) {
        isCameraActive = active
        refreshState()
    }

    private func setMicActive(_ active: Bool) {
        isMicActive = active
        refreshState()
    }

    private func refreshState() {
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
        isMicActive = false
        isCameraActive = false
        guard isActive else { return }
        isActive = false
        onStateChange?(false)
    }
}
