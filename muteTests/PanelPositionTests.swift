import XCTest
@testable import Mute

final class PanelPositionTests: XCTestCase {

    func testRawValueParsing() {
        XCTAssertEqual(PanelPosition(rawValue: "menu"), .menu)
        XCTAssertEqual(PanelPosition(rawValue: "notch"), .notch)
        XCTAssertEqual(PanelPosition(rawValue: "floating"), .floating)
        XCTAssertNil(PanelPosition(rawValue: "bogus"))
    }

    func testCurrentReadsDefaultsAndFallsBackToMenu() {
        let key = DefaultsKey.panelPosition
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set("floating", forKey: key)
        XCTAssertEqual(PanelPosition.current, .floating)

        UserDefaults.standard.set("garbage", forKey: key)
        XCTAssertEqual(PanelPosition.current, .menu)

        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(PanelPosition.current, .menu)
    }
}
