import CoreAudio
import XCTest
@testable import Mute

final class MicrophoneActivityMonitorTests: XCTestCase {

    func testAnyMonitoredDeviceActivatesMicrophone() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1, 2])
        let monitor = MicrophoneActivityMonitor(source: source)

        monitor.start()
        XCTAssertFalse(monitor.isActive)

        source.setDeviceRunning(1, true)
        XCTAssertTrue(monitor.isActive)

        source.setDeviceRunning(2, true)
        source.setDeviceRunning(1, false)
        XCTAssertTrue(monitor.isActive)

        source.setDeviceRunning(2, false)
        XCTAssertFalse(monitor.isActive)
    }

    func testOutputOnlyActivityOnAnInputDeviceDoesNotActivateMicrophone() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1])
        let monitor = MicrophoneActivityMonitor(source: source)
        monitor.start()

        source.setDeviceRunning(1, true, inputActive: false)
        XCTAssertFalse(monitor.isActive)

        source.setDeviceRunning(1, true, inputActive: true)
        XCTAssertTrue(monitor.isActive)
    }

    func testProcessInputStateTakesPrecedenceOverDeviceRunningState() {
        let monitoredDeviceIDs: Set<AudioDeviceID> = [1]
        let runningDeviceIDs: Set<AudioDeviceID> = [1]

        XCTAssertFalse(InputActivityResolver.isActive(
            monitoredDeviceIDs: monitoredDeviceIDs,
            activeProcessInputDeviceIDs: [],
            runningDeviceIDs: runningDeviceIDs
        ))
        XCTAssertTrue(InputActivityResolver.isActive(
            monitoredDeviceIDs: monitoredDeviceIDs,
            activeProcessInputDeviceIDs: [1],
            runningDeviceIDs: []
        ))
        XCTAssertFalse(InputActivityResolver.isActive(
            monitoredDeviceIDs: monitoredDeviceIDs,
            activeProcessInputDeviceIDs: [2],
            runningDeviceIDs: []
        ))
        XCTAssertTrue(InputActivityResolver.isActive(
            monitoredDeviceIDs: monitoredDeviceIDs,
            activeProcessInputDeviceIDs: nil,
            runningDeviceIDs: runningDeviceIDs
        ))
    }

    func testReconcilesListenersWhenDevicesConnectAndDisconnect() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1])
        let monitor = MicrophoneActivityMonitor(source: source)
        monitor.start()

        source.setDeviceIDs([1, 2])
        XCTAssertEqual(Set(source.observedDeviceIDs), [1, 2])

        source.setDeviceRunning(2, true)
        XCTAssertTrue(monitor.isActive)

        source.setDeviceIDs([1])
        XCTAssertEqual(source.invalidatedDeviceIDs, [2])
        XCTAssertFalse(monitor.isActive)
    }

    func testDoesNotRegisterDuplicateListenersForUnchangedDevices() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1])
        let monitor = MicrophoneActivityMonitor(source: source)
        monitor.start()

        source.setDeviceIDs([1])
        source.setDeviceIDs([1])

        XCTAssertEqual(source.listenerRegistrationCount(for: 1), 1)
    }

    func testPollingFallbackReadsADeviceWhoseListenerCouldNotBeAdded() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1])
        source.devicesRejectingListeners = [1]
        source.setDeviceRunning(1, true, notifyListeners: false)
        let monitor = MicrophoneActivityMonitor(source: source)

        monitor.start()
        XCTAssertTrue(monitor.isActive)

        source.setDeviceRunning(1, false, notifyListeners: false)
        monitor.refreshActivity()
        XCTAssertFalse(monitor.isActive)
    }

    func testPollingReconcilesDevicesWhenDeviceListListenerCouldNotBeAdded() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1])
        source.rejectsDeviceListListener = true
        let monitor = MicrophoneActivityMonitor(source: source)
        monitor.start()

        source.setDeviceIDs([1, 2])
        source.setDeviceRunning(2, true, notifyListeners: false)
        monitor.refreshActivity()

        XCTAssertEqual(source.listenerRegistrationCount(for: 2), 1)
        XCTAssertTrue(monitor.isActive)
    }

    func testStopInvalidatesEveryListenerAndClearsActivity() {
        let source = FakeInputDeviceActivitySource(deviceIDs: [1, 2])
        source.setDeviceRunning(1, true, notifyListeners: false)
        let monitor = MicrophoneActivityMonitor(source: source)
        monitor.start()
        XCTAssertTrue(monitor.isActive)

        monitor.stop()

        XCTAssertFalse(monitor.isActive)
        XCTAssertEqual(source.invalidatedDeviceListObserverCount, 1)
        XCTAssertEqual(Set(source.invalidatedDeviceIDs), [1, 2])

        source.setDeviceRunning(1, true)
        XCTAssertFalse(monitor.isActive)
    }
}

private final class FakeInputDeviceActivitySource: InputDeviceActivitySource {

    var devicesRejectingListeners: Set<AudioDeviceID> = []
    var rejectsDeviceListListener = false
    private var deviceIDs: Set<AudioDeviceID>
    private var inputActiveDeviceIDs: Set<AudioDeviceID> = []
    private var deviceListHandlers: [UUID: () -> Void] = [:]
    private var runningHandlers: [AudioDeviceID: [UUID: () -> Void]] = [:]

    private(set) var observedDeviceIDs: [AudioDeviceID] = []
    private(set) var invalidatedDeviceIDs: [AudioDeviceID] = []
    private(set) var invalidatedDeviceListObserverCount = 0
    private var listenerRegistrations: [AudioDeviceID: Int] = [:]

    init(deviceIDs: Set<AudioDeviceID>) {
        self.deviceIDs = deviceIDs
    }

    func inputDeviceIDs() -> Set<AudioDeviceID> {
        deviceIDs
    }

    func isInputActive(on deviceIDs: Set<AudioDeviceID>) -> Bool {
        !deviceIDs.isDisjoint(with: inputActiveDeviceIDs)
    }

    func observeDeviceList(_ handler: @escaping () -> Void) -> AudioHardwareObservation? {
        guard !rejectsDeviceListListener else { return nil }
        let id = UUID()
        deviceListHandlers[id] = handler
        return FakeObservation { [weak self] in
            guard let self, self.deviceListHandlers.removeValue(forKey: id) != nil else { return }
            self.invalidatedDeviceListObserverCount += 1
        }
    }

    func observeRunningState(
        of deviceID: AudioDeviceID,
        handler: @escaping () -> Void
    ) -> AudioHardwareObservation? {
        listenerRegistrations[deviceID, default: 0] += 1
        guard !devicesRejectingListeners.contains(deviceID) else { return nil }

        let id = UUID()
        runningHandlers[deviceID, default: [:]][id] = handler
        observedDeviceIDs.append(deviceID)
        return FakeObservation { [weak self] in
            guard let self, self.runningHandlers[deviceID]?.removeValue(forKey: id) != nil else { return }
            self.invalidatedDeviceIDs.append(deviceID)
        }
    }

    func setDeviceIDs(_ deviceIDs: Set<AudioDeviceID>) {
        self.deviceIDs = deviceIDs
        Array(deviceListHandlers.values).forEach { $0() }
    }

    func setDeviceRunning(
        _ deviceID: AudioDeviceID,
        _ isRunning: Bool,
        inputActive: Bool? = nil,
        notifyListeners: Bool = true
    ) {
        if inputActive ?? isRunning {
            inputActiveDeviceIDs.insert(deviceID)
        } else {
            inputActiveDeviceIDs.remove(deviceID)
        }
        guard notifyListeners else { return }
        let handlers = runningHandlers[deviceID].map { Array($0.values) } ?? []
        handlers.forEach { $0() }
    }

    func listenerRegistrationCount(for deviceID: AudioDeviceID) -> Int {
        listenerRegistrations[deviceID, default: 0]
    }
}

private final class FakeObservation: AudioHardwareObservation {

    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func invalidate() {
        cancellation?()
        cancellation = nil
    }
}
