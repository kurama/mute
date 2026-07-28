import XCTest
@testable import Mute

final class TriggerModeTests: XCTestCase {

    func testMicAndCameraTriggersOnEither() {
        let mode = TriggerMode.micAndCamera
        XCTAssertFalse(mode.isTriggered(mic: false, camera: false))
        XCTAssertTrue(mode.isTriggered(mic: true, camera: false))
        XCTAssertTrue(mode.isTriggered(mic: false, camera: true))
        XCTAssertTrue(mode.isTriggered(mic: true, camera: true))
    }

    func testMicOnlyIgnoresCamera() {
        let mode = TriggerMode.micOnly
        XCTAssertFalse(mode.isTriggered(mic: false, camera: false))
        XCTAssertTrue(mode.isTriggered(mic: true, camera: false))
        XCTAssertFalse(mode.isTriggered(mic: false, camera: true))
        XCTAssertTrue(mode.isTriggered(mic: true, camera: true))
    }

    func testCameraOnlyIgnoresMic() {
        let mode = TriggerMode.cameraOnly
        XCTAssertFalse(mode.isTriggered(mic: false, camera: false))
        XCTAssertFalse(mode.isTriggered(mic: true, camera: false))
        XCTAssertTrue(mode.isTriggered(mic: false, camera: true))
        XCTAssertTrue(mode.isTriggered(mic: true, camera: true))
    }

    // Raw values are persisted in UserDefaults, so they must stay stable.
    func testRawValuesAreStable() {
        XCTAssertEqual(TriggerMode.micAndCamera.rawValue, "both")
        XCTAssertEqual(TriggerMode.micOnly.rawValue, "mic")
        XCTAssertEqual(TriggerMode.cameraOnly.rawValue, "camera")
        XCTAssertEqual(TriggerMode(rawValue: "both"), .micAndCamera)
        XCTAssertNil(TriggerMode(rawValue: "nonsense"))
    }
}
