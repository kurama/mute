import XCTest
@testable import Mute

final class FocusDurationTests: XCTestCase {

    func testMinutesUnderAnHour() {
        XCTAssertEqual(5.focusDurationLabel, "5 min")
        XCTAssertEqual(30.focusDurationLabel, "30 min")
        XCTAssertEqual(59.focusDurationLabel, "59 min")
    }

    func testWholeHours() {
        XCTAssertEqual(60.focusDurationLabel, "1h")
        XCTAssertEqual(120.focusDurationLabel, "2h")
    }

    func testHoursAndMinutes() {
        XCTAssertEqual(90.focusDurationLabel, "1h 30m")
        XCTAssertEqual(125.focusDurationLabel, "2h 5m")
    }

    func testPresets() {
        XCTAssertEqual(FocusPreset.all.map { $0.minutes }, [5, 15, 30, 60])
        XCTAssertEqual(FocusPreset.all.last?.label, "1 hour")
    }
}
